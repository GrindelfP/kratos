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
    pub fn fillRect(self: *Surface, x: usize, y: usize, width: usize, height: usize, color: Color) void {
        if (x >= self.width or y >= self.height) return;
        const right = x + @min(width, self.width - x);
        const bottom = y + @min(height, self.height - y);
        for (y..bottom) |row| for (x..right) |column| self.pixel(@intCast(column), @intCast(row), color);
    }
};

// Five-by-five bitmap glyphs are doubled into the 12x12 cell for readability.
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const glyphs = [_][5]u8{
    .{ 14, 17, 17, 31, 17 }, .{ 30, 17, 17, 30, 17 }, .{ 14, 17, 16, 16, 14 }, .{ 30, 17, 17, 17, 30 }, .{ 31, 16, 16, 30, 31 }, .{ 31, 16, 16, 30, 16 }, .{ 14, 17, 16, 23, 15 }, .{ 17, 17, 31, 17, 17 }, .{ 14, 4, 4, 4, 14 },    .{ 7, 2, 2, 18, 12 },   .{ 17, 18, 28, 18, 17 }, .{ 16, 16, 16, 16, 31 }, .{ 17, 27, 21, 17, 17 }, .{ 17, 25, 21, 19, 17 }, .{ 14, 17, 17, 17, 14 }, .{ 30, 17, 17, 30, 16 }, .{ 14, 17, 17, 21, 10 }, .{ 30, 17, 17, 30, 17 }, .{ 15, 16, 14, 1, 30 }, .{ 31, 4, 4, 4, 4 }, .{ 17, 17, 17, 17, 14 }, .{ 17, 17, 17, 10, 4 }, .{ 17, 17, 21, 21, 10 }, .{ 17, 10, 4, 10, 17 }, .{ 17, 10, 4, 4, 4 }, .{ 31, 2, 4, 8, 31 },
    .{ 14, 17, 19, 21, 25 }, .{ 4, 12, 4, 4, 14 },    .{ 14, 17, 2, 8, 31 },   .{ 30, 1, 6, 1, 30 },    .{ 2, 6, 10, 31, 2 },    .{ 31, 16, 30, 1, 30 },  .{ 14, 16, 30, 17, 14 }, .{ 31, 1, 2, 4, 4 },     .{ 14, 17, 14, 17, 14 }, .{ 14, 17, 15, 1, 14 },
};
const lowercase_glyphs = [_][5]u8{
    .{ 0, 14, 1, 15, 15 }, .{ 16, 16, 30, 17, 30 }, .{ 0, 14, 16, 16, 14 }, .{ 1, 1, 15, 17, 15 }, .{ 0, 14, 31, 16, 14 }, .{ 6, 8, 28, 8, 8 }, .{ 0, 15, 17, 15, 1 }, .{ 16, 16, 30, 17, 17 }, .{ 4, 0, 12, 4, 14 }, .{ 2, 0, 2, 2, 18 }, .{ 16, 18, 28, 18, 17 }, .{ 12, 4, 4, 4, 14 }, .{ 0, 26, 21, 21, 21 }, .{ 0, 30, 17, 17, 17 }, .{ 0, 14, 17, 17, 14 }, .{ 0, 30, 17, 30, 16 }, .{ 0, 15, 17, 15, 1 }, .{ 0, 22, 24, 16, 16 }, .{ 0, 15, 24, 7, 30 }, .{ 8, 28, 8, 8, 6 }, .{ 0, 17, 17, 19, 13 }, .{ 0, 17, 17, 10, 4 }, .{ 0, 17, 21, 21, 10 }, .{ 0, 17, 10, 4, 10 }, .{ 0, 17, 17, 15, 1 }, .{ 0, 31, 2, 4, 31 },
};
// 5x5 source glyphs are drawn as 3x3 pixels in an 18x20 cell. The unused
// horizontal/vertical cell space gives adjacent text a little breathing room.
pub const font_width = 18;
pub const font_height = 20;
pub fn drawGlyph(surface: *Surface, x: isize, y: isize, byte: u8, fg: Color, bg: Color) void {
    const index = std.mem.indexOfScalar(u8, alphabet, byte);
    const lower_index = if (byte >= 'a' and byte <= 'z') @as(usize, byte - 'a') else null;
    const special: ?[5]u8 = switch (byte) {
        ' ' => .{ 0, 0, 0, 0, 0 }, '.' => .{ 0, 0, 0, 0, 4 }, ',' => .{ 0, 0, 0, 4, 8 }, ':' => .{ 0, 4, 0, 4, 0 }, ';' => .{ 0, 4, 0, 4, 8 }, '!' => .{ 4, 4, 4, 0, 4 }, '?' => .{ 14, 17, 2, 4, 4 }, '-' => .{ 0, 0, 31, 0, 0 }, '_' => .{ 0, 0, 0, 0, 31 }, '/' => .{ 1, 2, 4, 8, 16 }, '>' => .{ 16, 8, 4, 8, 16 }, '<' => .{ 1, 2, 4, 2, 1 }, '=' => .{ 0, 31, 0, 31, 0 }, '|' => .{ 4, 4, 4, 4, 4 }, '+' => .{ 0, 4, 14, 4, 0 }, '\'' => .{ 4, 4, 8, 0, 0 }, '"' => .{ 10, 10, 0, 0, 0 }, '#' => .{ 10, 31, 10, 31, 10 }, '*' => .{ 0, 21, 14, 21, 0 }, else => null,
    };
    const rows = if (index) |i| glyphs[i] else if (lower_index) |i| lowercase_glyphs[i] else special orelse .{ 0, 0, 0, 0, 0 };
    for (0..font_height) |row| for (0..font_width) |col| {
        const glyph_row = row / 3;
        const glyph_col = col / 3;
        const on = glyph_row < 5 and glyph_col < 5 and (rows[glyph_row] & (@as(u8, 1) << @intCast(4 - glyph_col))) != 0;
        surface.pixel(x + @as(isize, @intCast(col)), y + @as(isize, @intCast(row)), if (on) fg else bg);
    };
}

