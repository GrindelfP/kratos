//! Small copy-on-write data volume for personal and shared spaces.
//!
//! Two fixed metadata slots alternate by generation. File data is allocated
//! copy-on-write from sectors not referenced by the mounted generation. Data
//! and device cache are flushed before a checksummed metadata snapshot is
//! written and flushed. A torn snapshot fails its checksum, leaving the prior
//! generation mountable. Objects are never reused within a volume generation
//! history; `next_id` is persisted monotonically.
const std = @import("std");
const block = @import("block_device.zig");

pub const max_objects = 64;
pub const max_name = 32;
pub const max_file_bytes = 64 * 1024;
pub const max_dir_entries = 64;
pub const metadata_slot_sectors: u16 = 9;
pub const metadata_a_lba: u64 = 1;
pub const metadata_b_lba: u64 = metadata_a_lba + metadata_slot_sectors;
pub const data_start_lba: u64 = metadata_b_lba + metadata_slot_sectors;
const record_size = 64;
const header_size = 512;
const slot_bytes = @as(usize, metadata_slot_sectors) * block.sector_size;
const encoded_size = header_size + max_objects * record_size;

pub const Error = block.Error || error{
    Unformatted,
    Corrupt,
    UnsupportedVersion,
    InvalidName,
    InvalidPath,
    NotFound,
    Duplicate,
    WrongKind,
    NotEmpty,
    Reserved,
    Unsupported,
    NoSpace,
    TooLarge,
    OutputTooSmall,
};
pub const Kind = enum(u8) { space = 1, directory = 2, file = 3 };
pub const Handle = struct { id: u64 };
pub const Entry = struct { handle: Handle, parent: u64, name: []const u8, kind: Kind, size: usize };
pub const Record = struct { id: u64, parent: u64, name: [max_name]u8, name_len: u8, kind: Kind, size: u32, lba: u64, sectors: u16 };

