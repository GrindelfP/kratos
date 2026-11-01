//! Hardware-independent packed RGB framebuffer, 5x7 font, and bounded text console.
const std = @import("std");

pub const Color = u32; // 0xRRGGBB
pub const PixelFormat = struct { red_size: u8, red_shift: u8, green_size: u8, green_shift: u8, blue_size: u8, blue_shift: u8 };
pub const Surface = struct {
    bytes: []volatile u8,
    width: usize,
    height: usize,
    pitch: usize,
    format: PixelFormat,

    pub fn init(bytes: []volatile u8, width: usize, height: usize, pitch: usize, format: PixelFormat) ?Surface {
        if (width == 0 or height == 0 or width > 16384 or height > 16384) return null;
        if (format.red_size != 8 or format.green_size != 8 or format.blue_size != 8 or format.red_shift % 8 != 0 or format.green_shift % 8 != 0 or format.blue_shift % 8 != 0) return null;
        if (format.red_shift > 24 or format.green_shift > 24 or format.blue_shift > 24) return null;
        if (format.red_shift == format.green_shift or format.red_shift == format.blue_shift or format.green_shift == format.blue_shift) return null;
        const row = std.math.mul(usize, width, 4) catch return null;
        if (pitch < row) return null;
        const need = std.math.mul(usize, pitch, height) catch return null;
        if (need > bytes.len) return null;
        return .{ .bytes = bytes, .width = width, .height = height, .pitch = pitch, .format = format };
    }
    pub fn pixel(self: *Surface, x: isize, y: isize, color: Color) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return;
        const at = @as(usize, @intCast(y)) * self.pitch + @as(usize, @intCast(x)) * 4;
        const shifts = [_]u8{ self.format.red_shift, self.format.green_shift, self.format.blue_shift };
        const channels = [_]u8{ @truncate(color >> 16), @truncate(color >> 8), @truncate(color) };
        for (0..3) |i| self.bytes[at + shifts[i] / 8] = channels[i];
        self.bytes[at + 3] = 0;
    }
    pub fn fill(self: *Surface, color: Color) void {
        for (0..self.height) |y| for (0..self.width) |x| self.pixel(@intCast(x), @intCast(y), color);
    }
};

// Five columns, five rows plus spacing; lowercase uses readable uppercase fallback.
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const glyphs = [_][5]u8{
    .{ 14, 17, 17, 31, 17 }, .{ 30, 17, 17, 30, 17 }, .{ 14, 17, 16, 16, 14 }, .{ 30, 17, 17, 17, 30 }, .{ 31, 16, 16, 30, 31 }, .{ 31, 16, 16, 30, 16 }, .{ 14, 17, 16, 23, 15 }, .{ 17, 17, 31, 17, 17 }, .{ 14, 4, 4, 4, 14 },    .{ 7, 2, 2, 18, 12 },   .{ 17, 18, 28, 18, 17 }, .{ 16, 16, 16, 16, 31 }, .{ 17, 27, 21, 17, 17 }, .{ 17, 25, 21, 19, 17 }, .{ 14, 17, 17, 17, 14 }, .{ 30, 17, 17, 30, 16 }, .{ 14, 17, 17, 21, 10 }, .{ 30, 17, 17, 30, 17 }, .{ 15, 16, 14, 1, 30 }, .{ 31, 4, 4, 4, 4 }, .{ 17, 17, 17, 17, 14 }, .{ 17, 17, 17, 10, 4 }, .{ 17, 17, 21, 21, 10 }, .{ 17, 10, 4, 10, 17 }, .{ 17, 10, 4, 4, 4 }, .{ 31, 2, 4, 8, 31 },
    .{ 14, 17, 19, 21, 25 }, .{ 4, 12, 4, 4, 14 },    .{ 14, 17, 2, 8, 31 },   .{ 30, 1, 6, 1, 30 },    .{ 2, 6, 10, 31, 2 },    .{ 31, 16, 30, 1, 30 },  .{ 14, 16, 30, 17, 14 }, .{ 31, 1, 2, 4, 4 },     .{ 14, 17, 14, 17, 14 }, .{ 14, 17, 15, 1, 14 },
};
pub const font_width = 6;
pub const font_height = 6;
pub fn drawGlyph(surface: *Surface, x: isize, y: isize, byte: u8, fg: Color, bg: Color) void {
    var c = byte;
    if (c >= 'a' and c <= 'z') c -= 32;
    const index = std.mem.indexOfScalar(u8, alphabet, c);
    for (0..font_height) |row| for (0..font_width) |col| {
        const on = if (index) |i| row < 5 and col < 5 and (glyphs[i][row] & (@as(u8, 1) << @intCast(4 - col))) != 0 else false;
        surface.pixel(x + @as(isize, @intCast(col)), y + @as(isize, @intCast(row)), if (on) fg else bg);
    };
}