pub fn drawGlyphScaled(surface: *Surface, x: isize, y: isize, byte: u8, fg: Color, bg: Color, scale: usize) void {
    if (scale == 0) return;
    var base: [font_width * font_height * 4]u8 = @splat(0);
    var scratch = Surface.init(&base, font_width, font_height, font_width * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
    drawGlyph(&scratch, 0, 0, byte, fg, bg);
    for (0..font_height) |row| for (0..font_width) |col| {
        const pixel = (@as(usize, @intCast(base[(row * font_width + col) * 4 + 2])) << 16) | (@as(usize, @intCast(base[(row * font_width + col) * 4 + 1])) << 8) | base[(row * font_width + col) * 4];
        for (0..scale) |dy| for (0..scale) |dx| surface.pixel(x + @as(isize, @intCast(col * scale + dx)), y + @as(isize, @intCast(row * scale + dy)), @intCast(pixel));
    };
}

pub const Console = struct {
    surface: *Surface,
    x: usize = 0,
    y: usize = 0,
    fg: Color = 0xffffff,
    bg: Color = 0,
    bottom_padding: usize = 0,
    pub fn clear(self: *Console) void {
        self.surface.fill(self.bg);
        self.x = 0;
        self.y = 0;
    }
    fn newline(self: *Console) void {
        self.x = 0;
        self.y += font_height;
        const usable_height = self.surface.height -| self.bottom_padding;
        if (self.y + font_height > usable_height) {
            const rows = usable_height -| font_height;
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
                if (self.y + font_height > self.surface.height -| self.bottom_padding) self.newline();
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
test "scaled glyph preserves RGB channel order and clipped fillRect stays bounded" {
    var mem: [12 * 12 * 4]u8 = @splat(0xaa);
    var s = Surface.init(&mem, 12, 12, 12 * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
    drawGlyphScaled(&s, 0, 0, 'K', 0xe34234, 0x140d0d, 1);
    try std.testing.expectEqualSlices(u8, &.{ 0x34, 0x42, 0xe3, 0 }, mem[0..4]);
    var rect_mem: [12 * 12 * 4]u8 = @splat(0xaa);
    var rect_surface = Surface.init(&rect_mem, 12, 12, 12 * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
    rect_surface.fillRect(10, 10, std.math.maxInt(usize), std.math.maxInt(usize), 0x123456);
    try std.testing.expectEqual(@as(u8, 0x12), rect_mem[(10 * 12 + 10) * 4 + 2]);
    try std.testing.expectEqual(@as(u8, 0xaa), rect_mem[(9 * 12 + 10) * 4]);
}
test "renders lowercase letters and spaces as distinct readable glyphs" {
    var mem: [font_width * font_height * 4]u8 = @splat(0);
    var s = Surface.init(&mem, font_width, font_height, font_width * 4, rgb).?;
    drawGlyph(&s, 0, 0, 'a', 0xffffff, 0);
    const lowercase = mem;
    @memset(&mem, 0);
    drawGlyph(&s, 0, 0, 'A', 0xffffff, 0);
    try std.testing.expect(!std.mem.eql(u8, &lowercase, &mem));
    @memset(&mem, 0);
    drawGlyph(&s, 0, 0, ' ', 0xffffff, 0);
    for (mem) |pixel| try std.testing.expectEqual(@as(u8, 0), pixel);
}
test "console wraps, backspaces, and scrolls within surface" {
    var mem: [36 * 40 * 4]u8 = @splat(0);
    var s = Surface.init(&mem, 36, 40, 36 * 4, rgb).?;
    var c = Console{ .surface = &s };
    c.write("ABC\x08\n123\nXYZ");
    try std.testing.expect(c.x <= s.width and c.y + font_height <= s.height);
}

test "font uses 18x20 cells and padded console scrolling preserves bottom inset" {
    try std.testing.expectEqual(@as(usize, 18), font_width);
    try std.testing.expectEqual(@as(usize, 20), font_height);
    var mem: [36 * 80 * 4]u8 = @splat(0);
    var s = Surface.init(&mem, 36, 80, 36 * 4, rgb).?;
    var c = Console{ .surface = &s, .bottom_padding = font_height };
    c.write("one\ntwo\nthree\nfour\nfive");
    try std.testing.expect(c.y + font_height <= s.height - c.bottom_padding);
    try std.testing.expect(c.x <= s.width);
}