pub const Volume = struct {
    device: block.Device,
    records: [max_objects]Record = undefined,
    count: usize = 0,
    next_id: u64 = 1,
    generation: u64 = 0,
    active_slot: ?u64 = null,
    poisoned: bool = false,

    /// Formats only a caller-confirmed blank volume. The caller must inspect
    /// the device first; this method never probes or overwrites implicitly.
    pub fn formatBlank(self: *Volume) Error!void {
        var a: [slot_bytes]u8 = undefined;
        var b: [slot_bytes]u8 = undefined;
        try self.device.read(metadata_a_lba, metadata_slot_sectors, &a);
        try self.device.read(metadata_b_lba, metadata_slot_sectors, &b);
        if (!allZero(&a) or !allZero(&b)) return error.Corrupt;
        self.count = 0;
        self.next_id = 1;
        self.generation = 0;
        self.active_slot = null;
        self.poisoned = false;
        try self.commit();
    }

    pub fn mount(self: *Volume) Error!void {
        var a: [slot_bytes]u8 = undefined;
        var b: [slot_bytes]u8 = undefined;
        try self.device.read(metadata_a_lba, metadata_slot_sectors, &a);
        try self.device.read(metadata_b_lba, metadata_slot_sectors, &b);
        const da = decode(&a, &self.records);
        var records_b: [max_objects]Record = undefined;
        const db = decode(&b, &records_b);
        if (da == null and db == null) {
            if (allZero(&a) and allZero(&b)) return error.Unformatted;
            if (hasUnsupportedVersion(&a) or hasUnsupportedVersion(&b)) return error.UnsupportedVersion;
            return error.Corrupt;
        }
        if (da) |decoded_a| {
            if (db) |decoded_b| {
                if (decoded_b.generation > decoded_a.generation) {
                    @memcpy(&self.records, &records_b);
                    self.count = decoded_b.count;
                    self.next_id = decoded_b.next_id;
                    self.generation = decoded_b.generation;
                    self.active_slot = metadata_b_lba;
                    return self.validateMountedExtents();
                }
            }
            self.count = decoded_a.count;
            self.next_id = decoded_a.next_id;
            self.generation = decoded_a.generation;
            self.active_slot = metadata_a_lba;
            return self.validateMountedExtents();
        }
        const chosen = db orelse return error.Corrupt;
        @memcpy(&self.records, &records_b);
        self.count = chosen.count;
        self.next_id = chosen.next_id;
        self.generation = chosen.generation;
        self.active_slot = metadata_b_lba;
        try self.validateMountedExtents();
    }

    pub fn createSpace(self: *Volume, name: []const u8) Error!Handle {
        try self.ensureWritable();
        try validateName(name);
        if (std.mem.eql(u8, name, "system") or std.mem.eql(u8, name, "mine")) return error.Reserved;
        if (self.findChild(0, name) != null) return error.Duplicate;
        if (self.count + 5 > max_objects) return error.NoSpace;
        const old_count = self.count;
        const space = try self.append(0, name, .space);
        for ([_][]const u8{ "inbox", "work", "library", "archive" }) |area| _ = try self.append(space.id, area, .directory);
        self.commit() catch |err| {
            self.count = old_count;
            return err;
        };
        return .{ .id = space.id };
    }

    pub fn listSpaces(self: *const Volume, output: []Entry) Error!usize {
        return self.children(0, output);
    }

    pub fn lookup(self: *const Volume, path: []const u8) Error!Handle {
        if (path.len < 6 or path.len > 255) return error.InvalidPath;
        const colon = std.mem.indexOfScalar(u8, path, ':') orelse return error.InvalidPath;
        if (colon == 0 or colon > max_name) return error.InvalidPath;
        var current = self.findChild(0, path[0..colon]) orelse return error.NotFound;
        var rest = path[colon + 1 ..];
        if (rest.len == 0) return .{ .id = current.id };
        if (rest[0] != '/') return error.InvalidPath;
        rest = rest[1..];
        if (rest.len == 0) return error.InvalidPath;
        while (true) {
            const slash = std.mem.indexOfScalar(u8, rest, '/');
            const name = if (slash) |at| rest[0..at] else rest;
            try validateName(name);
            if (current.kind != .space and current.kind != .directory) return error.WrongKind;
            current = self.findChild(current.id, name) orelse return error.NotFound;
            if (slash) |at| {
                if (current.kind == .file) return error.WrongKind;
                rest = rest[at + 1 ..];
                if (rest.len == 0) return error.InvalidPath;
            } else return .{ .id = current.id };
        }
    }

    pub fn stat(self: *const Volume, handle: Handle) Error!Entry {
        const rec = self.findId(handle.id) orelse return error.NotFound;
        return entry(rec);
    }

    pub fn children(self: *const Volume, parent: u64, output: []Entry) Error!usize {
        const dir = self.findId(parent) orelse return error.NotFound;
        if (dir.kind == .file) return error.WrongKind;
        var n: usize = 0;
        for (self.records[0..self.count]) |rec| if (rec.parent == parent) {
            if (n == output.len) return error.OutputTooSmall;
            output[n] = entry(rec);
            n += 1;
        };
        return n;
    }

    pub fn createDirectory(self: *Volume, parent: Handle, name: []const u8) Error!Handle {
        return self.createNode(parent, name, .directory);
    }
    pub fn createFile(self: *Volume, parent: Handle, name: []const u8) Error!Handle {
        return self.createNode(parent, name, .file);
    }

    pub fn read(self: *const Volume, handle: Handle, offset: usize, output: []u8) Error!usize {
        const rec = self.findId(handle.id) orelse return error.NotFound;
        if (rec.kind != .file) return error.WrongKind;
        if (offset >= rec.size or output.len == 0) return 0;
        const amount = @min(output.len, @as(usize, rec.size) - offset);
        var bounce: [block.sector_size]u8 = undefined;
        var copied: usize = 0;
        while (copied < amount) {
            const absolute = offset + copied;
            const sector_index = absolute / block.sector_size;
            const within = absolute % block.sector_size;
            try self.device.read(rec.lba + sector_index, 1, &bounce);
            const take = @min(amount - copied, block.sector_size - within);
            @memcpy(output[copied .. copied + take], bounce[within .. within + take]);
            copied += take;
        }
        return amount;
    }

    /// Replaces a file atomically. Its old extent remains live until the new
    /// data and metadata snapshot have both reached stable storage.
    pub fn write(self: *Volume, handle: Handle, bytes: []const u8) Error!void {
        try self.ensureWritable();
        if (bytes.len > max_file_bytes) return error.TooLarge;
        const index = self.indexOf(handle.id) orelse return error.NotFound;
        if (self.records[index].kind != .file) return error.WrongKind;
        const old = self.records[index];
        const needed: u16 = @intCast((bytes.len + block.sector_size - 1) / block.sector_size);
        const allocated = try self.allocate(needed);
        var padded: [block.sector_size]u8 = undefined;
        var written: usize = 0;
        while (written < bytes.len) {
            @memset(&padded, 0);
            const take = @min(bytes.len - written, padded.len);
            @memcpy(padded[0..take], bytes[written .. written + take]);
            try self.device.write(allocated + written / padded.len, 1, &padded);
            written += take;
        }
        try self.device.flush();
        self.records[index].size = @intCast(bytes.len);
        self.records[index].lba = allocated;
        self.records[index].sectors = needed;
        self.commit() catch |err| {
            self.records[index] = old;
            return err;
        };
    }

    pub fn renameMove(self: *Volume, handle: Handle, new_parent: Handle, new_name: []const u8) Error!void {
        try self.ensureWritable();
        try validateName(new_name);
        const index = self.indexOf(handle.id) orelse return error.NotFound;
        const parent = self.findId(new_parent.id) orelse return error.NotFound;
        if (parent.kind == .file) return error.WrongKind;
        const rec = self.records[index];
        if (rec.kind == .space or self.isReservedArea(rec)) return error.Reserved;
        const destination_space = self.spaceId(parent.id) orelse return error.InvalidPath;
        const source_space = self.spaceId(rec.id) orelse return error.InvalidPath;
        if (destination_space != source_space) return error.Unsupported;
        if (self.findChild(parent.id, new_name)) |existing| if (existing.id != rec.id) return error.Duplicate;
        if (rec.kind == .directory and self.isDescendant(parent.id, rec.id)) return error.InvalidPath;
        const old = self.records[index];
        self.records[index].parent = parent.id;
        @memset(&self.records[index].name, 0);
        @memcpy(self.records[index].name[0..new_name.len], new_name);
        self.records[index].name_len = @intCast(new_name.len);
        self.commit() catch |err| {
            self.records[index] = old;
            return err;
        };
    }

    pub fn remove(self: *Volume, handle: Handle) Error!void {
        try self.ensureWritable();
        const index = self.indexOf(handle.id) orelse return error.NotFound;
        const rec = self.records[index];
        if (rec.kind == .space or self.isReservedArea(rec)) return error.Reserved;
        for (self.records[0..self.count]) |child| if (child.parent == rec.id) return error.NotEmpty;
        const old_count = self.count;
        var i = index;
        while (i + 1 < self.count) : (i += 1) self.records[i] = self.records[i + 1];
        self.count -= 1;
        self.commit() catch |err| {
            self.records[index] = rec;
            self.count = old_count;
            return err;
        };
        // Handles are stable IDs. A removed ID becomes NotFound and is never reused.
    }

    fn createNode(self: *Volume, parent: Handle, name: []const u8, kind: Kind) Error!Handle {
        try self.ensureWritable();
        try validateName(name);
        const dir = self.findId(parent.id) orelse return error.NotFound;
        if (dir.kind == .file) return error.WrongKind;
        if (dir.kind == .space and !isArea(name)) return error.Reserved;
        if (self.findChild(parent.id, name) != null) return error.Duplicate;
        const old_count = self.count;
        const result = try self.append(parent.id, name, kind);
        self.commit() catch |err| {
            self.count = old_count;
            return err;
        };
        return .{ .id = result.id };
    }

    fn append(self: *Volume, parent: u64, name: []const u8, kind: Kind) Error!Record {
        if (self.count == max_objects) return error.NoSpace;
        if (self.next_id == std.math.maxInt(u64)) return error.NoSpace;
        var rec: Record = .{ .id = self.next_id, .parent = parent, .name = undefined, .name_len = @intCast(name.len), .kind = kind, .size = 0, .lba = 0, .sectors = 0 };
        @memset(&rec.name, 0);
        @memcpy(rec.name[0..name.len], name);
        self.records[self.count] = rec;
        self.count += 1;
        self.next_id += 1;
        return rec;
    }

    fn commit(self: *Volume) Error!void {
        try self.ensureWritable();
        self.generation = std.math.add(u64, self.generation, 1) catch return error.Corrupt;
        var bytes: [slot_bytes]u8 = undefined;
        @memset(&bytes, 0);
        encode(&bytes, self.records[0..self.count], self.next_id, self.generation);
        const target = if (self.active_slot == metadata_a_lba) metadata_b_lba else metadata_a_lba;
        self.device.write(target, metadata_slot_sectors, &bytes) catch |err| {
            self.generation -= 1;
            self.poisoned = true;
            return err;
        };
        self.device.flush() catch |err| {
            self.generation -= 1;
            self.poisoned = true;
            return err;
        };
        self.active_slot = target;
    }

    fn ensureWritable(self: *const Volume) Error!void {
        if (self.poisoned) return error.IoFailure;
    }

    fn validateMountedExtents(self: *const Volume) Error!void {
        for (self.records[0..self.count]) |rec| if (rec.kind == .file and rec.sectors != 0) {
            if (rec.lba < data_start_lba or rec.lba > self.device.sector_count or rec.sectors > self.device.sector_count - rec.lba) return error.Corrupt;
        };
        for (self.records[0..self.count]) |space| if (space.kind == .space) {
            var area_count: usize = 0;
            for (self.records[0..self.count]) |child| if (child.parent == space.id) {
                area_count += 1;
                if (child.kind != .directory or !isArea(child.name[0..child.name_len])) return error.Corrupt;
            };
            if (area_count != 4) return error.Corrupt;
            inline for (.{ "inbox", "work", "library", "archive" }) |area| {
                const child = self.findChild(space.id, area) orelse return error.Corrupt;
                if (child.kind != .directory) return error.Corrupt;
            }
        };
    }

    fn allocate(self: *const Volume, sectors: u16) Error!u64 {
        if (sectors == 0) return 0;
        var candidate = data_start_lba;
        while (candidate + sectors <= self.device.sector_count) : (candidate += 1) {
            var occupied = false;
            for (self.records[0..self.count]) |rec| {
                if (rec.kind != .file or rec.sectors == 0) continue;
                if (candidate < rec.lba + rec.sectors and rec.lba < candidate + sectors) {
                    occupied = true;
                    break;
                }
            }
            if (!occupied) return candidate;
        }
        return error.NoSpace;
    }

    fn findId(self: *const Volume, id: u64) ?Record {
        for (self.records[0..self.count]) |rec| if (rec.id == id) return rec;
        return null;
    }
    fn indexOf(self: *const Volume, id: u64) ?usize {
        for (self.records[0..self.count], 0..) |rec, i| if (rec.id == id) return i;
        return null;
    }
    fn findChild(self: *const Volume, parent: u64, name: []const u8) ?Record {
        for (self.records[0..self.count]) |rec| if (rec.parent == parent and std.mem.eql(u8, rec.name[0..rec.name_len], name)) return rec;
        return null;
    }
    fn spaceId(self: *const Volume, id: u64) ?u64 {
        var rec = self.findId(id) orelse return null;
        while (rec.kind != .space) {
            rec = self.findId(rec.parent) orelse return null;
        }
        return rec.id;
    }
    fn isDescendant(self: *const Volume, possible_child: u64, ancestor: u64) bool {
        var id = possible_child;
        while (id != 0) {
            if (id == ancestor) return true;
            id = (self.findId(id) orelse return false).parent;
        }
        return false;
    }
    fn isReservedArea(self: *const Volume, rec: Record) bool {
        const parent = self.findId(rec.parent) orelse return false;
        return parent.kind == .space;
    }
};

