//! Bounded sector device contract shared by filesystem code and ATA PIO.
pub const sector_size: usize = 512;
pub const max_sectors_per_command: usize = 128;
pub const lba28_sector_limit: u64 = 0x10000000;

pub const Error = error{
    NoDevice,
    Timeout,
    IoFailure,
    UnsupportedFlush,
    InvalidBuffer,
    OutOfRange,
    TooManySectors,
};

pub const Backend = struct {
    context: *anyopaque,
    read_fn: *const fn (*anyopaque, u64, u16, []u8) Error!void,
    write_fn: *const fn (*anyopaque, u64, u16, []const u8) Error!void,
    flush_fn: *const fn (*anyopaque) Error!void,
};

pub const Device = struct {
    backend: ?Backend = null,
    sector_count: u64 = 0,

    pub fn read(self: Device, lba: u64, sectors: u16, output: []u8) Error!void {
        try self.checkRange(lba, sectors, output.len);
        try (self.backend orelse return error.NoDevice).read_fn(self.backend.?.context, lba, sectors, output);
    }

    pub fn write(self: Device, lba: u64, sectors: u16, input: []const u8) Error!void {
        try self.checkRange(lba, sectors, input.len);
        try (self.backend orelse return error.NoDevice).write_fn(self.backend.?.context, lba, sectors, input);
    }

    pub fn flush(self: Device) Error!void {
        const backend = self.backend orelse return error.NoDevice;
        try backend.flush_fn(backend.context);
    }

    fn checkRange(self: Device, lba: u64, sectors: u16, bytes: usize) Error!void {
        if (self.backend == null) return error.NoDevice;
        if (sectors == 0 or sectors > max_sectors_per_command) return error.TooManySectors;
        const expected = @as(usize, sectors) * sector_size;
        if (bytes != expected) return error.InvalidBuffer;
        if (lba >= self.sector_count or lba >= lba28_sector_limit or sectors > lba28_sector_limit - lba) return error.OutOfRange;
        if (sectors > self.sector_count - lba) return error.OutOfRange;
    }
};

test "device rejects absent, malformed, excessive, and out-of-range requests before backend calls" {
    const testing = @import("std").testing;
    var missing = Device{};
    var bytes: [sector_size]u8 = undefined;
    try testing.expectError(error.NoDevice, missing.read(0, 1, &bytes));
    try testing.expectError(error.NoDevice, missing.flush());

    var calls: usize = 0;
    var context = Fake{ .calls = &calls };
    const device = Device{ .backend = .{ .context = &context, .read_fn = Fake.read, .write_fn = Fake.write, .flush_fn = Fake.flush }, .sector_count = 4 };
    try testing.expectError(error.InvalidBuffer, device.read(0, 1, bytes[0..511]));
    try testing.expectError(error.TooManySectors, device.read(0, 129, bytes[0..]));
    try testing.expectError(error.OutOfRange, device.read(4, 1, &bytes));
    try testing.expectEqual(@as(usize, 0), calls);
    try device.read(3, 1, &bytes);
    try testing.expectEqual(@as(usize, 1), calls);
}

test "device preserves backend timeout and I/O errors and forwards flush" {
    const testing = @import("std").testing;
    var calls: usize = 0;
    var context = Fake{ .calls = &calls, .fail = true };
    const device = Device{ .backend = .{ .context = &context, .read_fn = Fake.read, .write_fn = Fake.write, .flush_fn = Fake.flush }, .sector_count = 4 };
    var bytes: [sector_size]u8 = undefined;
    try testing.expectError(error.Timeout, device.read(0, 1, &bytes));
    try testing.expectError(error.IoFailure, device.write(0, 1, &bytes));
    try testing.expectError(error.UnsupportedFlush, device.flush());
}

const Fake = struct {
    calls: *usize,
    fail: bool = false,
    fn read(ctx: *anyopaque, _: u64, _: u16, _: []u8) Error!void {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls.* += 1;
        if (self.fail) return error.Timeout;
    }
    fn write(ctx: *anyopaque, _: u64, _: u16, _: []const u8) Error!void {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls.* += 1;
        if (self.fail) return error.IoFailure;
    }
    fn flush(ctx: *anyopaque) Error!void {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls.* += 1;
        if (self.fail) return error.UnsupportedFlush;
    }
};
