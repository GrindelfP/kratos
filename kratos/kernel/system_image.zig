//! Validated, read-only view of the KRSYSIMG v1 system image.
const std = @import("std");

pub const max_image_size = 16 * 1024 * 1024;
pub const max_objects = 4096;
const header_size = 32;
const record_size = 80;

pub const Kind = enum(u8) { directory = 1, file = 2 };
pub const FileType = enum(u8) { directory = 0, @"opaque" = 1, text = 2, executable = 3, unknown = 255 };
pub const Error = error{ Unavailable, InvalidPath, NotFound, WrongKind, MalformedImage, OutputTooSmall };

pub const Record = struct {
    id: u64,
    parent: u64,
    kind: Kind,
    file_type: FileType,
    name_offset: u32,
    name_length: u8,
    content_offset: u32,
    content_length: u32,
};

pub const Handle = struct { id: u64 };
pub const Entry = struct { handle: Handle, name: []const u8, kind: Kind, file_type: FileType, size: usize };

pub const Mount = struct {
    image: []const u8,
    records: []const Record,

    pub fn init(image: []const u8, storage: []Record) Error!Mount {
        if (image.len < header_size or image.len > max_image_size or storage.len < 1) return error.MalformedImage;
        if (!std.mem.eql(u8, image[0..8], "KRSYSIMG") or read32(image, 8) != 1 or read32(image, 28) != 0) return error.MalformedImage;
        const total = read32(image, 12);
        const count = read32(image, 16);
        const table = read32(image, 20);
        const data_start = read32(image, 24);
        if (total != image.len or count == 0 or count > max_objects or count > storage.len or table != header_size) return error.MalformedImage;
        const expected_data = std.math.add(u32, header_size, std.math.mul(u32, count, record_size) catch return error.MalformedImage) catch return error.MalformedImage;
        if (data_start != expected_data or data_start > total) return error.MalformedImage;

        for (0..count) |i| {
            const at = header_size + i * record_size;
            const id = read64(image, at);
            const parent = read64(image, at + 8);
            const kind_raw = image[at + 16];
            const type_raw = image[at + 17];
            const name_len = read16(image, at + 18);
            const name_start = at + 20;
            const content_offset = read64(image, at + 52);
            const content_length = read64(image, at + 60);
            if (id == 0 or name_len > 32 or !allZero(image[at + 68 .. at + record_size]) or !allZero(image[name_start + name_len .. name_start + 32])) return error.MalformedImage;
            if (kind_raw != 1 and kind_raw != 2) return error.MalformedImage;
            const kind: Kind = @enumFromInt(kind_raw);
            if (i == 0) {
                if (id != 1 or parent != 0 or kind != .directory or name_len != 0) return error.MalformedImage;
            } else if (parent == 0 or name_len == 0 or !validName(image[name_start .. name_start + name_len])) return error.MalformedImage;
            const file_type: FileType = if (kind == .directory) blk: {
                if (type_raw != 0 or content_offset != 0 or content_length != 0) return error.MalformedImage;
                break :blk .directory;
            } else blk: {
                if (type_raw == 0 or content_offset < data_start or content_offset > total or content_length > total - content_offset) return error.MalformedImage;
                break :blk switch (type_raw) { 1 => .@"opaque", 2 => .text, 3 => .executable, else => .@"opaque" };
            };
            if (content_offset > std.math.maxInt(u32) or content_length > std.math.maxInt(u32)) return error.MalformedImage;
            storage[i] = .{ .id = id, .parent = parent, .kind = kind, .file_type = file_type, .name_offset = @intCast(name_start), .name_length = @intCast(name_len), .content_offset = @intCast(content_offset), .content_length = @intCast(content_length) };
            for (storage[0..i]) |prior| {
                if (prior.id == id or (prior.parent == parent and std.mem.eql(u8, image[prior.name_offset .. prior.name_offset + prior.name_length], image[name_start .. name_start + name_len]))) return error.MalformedImage;
            }
        }
        // Validate every parent chain and the canonical system root shape.
        for (storage[0..count], 0..) |rec, index| {
            if (index == 0) continue;
            var current = rec;
            var steps: usize = 0;
            var path_length: usize = 7;
            while (current.id != 1) : (steps += 1) {
                if (steps >= count) return error.MalformedImage;
                path_length = std.math.add(usize, path_length, current.name_length + 1) catch return error.MalformedImage;
                if (path_length > 255 or steps >= 128) return error.MalformedImage;
                var found: ?Record = null;
                for (storage[0..count]) |candidate| if (candidate.id == current.parent) {
                    found = candidate;
                    break;
                };
                current = found orelse return error.MalformedImage;
                if (current.kind != .directory) return error.MalformedImage;
            }
        }
        var root_names: [3][]const u8 = undefined;
        var root_count: usize = 0;
        for (storage[0..count]) |rec| if (rec.parent == 1) {
            if (rec.kind != .directory or root_count == root_names.len) return error.MalformedImage;
            root_names[root_count] = image[rec.name_offset .. rec.name_offset + rec.name_length];
            root_count += 1;
        };
        if (root_count != 3 or !hasName(&root_names, "boot") or !hasName(&root_names, "packages") or !hasName(&root_names, "policy")) return error.MalformedImage;
        // Records must cover the data section exactly. Selection sort avoids allocation.
        var cursor: u64 = data_start;
        var consumed: usize = 0;
        while (consumed < count) : (consumed += 1) {
            var next: ?Record = null;
            for (storage[0..count]) |rec| if (rec.kind == .file and rec.content_length != 0 and rec.content_offset >= cursor) {
                if (next == null or rec.content_offset < next.?.content_offset) next = rec;
            };
            if (next) |rec| {
                if (rec.content_offset != cursor) return error.MalformedImage;
                cursor += rec.content_length;
            }
        }
        if (cursor != total) return error.MalformedImage;
        for (storage[0..count]) |rec| if (rec.kind == .file and rec.content_length == 0 and rec.content_offset < data_start) return error.MalformedImage;
        return .{ .image = image, .records = storage[0..count] };
    }

    pub fn lookup(self: Mount, path: []const u8) Error!Handle {
        if (!std.mem.startsWith(u8, path, "system:") or path.len > 255) return error.InvalidPath;
        var current: u64 = 1;
        var rest = path[7..];
        if (rest.len == 0) return .{ .id = 1 };
        if (rest[0] != '/') return error.InvalidPath;
        rest = rest[1..];
        if (rest.len == 0) return error.InvalidPath;
        while (true) {
            const slash = std.mem.indexOfScalar(u8, rest, '/');
            const component = if (slash) |pos| rest[0..pos] else rest;
            if (!validName(component)) return error.InvalidPath;
            var match: ?Record = null;
            for (self.records) |rec| if (rec.parent == current and std.mem.eql(u8, self.name(rec), component)) {
                match = rec;
                break;
            };
            const found = match orelse return error.NotFound;
            current = found.id;
            if (slash) |pos| {
                if (found.kind != .directory) return error.WrongKind;
                rest = rest[pos + 1 ..];
                if (rest.len == 0) return error.InvalidPath;
            } else return .{ .id = current };
        }
    }

    pub fn stat(self: Mount, handle: Handle) Error!Entry {
        const rec = self.record(handle) orelse return error.NotFound;
        return .{ .handle = handle, .name = self.name(rec), .kind = rec.kind, .file_type = rec.file_type, .size = rec.content_length };
    }

    pub fn enumerate(self: Mount, directory: Handle, output: []Entry) Error!usize {
        const dir = self.record(directory) orelse return error.NotFound;
        if (dir.kind != .directory) return error.WrongKind;
        var count: usize = 0;
        for (self.records) |rec| if (rec.parent == dir.id) {
            if (count == output.len) return error.OutputTooSmall;
            output[count] = try self.stat(.{ .id = rec.id });
            count += 1;
        };
        return count;
    }

    pub fn read(self: Mount, handle: Handle, offset: usize, output: []u8) Error!usize {
        const rec = self.record(handle) orelse return error.NotFound;
        if (rec.kind != .file) return error.WrongKind;
        if (offset >= rec.content_length or output.len == 0) return 0;
        const amount = @min(output.len, rec.content_length - offset);
        const start = std.math.add(usize, rec.content_offset, offset) catch return error.MalformedImage;
        @memcpy(output[0..amount], self.image[start .. start + amount]);
        return amount;
    }

    fn record(self: Mount, handle: Handle) ?Record {
        for (self.records) |rec| if (rec.id == handle.id) return rec;
        return null;
    }
    fn name(self: Mount, rec: Record) []const u8 { return self.image[rec.name_offset .. rec.name_offset + rec.name_length]; }
};