fn entry(rec: Record) Entry {
    return .{ .handle = .{ .id = rec.id }, .parent = rec.parent, .name = rec.name[0..rec.name_len], .kind = rec.kind, .size = rec.size };
}
fn isArea(name: []const u8) bool {
    for ([_][]const u8{ "inbox", "work", "library", "archive" }) |area| if (std.mem.eql(u8, name, area)) return true;
    return false;
}
fn validateName(name: []const u8) Error!void {
    if (name.len == 0 or name.len > max_name) return error.InvalidName;
    for (name) |c| if (c < 'a' or c > 'z') return error.InvalidName;
}
fn allZero(bytes: []const u8) bool {
    for (bytes) |b| if (b != 0) return false;
    return true;
}
fn hasUnsupportedVersion(bytes: []const u8) bool {
    return bytes.len >= 12 and std.mem.eql(u8, bytes[0..8], "KRSPACE1") and get32(bytes, 8) != 1;
}
fn put16(b: []u8, at: usize, x: u16) void {
    b[at] = @truncate(x);
    b[at + 1] = @truncate(x >> 8);
}
fn put32(b: []u8, at: usize, x: u32) void {
    put16(b, at, @truncate(x));
    put16(b, at + 2, @truncate(x >> 16));
}
fn put64(b: []u8, at: usize, x: u64) void {
    put32(b, at, @truncate(x));
    put32(b, at + 4, @truncate(x >> 32));
}
fn get16(b: []const u8, at: usize) u16 {
    return @as(u16, b[at]) | (@as(u16, b[at + 1]) << 8);
}
fn get32(b: []const u8, at: usize) u32 {
    return @as(u32, get16(b, at)) | (@as(u32, get16(b, at + 2)) << 16);
}
fn get64(b: []const u8, at: usize) u64 {
    return @as(u64, get32(b, at)) | (@as(u64, get32(b, at + 4)) << 32);
}
fn checksum(bytes: []const u8) u32 {
    var copy: [slot_bytes]u8 = undefined;
    @memcpy(&copy, bytes);
    @memset(copy[24..28], 0);
    return std.hash.Crc32.hash(&copy);
}