pub const Console = struct {
    surface: *Surface,
    x: usize = 0,
    y: usize = 0,
    fg: Color = 0xffffff,
    bg: Color = 0,
    pub fn clear(self: *Console) void {
        self.surface.fill(self.bg);
        self.x = 0;
        self.y = 0;
    }
    fn newline(self: *Console) void {
        self.x = 0;
        self.y += font_height;
        if (self.y + font_height > self.surface.height) {
            const rows = self.surface.height -| font_height;
            for (0..rows) |y| for (0..self.surface.width) |x| {
                const src = (y + font_height) * self.surface.pitch + x * 4;
                const dst = y * self.surface.pitch + x * 4;
                for (0..4) |b| self.surface.bytes[dst + b] = self.surface.bytes[src + b];
            };
            self.y = rows -| rows % font_height;
            for (rows..self.surface.height) |y| for (0..self.surface.width) |x| self.surface.pixel(@intCast(x), @intCast(y), self.bg);
        }
    }
    pub fn write(self: *Console, text: []const u8) void {
        for (text) |c| switch (c) {
            '\n' => self.newline(),
            '\r' => self.x = 0,
            8, 127 => {
                if (self.x >= font_width) self.x -= font_width else if (self.y >= font_height) {
                    self.y -= font_height;
                    self.x = self.surface.width / font_width * font_width -| font_width;
                }
                drawGlyph(self.surface, @intCast(self.x), @intCast(self.y), ' ', self.fg, self.bg);
            },
            else => {
                if (self.x + font_width > self.surface.width) self.newline();
                if (self.y + font_height > self.surface.height) self.newline();
                drawGlyph(self.surface, @intCast(self.x), @intCast(self.y), c, self.fg, self.bg);
                self.x += font_width;
            },
        };
    }
};

const rgb = PixelFormat{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 };
test "validates pitch, allocation and format; clips drawing" {
    var mem: [64]u8 = @splat(0);
    var s = Surface.init(&mem, 3, 2, 16, rgb).?;
    s.pixel(-1, 0, 0xffffff);
    s.pixel(2, 1, 0x123456);
    try std.testing.expectEqual(@as(u8, 0x12), mem[16 + 8 + 2]);
    try std.testing.expect(Surface.init(&mem, 3, 2, 11, rgb) == null);
    try std.testing.expect(Surface.init(&mem, 3, 2, 16, .{ .red_size = 5, .red_shift = 11, .green_size = 6, .green_shift = 5, .blue_size = 5, .blue_shift = 0 }) == null);
}
test "supports alternate RGB channel byte order without touching row padding" {
    var mem: [32]u8 = @splat(0xaa);
    var s = Surface.init(&mem, 1, 2, 16, .{ .red_size = 8, .red_shift = 0, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 16 }).?;
    s.pixel(0, 0, 0x123456);
    try std.testing.expectEqualSlices(u8, &.{ 0x12, 0x34, 0x56, 0 }, mem[0..4]);
    try std.testing.expectEqual(@as(u8, 0xaa), mem[4]);
}
test "console wraps, backspaces, and scrolls within surface" {
    var mem: [768]u8 = @splat(0);
    var s = Surface.init(&mem, 12, 16, 48, rgb).?;
    var c = Console{ .surface = &s };
    c.write("ABC\x08\n123\nXYZ");
    try std.testing.expect(c.x <= s.width and c.y + font_height <= s.height);
}
