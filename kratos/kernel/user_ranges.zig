//! Validation for a prospective bounded, lower-half user address space.
//! This is policy only: it does not create mappings or enforce permissions.

const std = @import("std");

pub const page_size: u64 = 4096;
pub const user_end: u64 = 0x0000_8000_0000_0000;

pub const Range = struct {
    start: u64,
    length: u64,
    writable: bool,
    executable: bool,
};

pub const Error = error{ Empty, Unaligned, OutOfRange, WritableExecutable, Overlap };

/// Validate all ranges before allocating frames or altering page tables.
/// Page zero is deliberately unavailable; ranges are half-open.
pub fn validate(ranges: []const Range) Error!void {
    for (ranges, 0..) |range, i| {
        if (range.length == 0) return error.Empty;
        if (range.start % page_size != 0 or range.length % page_size != 0) return error.Unaligned;
        if (range.start < page_size or range.start >= user_end or range.length > user_end - range.start) return error.OutOfRange;
        if (range.writable and range.executable) return error.WritableExecutable;
        const end = range.start + range.length;
        for (ranges[0..i]) |previous| {
            // Previous entries have already passed overflow and bounds checks.
            if (range.start < previous.start + previous.length and previous.start < end) return error.Overlap;
        }
    }
}

test "accepts adjacent code and stack" {
    try validate(&.{
        .{ .start = 0x1000, .length = 0x1000, .writable = false, .executable = true },
        .{ .start = 0x2000, .length = 0x1000, .writable = true, .executable = false },
    });
}

test "rejects malformed ranges and permissions" {
    const base = Range{ .start = 0x1000, .length = 0x1000, .writable = false, .executable = false };
    var range = base;
    range.length = 0;
    try std.testing.expectError(error.Empty, validate(&.{range}));
    range = base;
    range.start += 1;
    try std.testing.expectError(error.Unaligned, validate(&.{range}));
    range = base;
    range.length += 1;
    try std.testing.expectError(error.Unaligned, validate(&.{range}));
    range = base;
    range.start = 0;
    try std.testing.expectError(error.OutOfRange, validate(&.{range}));
    range = base;
    range.start = user_end;
    try std.testing.expectError(error.OutOfRange, validate(&.{range}));
    range = base;
    range.start = user_end - page_size;
    range.length = 2 * page_size;
    try std.testing.expectError(error.OutOfRange, validate(&.{range}));
    range = base;
    range.start = 0xffff_ffff_ffff_f000;
    try std.testing.expectError(error.OutOfRange, validate(&.{range}));
    range = base;
    range.writable = true;
    range.executable = true;
    try std.testing.expectError(error.WritableExecutable, validate(&.{range}));
    try std.testing.expectError(error.Overlap, validate(&.{ base, base }));
    range = base;
    range.length = 2 * page_size;
    try std.testing.expectError(error.Overlap, validate(&.{ range, .{ .start = 0x2000, .length = page_size, .writable = true, .executable = false } }));
}