fn encode(bytes: *[slot_bytes]u8, records: []const Record, next_id: u64, generation: u64) void {
    @memset(bytes, 0);
    @memcpy(bytes[0..8], "KRSPACE1");
    put32(bytes, 8, 1);
    put32(bytes, 12, @intCast(records.len));
    put64(bytes, 16, generation);
    put64(bytes, 28, next_id);
    put32(bytes, 36, @intCast(data_start_lba));
    for (records, 0..) |rec, i| {
        const at = header_size + i * record_size;
        put64(bytes, at, rec.id);
        put64(bytes, at + 8, rec.parent);
        bytes[at + 16] = @backingInt(rec.kind);
        bytes[at + 17] = rec.name_len;
        @memcpy(bytes[at + 18 .. at + 18 + max_name], &rec.name);
        put32(bytes, at + 50, rec.size);
        put64(bytes, at + 54, rec.lba);
        put16(bytes, at + 62, rec.sectors);
    }
    put32(bytes, 24, checksum(bytes));
}

const Decoded = struct { count: usize, generation: u64, next_id: u64 };
fn decode(bytes: []const u8, records: *[max_objects]Record) ?Decoded {
    if (bytes.len != slot_bytes or !std.mem.eql(u8, bytes[0..8], "KRSPACE1")) return null;
    if (get32(bytes, 8) != 1) return null;
    const count = get32(bytes, 12);
    if (count > max_objects or get32(bytes, 24) != checksum(bytes)) return null;
    const next_id = get64(bytes, 28);
    if (next_id == 0) return null;
    if (get32(bytes, 36) != data_start_lba or !allZero(bytes[40..header_size])) return null;
    var max_id: u64 = 0;
    for (0..count) |i| {
        const at = header_size + i * record_size;
        const kind_raw = bytes[at + 16];
        const len = bytes[at + 17];
        if (kind_raw < 1 or kind_raw > 3 or len == 0 or len > max_name or !allZero(bytes[at + 18 + len .. at + 50])) return null;
        const id = get64(bytes, at);
        const parent = get64(bytes, at + 8);
        if (id == 0 or id >= next_id or (i == 0 and (parent != 0 or kind_raw != @backingInt(Kind.space))) or (i > 0 and parent == 0)) return null;
        const name = bytes[at + 18 .. at + 18 + len];
        for (name) |c| if (c < 'a' or c > 'z') return null;
        const kind: Kind = @fromBackingInt(@intCast(kind_raw));
        const size = get32(bytes, at + 50);
        const lba = get64(bytes, at + 54);
        const sectors = get16(bytes, at + 62);
        if (kind != .file and (size != 0 or lba != 0 or sectors != 0)) return null;
        if (kind == .file and (size > max_file_bytes or sectors != (size + block.sector_size - 1) / block.sector_size or (sectors != 0 and lba < data_start_lba))) return null;
        records[i] = .{ .id = id, .parent = parent, .name = undefined, .name_len = len, .kind = kind, .size = size, .lba = lba, .sectors = sectors };
        @memset(&records[i].name, 0);
        @memcpy(records[i].name[0..len], name);
        max_id = @max(max_id, id);
        for (records[0..i]) |prior| if (prior.id == id or (prior.parent == parent and std.mem.eql(u8, prior.name[0..prior.name_len], name))) return null;
    }
    if (next_id <= max_id) return null;
    for (records[0..count]) |rec| if (rec.parent != 0) {
        var parent_found = false;
        for (records[0..count]) |parent| if (parent.id == rec.parent and parent.kind != .file) {
            parent_found = true;
            break;
        };
        if (!parent_found) return null;
    };
    for (records[0..count]) |rec| {
        var current = rec;
        var steps: usize = 0;
        while (current.parent != 0) : (steps += 1) {
            if (steps >= count) return null;
            var found: ?Record = null;
            for (records[0..count]) |parent| if (parent.id == current.parent) {
                found = parent;
                break;
            };
            current = found orelse return null;
        }
        if (current.kind != .space) return null;
        if (rec.parent == 0 and rec.kind != .space) return null;
    }
    // Reject extents outside the device-independent LBA28 address space and overlaps.
    for (records[0..count], 0..) |rec, i| if (rec.kind == .file and rec.sectors != 0) {
        if (rec.lba > block.lba28_sector_limit - rec.sectors) return null;
        for (records[0..i]) |prior| if (prior.kind == .file and prior.sectors != 0 and rec.lba < prior.lba + prior.sectors and prior.lba < rec.lba + rec.sectors) return null;
    };
    return .{ .count = count, .generation = get64(bytes, 16), .next_id = next_id };
}