/// Optional mounted volume that reports absence distinctly from lookup errors.
pub const Volume = struct {
    mount: ?Mount = null,
    pub fn lookup(self: Volume, path: []const u8) Error!Handle { return (self.mount orelse return error.Unavailable).lookup(path); }
    pub fn stat(self: Volume, handle: Handle) Error!Entry { return (self.mount orelse return error.Unavailable).stat(handle); }
    pub fn enumerate(self: Volume, directory: Handle, output: []Entry) Error!usize { return (self.mount orelse return error.Unavailable).enumerate(directory, output); }
    pub fn read(self: Volume, handle: Handle, offset: usize, output: []u8) Error!usize { return (self.mount orelse return error.Unavailable).read(handle, offset, output); }
};

fn read16(bytes: []const u8, at: usize) u16 { return @as(u16, bytes[at]) | (@as(u16, bytes[at + 1]) << 8); }
fn read32(bytes: []const u8, at: usize) u32 { return @as(u32, read16(bytes, at)) | (@as(u32, read16(bytes, at + 2)) << 16); }
fn read64(bytes: []const u8, at: usize) u64 { return @as(u64, read32(bytes, at)) | (@as(u64, read32(bytes, at + 4)) << 32); }
fn allZero(bytes: []const u8) bool { for (bytes) |byte| if (byte != 0) return false; return true; }
fn validName(name: []const u8) bool { if (name.len == 0 or name.len > 32) return false; for (name) |c| if (c < 'a' or c > 'z') return false; return true; }
fn hasName(names: *const [3][]const u8, target: []const u8) bool { for (names.*) |name| if (std.mem.eql(u8, name, target)) return true; return false; }

