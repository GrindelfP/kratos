//! Policy for the fixed embedded context's non-POSIX syscall ABI.
const std = @import("std");
const system = @import("system_image.zig");
pub const max_output: u64 = 1024;
pub const max_path: u64 = 255;
pub const max_read: u64 = 512;
pub const bad_range: u64 = @bitCast(@as(i64, -1));
pub const too_long: u64 = @bitCast(@as(i64, -2));
pub const unknown: u64 = @bitCast(@as(i64, -3));
pub const not_found: u64 = @bitCast(@as(i64, -4));
pub const wrong_kind: u64 = @bitCast(@as(i64, -5));
pub const stale_handle: u64 = @bitCast(@as(i64, -6));
pub const unavailable: u64 = @bitCast(@as(i64, -7));
pub const no_handles: u64 = @bitCast(@as(i64, -8));
pub const bad_path: u64 = @bitCast(@as(i64, -9));
pub const Action = union(enum) { output: struct { address: u64, length: u64 }, open: struct { address: u64, length: u64 }, read: struct { handle: u64, address: u64, length: u64 }, close: u64, exit: u64, result: u64 };

/// All three pages are present and user-readable for the lifetime of a run.
pub fn readable(address: u64, length: u64) bool {
    if (length == 0) return true;
    return address >= 0x400000 and address < 0x403000 and length <= 0x403000 - address;
}
pub fn writable(address: u64, length: u64) bool {
    if (length == 0) return true;
    return address >= 0x401000 and address < 0x403000 and length <= 0x403000 - address;
}
pub fn dispatch(number: u64, arg1: u64, arg2: u64, arg3: u64) Action {
    return switch (number) {
        1 => if (arg2 > max_output) .{ .result = too_long } else if (!readable(arg1, arg2)) .{ .result = bad_range } else .{ .output = .{ .address = arg1, .length = arg2 } },
        2 => .{ .exit = arg1 },
        3 => if (arg2 == 0 or arg2 > max_path) .{ .result = too_long } else if (!readable(arg1, arg2)) .{ .result = bad_range } else .{ .open = .{ .address = arg1, .length = arg2 } },
        4 => if (arg3 > max_read) .{ .result = too_long } else if (!writable(arg2, arg3)) .{ .result = bad_range } else .{ .read = .{ .handle = arg1, .address = arg2, .length = arg3 } },
        5 => .{ .close = arg1 },
        else => .{ .result = unknown },
    };
}

/// Handles are local to one fixed user run and use generation-tagged values so
/// stale numeric handles cannot alias a subsequently opened file.
pub const Files = struct {
    const Slot = struct { handle: system.Handle = .{ .id = 0 }, cursor: usize = 0, generation: u32 = 0, open: bool = false };
    volume: *const system.Volume,
    slots: [4]Slot = @splat(.{}),

    pub fn reset(self: *Files) void { for (&self.slots) |*slot| { slot.open = false; slot.cursor = 0; slot.generation +%= 1; } }
    pub fn open(self: *Files, path: []const u8) u64 {
        const volume = self.volume.mount orelse return unavailable;
        const object = volume.lookup(path) catch |err| return mapError(err);
        const info = volume.stat(object) catch |err| return mapError(err);
        if (info.kind != .file) return wrong_kind;
        for (&self.slots, 0..) |*slot, i| if (!slot.open) {
            slot.generation +%= 1;
            slot.handle = object;
            slot.cursor = 0;
            slot.open = true;
            return (@as(u64, slot.generation) << 8) | (i + 1);
        };
        return no_handles;
    }
    pub fn read(self: *Files, handle: u64, output: []u8) u64 {
        const entry = self.getSlot(handle) orelse return stale_handle;
        const volume = self.volume.mount orelse return unavailable;
        const amount = volume.read(entry.handle, entry.cursor, output) catch |err| return mapError(err);
        entry.cursor += amount;
        return amount;
    }
    pub fn close(self: *Files, handle: u64) u64 {
        const entry = self.getSlot(handle) orelse return stale_handle;
        entry.open = false;
        return 0;
    }
    fn getSlot(self: *Files, handle: u64) ?*Slot {
        const index = handle & 0xff;
        if (index == 0 or index > self.slots.len) return null;
        const slot_ptr = &self.slots[@intCast(index - 1)];
        if (!slot_ptr.open or slot_ptr.generation != handle >> 8) return null;
        return slot_ptr;
    }
};

fn mapError(err: system.Error) u64 { return switch (err) { error.Unavailable => unavailable, error.NotFound => not_found, error.WrongKind => wrong_kind, error.InvalidPath => bad_path, else => bad_range }; }
test "bounded complete ranges" {
    try std.testing.expect(readable(0, 0));
    try std.testing.expect(readable(0x400fff, 2));
    try std.testing.expect(readable(0x402fff, 1));
    try std.testing.expect(!readable(0x402fff, 2));
    try std.testing.expect(!readable(0x3fffff, 1));
    try std.testing.expect(!readable(0xffffffffffffffff, 2));
    try std.testing.expect(!readable(0xffffffff80000000, 1));
}
test "dispatch results and limits" {
    try std.testing.expect(dispatch(1, 0, 1, 0).result == bad_range);
    try std.testing.expect(dispatch(1, 0, max_output + 1, 0).result == too_long);
    try std.testing.expect(dispatch(1, 0x400000, max_output, 0).output.length == max_output);
    try std.testing.expect(dispatch(1, 0, 0, 0).output.length == 0);
    try std.testing.expect(dispatch(2, 42, 0, 0).exit == 42);
    try std.testing.expect(dispatch(3, 0x400000, 12, 0).open.length == 12);
    try std.testing.expect(dispatch(4, 0x101, 0x401000, max_read).read.length == max_read);
    try std.testing.expect(dispatch(4, 0x101, 0x400fff, 2).result == bad_range);
    try std.testing.expect(dispatch(4, 0x101, 0x401000, max_read + 1).result == too_long);
    try std.testing.expect(dispatch(99, 0, 0, 0).result == unknown);
}
test "file handles enforce path, kind, lifetime, cursor, and capacity" {
    const allocator = std.testing.allocator;
    const bytes = try system.makeFixture(allocator);
    defer allocator.free(bytes);
    var records: [8]system.Record = undefined;
    var volume = system.Volume{ .mount = try system.Mount.init(bytes, &records) };
    var files = Files{ .volume = &volume };
    const h = files.open("system:/packages/hello/message");
    try std.testing.expect(h > 0);
    var output: [8]u8 = undefined;
    try std.testing.expectEqual(@as(u64, 5), files.read(h, &output));
    try std.testing.expectEqualStrings("hello", output[0..5]);
    try std.testing.expectEqual(@as(u64, 0), files.read(h, &output));
    try std.testing.expectEqual(@as(u64, 0), files.close(h));
    try std.testing.expectEqual(stale_handle, files.read(h, &output));
    try std.testing.expectEqual(stale_handle, files.close(h));
    try std.testing.expectEqual(not_found, files.open("system:/missing"));
    try std.testing.expectEqual(bad_path, files.open("system://packages"));
    try std.testing.expectEqual(wrong_kind, files.open("system:/packages"));
    var handles: [4]u64 = undefined;
    for (&handles) |*handle| handle.* = files.open("system:/packages/hello/message");
    try std.testing.expectEqual(no_handles, files.open("system:/packages/hello/message"));
    volume.mount = null;
    try std.testing.expectEqual(unavailable, files.open("system:/packages/hello/message"));
}