test "format, create spaces and areas, persist files, and retain IDs through moves" {
    const testing = std.testing;
    var fake = FakeDisk.init(512);
    defer testing.allocator.free(fake.bytes);
    var volume = Volume{ .device = fake.device() };
    try volume.formatBlank();
    const space = try volume.createSpace("personal");
    const work = try volume.lookup("personal:/work");
    const file = try volume.createFile(work, "note");
    try volume.write(file, "durable");
    const archive = try volume.lookup("personal:/archive");
    try volume.renameMove(file, archive, "record");
    try testing.expectEqual(file.id, (try volume.lookup("personal:/archive/record")).id);
    var remounted = Volume{ .device = fake.device() };
    try remounted.mount();
    const loaded = try remounted.lookup("personal:/archive/record");
    var output: [16]u8 = undefined;
    const n = try remounted.read(loaded, 0, &output);
    try testing.expectEqualStrings("durable", output[0..n]);
    try testing.expectEqual(space.id, (try remounted.lookup("personal:")).id);
}

test "names, duplicates, reserved areas, exhaustion, and stale handles are bounded" {
    const testing = std.testing;
    var fake = FakeDisk.init(100);
    defer testing.allocator.free(fake.bytes);
    var volume = Volume{ .device = fake.device() };
    try volume.formatBlank();
    const space = try volume.createSpace("team");
    const archive = try volume.lookup("team:/archive");
    try testing.expectError(error.InvalidName, volume.createFile(archive, "Bad"));
    try testing.expectError(error.Reserved, volume.createDirectory(space, "other"));
    const file = try volume.createFile(archive, "note");
    try testing.expectError(error.Duplicate, volume.createFile(archive, "note"));
    try volume.remove(file);
    try testing.expectError(error.NotFound, volume.stat(file));
    var enormous: [max_file_bytes + 1]u8 = undefined;
    @memset(&enormous, 0);
    const other = try volume.createFile(archive, "large");
    try testing.expectError(error.TooLarge, volume.write(other, &enormous));
}