test "mount lookup stat enumeration and bounded read" {
    const testing = std.testing;
    const image = try makeFixture(testing.allocator);
    defer testing.allocator.free(image);
    var records: [8]Record = undefined;
    const mount = try Mount.init(image, &records);
    const file = try mount.lookup("system:/packages/hello/message");
    const info = try mount.stat(file);
    try testing.expectEqual(FileType.text, info.file_type);
    try testing.expectEqual(@as(usize, 5), info.size);
    var bytes: [8]u8 = undefined;
    try testing.expectEqual(@as(usize, 3), try mount.read(file, 2, &bytes));
    try testing.expectEqualStrings("llo", bytes[0..3]);
    try testing.expectEqual(@as(usize, 0), try mount.read(file, 5, &bytes));
    try testing.expectError(error.WrongKind, mount.read(try mount.lookup("system:/packages"), 0, &bytes));
    var entries: [4]Entry = undefined;
    try testing.expectEqual(@as(usize, 1), try mount.enumerate(try mount.lookup("system:/packages/hello"), &entries));
}

test "reject malformed image without publishing a mount" {
    const testing = std.testing;
    const image = try makeFixture(testing.allocator);
    defer testing.allocator.free(image);
    var records: [8]Record = undefined;
    var bad = try testing.allocator.dupe(u8, image);
    defer testing.allocator.free(bad);
    bad[8] = 2;
    try testing.expectError(error.MalformedImage, Mount.init(bad, &records));
    try testing.expectError(error.InvalidPath, (try Mount.init(image, &records)).lookup("system://packages"));
    try testing.expectError(error.NotFound, (try Mount.init(image, &records)).lookup("system:/missing"));
    try testing.expectError(error.WrongKind, (try Mount.init(image, &records)).lookup("system:/packages/hello/message/child"));
    try testing.expectError(error.Unavailable, (Volume{}).lookup("system:/"));
}

fn makeFixture(allocator: std.mem.Allocator) ![]u8 {
    const count: usize = 6;
    const data_start = header_size + count * record_size;
    const content = "hello";
    const bytes = try allocator.alloc(u8, data_start + content.len);
    @memset(bytes, 0);
    @memcpy(bytes[0..8], "KRSYSIMG");
    put32(bytes, 8, 1); put32(bytes, 12, @intCast(bytes.len)); put32(bytes, 16, count); put32(bytes, 20, header_size); put32(bytes, 24, data_start);
    const names = [_][]const u8{ "", "boot", "packages", "hello", "message", "policy" };
    const parents = [_]u64{ 0, 1, 1, 3, 4, 1 };
    const kinds = [_]u8{ 1, 1, 1, 1, 2, 1 };
    for (0..count) |i| {
        const at = header_size + i * record_size;
        put64(bytes, at, i + 1); put64(bytes, at + 8, parents[i]); bytes[at + 16] = kinds[i]; bytes[at + 17] = if (i == 4) 2 else 0; put16(bytes, at + 18, @intCast(names[i].len));
        @memcpy(bytes[at + 20 .. at + 20 + names[i].len], names[i]);
        if (i == 4) { put64(bytes, at + 52, data_start); put64(bytes, at + 60, content.len); }
    }
    @memcpy(bytes[data_start..], content);
    return bytes;
}
fn put16(bytes: []u8, at: usize, n: u16) void { bytes[at] = @truncate(n); bytes[at + 1] = @truncate(n >> 8); }
fn put32(bytes: []u8, at: usize, n: u32) void { put16(bytes, at, @truncate(n)); put16(bytes, at + 2, @truncate(n >> 16)); }
fn put64(bytes: []u8, at: usize, n: u64) void { put32(bytes, at, @truncate(n)); put32(bytes, at + 4, @truncate(n >> 32)); }
