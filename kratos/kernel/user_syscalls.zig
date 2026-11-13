//! Policy for the fixed embedded context's non-POSIX syscall ABI.
const std = @import("std");
pub const max_output: u64 = 1024;
pub const bad_range: u64 = @bitCast(@as(i64, -1));
pub const too_long: u64 = @bitCast(@as(i64, -2));
pub const unknown: u64 = @bitCast(@as(i64, -3));
pub const Action = union(enum) { output: struct { address: u64, length: u64 }, exit: u64, result: u64 };

/// All three pages are present and user-readable for the lifetime of a run.
pub fn readable(address: u64, length: u64) bool {
    if (length == 0) return true;
    return address >= 0x400000 and address < 0x403000 and length <= 0x403000 - address;
}
pub fn dispatch(number: u64, arg1: u64, arg2: u64) Action {
    return switch (number) {
        1 => if (arg2 > max_output) .{ .result = too_long } else if (!readable(arg1, arg2)) .{ .result = bad_range } else .{ .output = .{ .address = arg1, .length = arg2 } },
        2 => .{ .exit = arg1 },
        else => .{ .result = unknown },
    };
}
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
    try std.testing.expect(dispatch(1, 0, 1).result == bad_range);
    try std.testing.expect(dispatch(1, 0, max_output + 1).result == too_long);
    try std.testing.expect(dispatch(1, 0x400000, max_output).output.length == max_output);
    try std.testing.expect(dispatch(1, 0, 0).output.length == 0);
    try std.testing.expect(dispatch(2, 42, 0).exit == 42);
    try std.testing.expect(dispatch(99, 0, 0).result == unknown);
}