test "mount chooses complete old snapshot after interrupted metadata write" {
    const testing = std.testing;
    var fake = FakeDisk.init(128);
    defer testing.allocator.free(fake.bytes);
    var volume = Volume{ .device = fake.device() };
    try volume.formatBlank();
    _ = try volume.createSpace("first");
    fake.fail_write_after = fake.writes + 1;
    try testing.expectError(error.IoFailure, volume.createSpace("second"));
    fake.fail_write_after = 0;
    var recovered = Volume{ .device = fake.device() };
    try recovered.mount();
    _ = try recovered.lookup("first:");
    try testing.expectError(error.NotFound, recovered.lookup("second:"));
}

test "rejects unsupported versions and file allocation exhaustion" {
    const testing = std.testing;
    var fake = FakeDisk.init(40);
    defer testing.allocator.free(fake.bytes);
    var volume = Volume{ .device = fake.device() };
    try volume.formatBlank();
    _ = try volume.createSpace("home");
    const folder = try volume.lookup("home:/work");
    const file = try volume.createFile(folder, "large");
    var contents: [max_file_bytes]u8 = undefined;
    @memset(&contents, 0xaa);
    try testing.expectError(error.NoSpace, volume.write(file, &contents));
    fake.bytes[@as(usize, @intCast(metadata_a_lba)) * block.sector_size + 8] = 2;
    fake.bytes[@as(usize, @intCast(metadata_b_lba)) * block.sector_size + 8] = 2;
    var recovered = Volume{ .device = fake.device() };
    try testing.expectError(error.UnsupportedVersion, recovered.mount());
}

