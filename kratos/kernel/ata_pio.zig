//! One primary-channel ATA PIO disk at legacy ports 0x1f0–0x1f7/0x3f6.
const block = @import("block_device.zig");

const io_base: u16 = 0x1f0;
const control: u16 = 0x3f6;
const poll_limit: usize = 1_000_000;
const command_read: u8 = 0x20;
const command_write: u8 = 0x30;
const command_identify: u8 = 0xec;
const command_flush: u8 = 0xe7;

pub const Controller = struct {
    sectors: u64 = 0,
    present: bool = false,
    flush_supported: bool = false,

    pub fn probe(self: *Controller) block.Error!void {
        out8(control, 0);
        select(0xe0);
        out8(io_base + 2, 0);
        out8(io_base + 3, 0);
        out8(io_base + 4, 0);
        out8(io_base + 5, 0);
        out8(io_base + 7, command_identify);
        const initial = in8(io_base + 7);
        if (initial == 0 or initial == 0xff) return error.NoDevice;
        try waitDataRequest();
        var words: [256]u16 = undefined;
        for (&words) |*word| word.* = in16(io_base);
        if ((words[49] & (1 << 9)) == 0) return error.IoFailure;
        const count = @as(u32, words[61]) << 16 | words[60];
        if (count == 0 or count > block.lba28_sector_limit) return error.IoFailure;
        self.sectors = count;
        self.flush_supported = (words[83] & 0xc000) == 0x4000 and (words[83] & (1 << 12)) != 0;
        self.present = true;
    }

    pub fn device(self: *Controller) block.Device {
        if (!self.present) return .{};
        return .{
            .backend = .{ .context = self, .read_fn = read, .write_fn = write, .flush_fn = flush },
            .sector_count = self.sectors,
        };
    }

    fn read(ctx: *anyopaque, lba: u64, count: u16, output: []u8) block.Error!void {
        const self: *Controller = @ptrCast(@alignCast(ctx));
        if (!self.present) return error.NoDevice;
        if (!self.flush_supported) return error.UnsupportedFlush;
        try command(lba, count, command_read);
        var at: usize = 0;
        while (at < output.len) : (at += 2) {
            const word = try nextWord();
            output[at] = @truncate(word);
            output[at + 1] = @truncate(word >> 8);
        }
        try waitNotBusy();
        try checkStatus();
    }

    fn write(ctx: *anyopaque, lba: u64, count: u16, input: []const u8) block.Error!void {
        const self: *Controller = @ptrCast(@alignCast(ctx));
        if (!self.present) return error.NoDevice;
        try command(lba, count, command_write);
        var at: usize = 0;
        while (at < input.len) {
            try waitDataRequest();
            const sector_end = at + block.sector_size;
            while (at < sector_end) : (at += 2) {
                const word = @as(u16, input[at]) | (@as(u16, input[at + 1]) << 8);
                out16(io_base, word);
            }
        }
        try waitNotBusy();
        try checkStatus();
    }

    fn flush(ctx: *anyopaque) block.Error!void {
        const self: *Controller = @ptrCast(@alignCast(ctx));
        if (!self.present) return error.NoDevice;
        select(0xe0);
        out8(io_base + 7, command_flush);
        try waitNotBusy();
        try checkStatus();
    }
};

fn command(lba: u64, count: u16, opcode: u8) block.Error!void {
    try waitNotBusy();
    select(0xe0 | @as(u8, @truncate((lba >> 24) & 0x0f)));
    out8(io_base + 1, 0);
    out8(io_base + 2, @truncate(count));
    out8(io_base + 3, @truncate(lba));
    out8(io_base + 4, @truncate(lba >> 8));
    out8(io_base + 5, @truncate(lba >> 16));
    out8(io_base + 7, opcode);
    ioDelay();
}

fn waitDataRequest() block.Error!void {
    var attempts: usize = 0;
    while (attempts < poll_limit) : (attempts += 1) {
        const status = in8(io_base + 7);
        if (status == 0xff) return error.NoDevice;
        if ((status & 0x21) != 0) return error.IoFailure;
        if ((status & 0x80) == 0 and (status & 0x08) != 0) return;
    }
    return error.Timeout;
}

fn nextWord() block.Error!u16 {
    var attempts: usize = 0;
    while (attempts < poll_limit) : (attempts += 1) {
        const status = in8(io_base + 7);
        if (status == 0xff) return error.NoDevice;
        if ((status & 0x21) != 0) return error.IoFailure;
        if ((status & 0x80) == 0 and (status & 0x08) != 0) return in16(io_base);
    }
    return error.Timeout;
}

fn waitNotBusy() block.Error!void {
    var attempts: usize = 0;
    while (attempts < poll_limit) : (attempts += 1) {
        const status = in8(io_base + 7);
        if (status == 0xff) return error.NoDevice;
        if ((status & 0x80) == 0) return;
    }
    return error.Timeout;
}

fn checkStatus() block.Error!void {
    const status = in8(io_base + 7);
    if (status == 0xff) return error.NoDevice;
    if ((status & 0x21) != 0) return error.IoFailure;
}

fn select(value: u8) void { out8(io_base + 6, value); ioDelay(); }
fn ioDelay() void { _ = in8(control); _ = in8(control); _ = in8(control); _ = in8(control); }
fn in8(port: u16) u8 { return asm volatile ("inb %dx, %al" : [value] "={al}" (-> u8), : [port] "{dx}" (port)); }
fn in16(port: u16) u16 { return asm volatile ("inw %dx, %ax" : [value] "={ax}" (-> u16), : [port] "{dx}" (port)); }
fn out8(port: u16, value: u8) void { asm volatile ("outb %al, %dx" : : [value] "{al}" (value), [port] "{dx}" (port)); }
fn out16(port: u16, value: u16) void { asm volatile ("outw %ax, %dx" : : [value] "{ax}" (value), [port] "{dx}" (port)); }
