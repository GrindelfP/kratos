//! Conservative Limine memory-map validation and a minimal page-frame allocator.
//! This module does not own/copy Limine response storage; callers must use it
//! before reclaiming bootloader memory and keep the input alive while allocating.

pub const page_size: u64 = 4096;

pub const MemoryType = enum(u64) {
    usable = 0,
    reserved = 1,
    acpi_reclaimable = 2,
    acpi_nvs = 3,
    bad_memory = 4,
    bootloader_reclaimable = 5,
    executable_and_modules = 6,
    framebuffer = 7,
    reserved_mapped = 8,
};

/// Layout of `struct limine_memmap_entry` in the official Limine protocol.
pub const LimineMemmapEntry = extern struct {
    base: u64,
    length: u64,
    type: u64,
};

pub const Region = struct {
    base: u64,
    length: u64,
    kind: MemoryType,
};

pub const MapError = error{
    EmptyMap,
    EmptyRegion,
    AddressOverflow,
    UnknownType,
    OverlappingRegions,
};

/// Convert raw ABI entries into validated regions. Unknown types and any
/// overlapping ranges invalidate the whole map rather than granting memory.
pub fn validate(raw: []const LimineMemmapEntry, output: []Region) (MapError || error{OutputTooSmall})![]Region {
    if (raw.len == 0) return error.EmptyMap;
    if (output.len < raw.len) return error.OutputTooSmall;

    for (raw, 0..) |entry, i| {
        if (entry.length == 0) return error.EmptyRegion;
        if (entry.base > std.math.maxInt(u64) - entry.length) return error.AddressOverflow;
        const kind: MemoryType = switch (entry.type) {
            0 => .usable,
            1 => .reserved,
            2 => .acpi_reclaimable,
            3 => .acpi_nvs,
            4 => .bad_memory,
            5 => .bootloader_reclaimable,
            6 => .executable_and_modules,
            7 => .framebuffer,
            8 => .reserved_mapped,
            else => return error.UnknownType,
        };
        output[i] = .{ .base = entry.base, .length = entry.length, .kind = kind };
    }

    // Limine normally returns a sorted map, but validate without depending on
    // ordering: malformed overlaps should never become allocator input.
    for (output[0..raw.len], 0..) |left, i| {
        const left_end = left.base + left.length;
        for (output[0..raw.len][i + 1 ..]) |right| {
            const right_end = right.base + right.length;
            if (left.base < right_end and right.base < left_end) return error.OverlappingRegions;
        }
    }
    return output[0..raw.len];
}

/// Monotonic first-fit physical page allocator. It never recycles frames and
/// deliberately considers only `usable` regions, aligned inward to 4 KiB.
pub const FrameAllocator = struct {
    regions: []const Region,
    cursors: []u64,

    pub fn init(regions: []const Region, cursors: []u64) error{OutputTooSmall}!FrameAllocator {
        if (cursors.len < regions.len) return error.OutputTooSmall;
        for (regions, 0..) |region, i| {
            const end = region.base + region.length;
            cursors[i] = if (region.kind == .usable) alignForward(region.base) orelse end else end;
        }
        return .{ .regions = regions, .cursors = cursors[0..regions.len] };
    }

    pub fn allocate(self: *FrameAllocator) ?u64 {
        for (self.regions, 0..) |region, i| {
            if (region.kind != .usable) continue;
            const end = region.base + region.length;
            const frame = self.cursors[i];
            if (frame <= end and end - frame >= page_size) {
                self.cursors[i] = frame + page_size;
                return frame;
            }
        }
        return null;
    }
};

fn alignForward(value: u64) ?u64 {
    const remainder = value % page_size;
    if (remainder == 0) return value;
    const increment = page_size - remainder;
    if (value > std.math.maxInt(u64) - increment) return null;
    return value + increment;
}

const std = @import("std");

test "validates map and allocates only inward-aligned usable frames" {
    const raw = [_]LimineMemmapEntry{
        .{ .base = 0x1003, .length = 0x5000, .type = 0 },
        .{ .base = 0x7000, .length = 0x2000, .type = 1 },
        .{ .base = 0x9000, .length = 0x2000, .type = 0 },
    };
    var regions: [raw.len]Region = undefined;
    const valid = try validate(&raw, &regions);
    var cursors: [raw.len]u64 = undefined;
    var allocator = try FrameAllocator.init(valid, &cursors);
    try std.testing.expectEqual(@as(?u64, 0x2000), allocator.allocate());
    try std.testing.expectEqual(@as(?u64, 0x3000), allocator.allocate());
    try std.testing.expectEqual(@as(?u64, 0x4000), allocator.allocate());
    try std.testing.expectEqual(@as(?u64, 0x5000), allocator.allocate());
    try std.testing.expectEqual(@as(?u64, 0x9000), allocator.allocate());
    try std.testing.expectEqual(@as(?u64, 0xa000), allocator.allocate());
    try std.testing.expectEqual(@as(?u64, null), allocator.allocate());
}

test "rejects unknown, empty, overflowing, and overlapping entries" {
    var output: [2]Region = undefined;
    const unknown = [_]LimineMemmapEntry{.{ .base = 0, .length = page_size, .type = 99 }};
    try std.testing.expectError(error.UnknownType, validate(&unknown, &output));
    const empty = [_]LimineMemmapEntry{.{ .base = 0, .length = 0, .type = 0 }};
    try std.testing.expectError(error.EmptyRegion, validate(&empty, &output));
    const overflow = [_]LimineMemmapEntry{.{ .base = std.math.maxInt(u64) - 8, .length = 16, .type = 0 }};
    try std.testing.expectError(error.AddressOverflow, validate(&overflow, &output));
    const overlap = [_]LimineMemmapEntry{
        .{ .base = 0x1000, .length = 0x3000, .type = 0 },
        .{ .base = 0x2000, .length = 0x1000, .type = 1 },
    };
    try std.testing.expectError(error.OverlappingRegions, validate(&overlap, &output));
}

test "does not wrap an unalignable usable region near the address limit" {
    const raw = [_]LimineMemmapEntry{.{
        .base = std.math.maxInt(u64) - 1,
        .length = 1,
        .type = 0,
    }};
    var regions: [raw.len]Region = undefined;
    const valid = try validate(&raw, &regions);
    var cursors: [raw.len]u64 = undefined;
    var allocator = try FrameAllocator.init(valid, &cursors);
    try std.testing.expectEqual(@as(?u64, null), allocator.allocate());
}