test "failed copy-on-write data update preserves prior file contents" {
    const testing = std.testing;
    var fake = FakeDisk.init(128);
    defer testing.allocator.free(fake.bytes);
    var volume = Volume{ .device = fake.device() };
    try volume.formatBlank();
    _ = try volume.createSpace("home");
    const folder = try volume.lookup("home:/archive");
    const file = try volume.createFile(folder, "note");
    try volume.write(file, "old data");
    fake.fail_write_after = fake.writes + 1;
    try testing.expectError(error.IoFailure, volume.write(file, "new data"));
    fake.fail_write_after = 0;
    var recovered = Volume{ .device = fake.device() };
    try recovered.mount();
    var output: [16]u8 = undefined;
    const n = try recovered.read(try recovered.lookup("home:/archive/note"), 0, &output);
    try testing.expectEqualStrings("old data", output[0..n]);
}

const FakeDisk = struct {
    bytes: []u8,
    writes: usize = 0,
    fail_write_after: usize = 0,
    fn init(sectors: usize) FakeDisk {
        const memory = std.testing.allocator.alloc(u8, sectors * block.sector_size) catch unreachable;
        @memset(memory, 0);
        return .{ .bytes = memory };
    }
    fn device(self: *FakeDisk) block.Device {
        return .{ .backend = .{ .context = self, .read_fn = read, .write_fn = write, .flush_fn = flush }, .sector_count = self.bytes.len / block.sector_size };
    }
    fn read(raw: *anyopaque, lba: u64, sectors: u16, output: []u8) block.Error!void {
        const self: *FakeDisk = @ptrCast(@alignCast(raw));
        @memcpy(output, self.bytes[@as(usize, @intCast(lba)) * block.sector_size ..][0 .. @as(usize, sectors) * block.sector_size]);
    }
    fn write(raw: *anyopaque, lba: u64, sectors: u16, input: []const u8) block.Error!void {
        const self: *FakeDisk = @ptrCast(@alignCast(raw));
        self.writes += 1;
        const offset = @as(usize, @intCast(lba)) * block.sector_size;
        if (self.fail_write_after != 0 and self.writes >= self.fail_write_after) {
            const partial = input.len / 2;
            @memcpy(self.bytes[offset .. offset + partial], input[0..partial]);
            return error.IoFailure;
        }
        @memcpy(self.bytes[offset .. offset + @as(usize, sectors) * block.sector_size], input);
    }
    fn flush(_: *anyopaque) block.Error!void {}
};
