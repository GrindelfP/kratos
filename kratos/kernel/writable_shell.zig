//! Explicit administrative commands for the writable data volume.
const std = @import("std");
const volume_mod = @import("writable_volume.zig");
pub const Writer = struct { context: *anyopaque, write: *const fn (*anyopaque, []const u8) void };

pub fn execute(volume: *volume_mod.Volume, command: []const u8, args: []const u8, writer: Writer) void {
    var principal: u64 = 1;
    executeAs(volume, &principal, command, args, writer);
}

pub fn executeAs(volume: *volume_mod.Volume, principal: *u64, command: []const u8, args: []const u8, writer: Writer) void {
    if (std.mem.eql(u8, command, "account-use")) {
        const account = volume.accountByName(args) orelse {
            writer.write(writer.context, "Account not found\r\n");
            return;
        };
        principal.* = account.id;
        writer.write(writer.context, "Active recovery principal: ");
        writer.write(writer.context, args);
        writer.write(writer.context, "\r\n");
    } else if (std.mem.eql(u8, command, "account-create")) {
        const id = volume.createAccount(args) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Created account id=");
        writeDecimal(writer, id);
        writer.write(writer.context, "\r\n");
    } else if (std.mem.eql(u8, command, "account-list")) {
        var accounts: [volume_mod.max_accounts]volume_mod.Account = undefined;
        const count = volume.accountList(&accounts) catch |err| {
            report(writer, err);
            return;
        };
        for (accounts[0..count]) |account| {
            writeDecimal(writer, account.id);
            writer.write(writer.context, " ");
            writer.write(writer.context, account.name[0..account.name_len]);
            if (account.id == principal.*) writer.write(writer.context, " (active)");
            writer.write(writer.context, "\r\n");
        }
    } else if (std.mem.eql(u8, command, "account-rename")) {
        const split = std.mem.indexOfScalar(u8, args, ' ') orelse {
            usage(writer, command);
            return;
        };
        const id = parseDecimal(args[0..split]) orelse {
            usage(writer, command);
            return;
        };
        volume.renameAccount(id, args[split + 1 ..]) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Account renamed; stable id preserved\r\n");
    } else if (std.mem.eql(u8, command, "account-disable")) {
        const id = parseDecimal(args) orelse {
            usage(writer, command);
            return;
        };
        volume.disableAccount(id) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Account disabled; ownership records retained\r\n");
    } else if (std.mem.eql(u8, command, "grant")) {
        const first = std.mem.indexOfScalar(u8, args, ' ') orelse {
            usage(writer, command);
            return;
        };
        const second_rel = std.mem.indexOfScalar(u8, args[first + 1 ..], ' ') orelse {
            usage(writer, command);
            return;
        };
        const second = first + 1 + second_rel;
        const space = volume.lookupAs(args[0..first], principal.*) catch |err| {
            report(writer, err);
            return;
        };
        volume.authorize(space, principal.*, .manage_grants) catch |err| {
            report(writer, err);
            return;
        };
        const id = parseDecimal(args[first + 1 .. second]) orelse {
            usage(writer, command);
            return;
        };
        const role: volume_mod.Role = if (std.mem.eql(u8, args[second + 1 ..], "reader")) .reader else if (std.mem.eql(u8, args[second + 1 ..], "editor")) .editor else if (std.mem.eql(u8, args[second + 1 ..], "owner")) .owner else {
            usage(writer, command);
            return;
        };
        volume.grant(space, id, role) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Grant saved\r\n");
    } else if (std.mem.eql(u8, command, "revoke")) {
        const split = std.mem.indexOfScalar(u8, args, ' ') orelse {
            usage(writer, command);
            return;
        };
        const space = volume.lookupAs(args[0..split], principal.*) catch |err| {
            report(writer, err);
            return;
        };
        volume.authorize(space, principal.*, .manage_grants) catch |err| {
            report(writer, err);
            return;
        };
        const id = parseDecimal(args[split + 1 ..]) orelse {
            usage(writer, command);
            return;
        };
        volume.revoke(space, id) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Grant revoked\r\n");
    } else if (std.mem.eql(u8, command, "space-create")) {
        if (volume.accountById(principal.*) == null) {
            report(writer, error.AccessDenied);
            return;
        }
        _ = volume.createSpaceOwned(args, principal.*) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Space created\r\n");
    } else if (std.mem.eql(u8, command, "space-format")) {
        volume.formatBlank() catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Blank data volume formatted\r\n");
    } else if (std.mem.eql(u8, command, "space-create")) {} else if (std.mem.eql(u8, command, "space-list")) {
        var entries: [volume_mod.max_objects]volume_mod.Entry = undefined;
        const count = volume.listSpacesAs(principal.*, &entries) catch |err| {
            report(writer, err);
            return;
        };
        if (count == 0) {
            writer.write(writer.context, "(no spaces)\r\n");
        } else {
            for (entries[0..count]) |item| {
                writer.write(writer.context, item.name);
                writer.write(writer.context, "\r\n");
            }
        }
    } else if (std.mem.eql(u8, command, "mkdir") or std.mem.eql(u8, command, "touch")) {
        const parts = splitPath(args) orelse {
            usage(writer, command);
            return;
        };
        const parent = volume.lookupAs(parts.parent, principal.*) catch |err| {
            report(writer, err);
            return;
        };
        if (std.mem.eql(u8, command, "mkdir")) _ = volume.createDirectoryAs(parent, principal.*, parts.name) catch |err| {
            report(writer, err);
            return;
        } else _ = volume.createFileAs(parent, principal.*, parts.name) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Created\r\n");
    } else if (std.mem.eql(u8, command, "write")) {
        const split = std.mem.indexOfScalar(u8, args, ' ') orelse {
            usage(writer, command);
            return;
        };
        const handle = volume.lookupAs(args[0..split], principal.*) catch |err| {
            report(writer, err);
            return;
        };
        volume.writeAs(handle, principal.*, args[split + 1 ..]) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Written\r\n");
    } else if (std.mem.eql(u8, command, "read")) {
        const handle = volume.lookupAs(args, principal.*) catch |err| {
            report(writer, err);
            return;
        };
        var bytes: [96]u8 = undefined;
        const amount = volume.readAs(handle, principal.*, 0, &bytes) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, bytes[0..amount]);
        writer.write(writer.context, "\r\n");
    } else if (std.mem.eql(u8, command, "mv")) {
        const split = std.mem.indexOfScalar(u8, args, ' ') orelse {
            usage(writer, command);
            return;
        };
        const source = volume.lookupAs(args[0..split], principal.*) catch |err| {
            report(writer, err);
            return;
        };
        const parts = splitPath(args[split + 1 ..]) orelse {
            usage(writer, command);
            return;
        };
        const parent = volume.lookupAs(parts.parent, principal.*) catch |err| {
            report(writer, err);
            return;
        };
        volume.renameMoveAs(source, parent, principal.*, parts.name) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Moved\r\n");
    } else if (std.mem.eql(u8, command, "rm")) {
        const handle = volume.lookupAs(args, principal.*) catch |err| {
            report(writer, err);
            return;
        };
        volume.removeAs(handle, principal.*) catch |err| {
            report(writer, err);
            return;
        };
        writer.write(writer.context, "Removed\r\n");
    }
}

const PathParts = struct { parent: []const u8, name: []const u8 };
fn splitPath(path: []const u8) ?PathParts {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return null;
    if (slash == 0 or slash + 1 == path.len) return null;
    return .{ .parent = path[0..slash], .name = path[slash + 1 ..] };
}
fn usage(writer: Writer, command: []const u8) void {
    writer.write(writer.context, "Usage: ");
    writer.write(writer.context, command);
    writer.write(writer.context, " <path>\r\n");
}
fn writeDecimal(writer: Writer, value: u64) void {
    var bytes: [20]u8 = undefined;
    var n = value;
    var index = bytes.len;
    while (true) {
        index -= 1;
        bytes[index] = @intCast(n % 10 + '0');
        n /= 10;
        if (n == 0) break;
    }
    writer.write(writer.context, bytes[index..]);
}
fn parseDecimal(text: []const u8) ?u64 {
    if (text.len == 0) return null;
    var value: u64 = 0;
    for (text) |byte| {
        if (byte < '0' or byte > '9') return null;
        value = std.math.mul(u64, value, 10) catch return null;
        value = std.math.add(u64, value, byte - '0') catch return null;
    }
    return value;
}
fn report(writer: Writer, err: volume_mod.Error) void {
    writer.write(writer.context, switch (err) {
        error.AccessDenied => "Access denied for active principal\r\n",
        error.Unformatted => "Data volume unformatted; use space-format on a blank image\r\n",
        error.Corrupt => "Data volume corrupt or not blank; no data changed\r\n",
        error.UnsupportedVersion => "Unsupported data volume version\r\n",
        error.InvalidName, error.InvalidPath => "Invalid lowercase path/name\r\n",
        error.NotFound => "Path not found\r\n",
        error.Duplicate => "Name already exists\r\n",
        error.WrongKind => "Wrong object kind\r\n",
        error.NotEmpty => "Directory is not empty\r\n",
        error.Reserved => "Reserved area\r\n",
        error.Unsupported => "Cross-space moves are unsupported\r\n",
        error.NoSpace => "Data volume capacity exhausted\r\n",
        error.TooLarge => "File exceeds the 65536-byte limit\r\n",
        error.OutputTooSmall => "Listing exceeds fixed capacity\r\n",
        error.NoDevice => "No writable data disk\r\n",
        error.Timeout => "Data disk timed out\r\n",
        error.IoFailure, error.UnsupportedFlush => "Data disk I/O or flush failed; reboot to recover\r\n",
        error.InvalidBuffer, error.OutOfRange, error.TooManySectors => "Block request rejected\r\n",
    });
}

test "shell mutation commands format create write read and remove" {
    const testing = std.testing;
    var disk = TestDisk.init();
    defer testing.allocator.free(disk.bytes);
    var volume = volume_mod.Volume{ .device = disk.device() };
    var output: TestOutput = .{};
    const writer = Writer{ .context = &output, .write = TestOutput.write };
    execute(&volume, "space-format", "", writer);
    execute(&volume, "space-create", "home", writer);
    execute(&volume, "touch", "home:/work/note", writer);
    execute(&volume, "write", "home:/work/note hello world", writer);
    execute(&volume, "read", "home:/work/note", writer);
    try testing.expect(std.mem.indexOf(u8, output.bytes[0..output.len], "hello world\r\n") != null);
    execute(&volume, "rm", "home:/work/note", writer);
    try testing.expectError(error.NotFound, volume.lookup("home:/work/note"));
}

test "shell grant command resolves shared space root and persists role" {
    const testing = std.testing;
    var disk = TestDisk.init();
    defer testing.allocator.free(disk.bytes);
    var volume = volume_mod.Volume{ .device = disk.device() };
    var output: TestOutput = .{};
    const writer = Writer{ .context = &output, .write = TestOutput.write };
    try volume.formatBlank();
    const alice = try volume.createAccount("alice");
    const bob = try volume.createAccount("bob");
    var principal = alice;
    executeAs(&volume, &principal, "space-create", "team", writer);
    try testing.expect(std.mem.indexOf(u8, output.bytes[0..output.len], "Space created\r\n") != null);
    output.len = 0;
    executeAs(&volume, &principal, "grant", "team: 3 reader", writer);
    try testing.expect(std.mem.indexOf(u8, output.bytes[0..output.len], "Grant saved\r\n") != null);
    try testing.expectEqual(volume_mod.Role.reader, volume.roleFor((try volume.lookup("team:")).id, bob).?);
}

const TestOutput = struct {
    bytes: [1024]u8 = undefined,
    len: usize = 0,
    fn write(raw: *anyopaque, bytes: []const u8) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        @memcpy(self.bytes[self.len..][0..bytes.len], bytes);
        self.len += bytes.len;
    }
};
const TestDisk = struct {
    bytes: []u8,
    fn init() TestDisk {
        const bytes = std.testing.allocator.alloc(u8, 256 * 512) catch unreachable;
        @memset(bytes, 0);
        return .{ .bytes = bytes };
    }
    fn device(self: *TestDisk) @import("block_device.zig").Device {
        return .{ .backend = .{ .context = self, .read_fn = read, .write_fn = write, .flush_fn = flush }, .sector_count = self.bytes.len / 512 };
    }
    fn read(raw: *anyopaque, lba: u64, count: u16, output: []u8) @import("block_device.zig").Error!void {
        const self: *TestDisk = @ptrCast(@alignCast(raw));
        @memcpy(output, self.bytes[@as(usize, @intCast(lba)) * 512 ..][0 .. @as(usize, count) * 512]);
    }
    fn write(raw: *anyopaque, lba: u64, count: u16, input: []const u8) @import("block_device.zig").Error!void {
        const self: *TestDisk = @ptrCast(@alignCast(raw));
        @memcpy(self.bytes[@as(usize, @intCast(lba)) * 512 ..][0 .. @as(usize, count) * 512], input);
    }
    fn flush(_: *anyopaque) @import("block_device.zig").Error!void {}
};
