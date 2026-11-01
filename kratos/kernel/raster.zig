//! Hardware-independent packed RGB framebuffer, scalable 5x5 font, and bounded text console.
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

// Five-by-five bitmap glyphs are rasterized at a configurable integer scale.
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const glyphs = [_][5]u8{
    .{ 14, 17, 17, 31, 17 }, .{ 30, 17, 17, 30, 17 }, .{ 14, 17, 16, 16, 14 }, .{ 30, 17, 17, 17, 30 }, .{ 31, 16, 16, 30, 31 }, .{ 31, 16, 16, 30, 16 }, .{ 14, 17, 16, 23, 15 }, .{ 17, 17, 31, 17, 17 }, .{ 14, 4, 4, 4, 14 },    .{ 7, 2, 2, 18, 12 },   .{ 17, 18, 28, 18, 17 }, .{ 16, 16, 16, 16, 31 }, .{ 17, 27, 21, 17, 17 }, .{ 17, 25, 21, 19, 17 }, .{ 14, 17, 17, 17, 14 }, .{ 30, 17, 17, 30, 16 }, .{ 14, 17, 17, 21, 10 }, .{ 30, 17, 17, 30, 17 }, .{ 15, 16, 14, 1, 30 }, .{ 31, 4, 4, 4, 4 }, .{ 17, 17, 17, 17, 14 }, .{ 17, 17, 17, 10, 4 }, .{ 17, 17, 21, 21, 10 }, .{ 17, 10, 4, 10, 17 }, .{ 17, 10, 4, 4, 4 }, .{ 31, 2, 4, 8, 31 },
    .{ 14, 17, 19, 21, 25 }, .{ 4, 12, 4, 4, 14 },    .{ 14, 17, 2, 8, 31 },   .{ 30, 1, 6, 1, 30 },    .{ 2, 6, 10, 31, 2 },    .{ 31, 16, 30, 1, 30 },  .{ 14, 16, 30, 17, 14 }, .{ 31, 1, 2, 4, 4 },     .{ 14, 17, 14, 17, 14 }, .{ 14, 17, 15, 1, 14 },
};
const lowercase_glyphs = [_][5]u8{
    .{ 0, 14, 1, 15, 15 }, .{ 16, 16, 30, 17, 30 }, .{ 0, 14, 16, 16, 14 }, .{ 1, 1, 15, 17, 15 }, .{ 0, 14, 31, 16, 14 }, .{ 6, 8, 28, 8, 8 }, .{ 0, 15, 17, 15, 1 }, .{ 16, 16, 30, 17, 17 }, .{ 4, 0, 12, 4, 14 }, .{ 2, 0, 2, 2, 18 }, .{ 16, 18, 28, 18, 17 }, .{ 12, 4, 4, 4, 14 }, .{ 0, 26, 21, 21, 21 }, .{ 0, 30, 17, 17, 17 }, .{ 0, 14, 17, 17, 14 }, .{ 0, 30, 17, 30, 16 }, .{ 0, 15, 17, 15, 1 }, .{ 0, 22, 24, 16, 16 }, .{ 0, 15, 24, 7, 30 }, .{ 8, 28, 8, 8, 6 }, .{ 0, 17, 17, 19, 13 }, .{ 0, 17, 17, 10, 4 }, .{ 0, 17, 21, 21, 10 }, .{ 0, 17, 10, 4, 10 }, .{ 0, 17, 17, 15, 1 }, .{ 0, 31, 2, 4, 31 },
};
// Normal display uses 4x4 glyph pixels in 24x28 cells; the compact mode uses
// 3x3 pixels in 18x20 cells. Cell helpers centralize the baseline/spacing.
pub const normal_font_scale = 4;
pub const compact_font_scale = 3;
pub fn cellWidth(scale: usize) usize { return scale * 6; }
pub fn cellHeight(scale: usize) usize { return scale * 8 - 4; }
pub const font_width = cellWidth(normal_font_scale);
pub const font_height = cellHeight(normal_font_scale);
pub fn drawGlyph(surface: *Surface, x: isize, y: isize, byte: u8, fg: Color, bg: Color, scale: usize) void {
    if (scale == 0) return;
    const width = cellWidth(scale);
    const height = cellHeight(scale);
    const index = std.mem.indexOfScalar(u8, alphabet, byte);
    const lower_index = if (byte >= 'a' and byte <= 'z') @as(usize, byte - 'a') else null;
    const special: ?[5]u8 = switch (byte) {
        ' ' => .{ 0, 0, 0, 0, 0 }, '.' => .{ 0, 0, 0, 0, 4 }, ',' => .{ 0, 0, 0, 4, 8 }, ':' => .{ 0, 4, 0, 4, 0 }, ';' => .{ 0, 4, 0, 4, 8 }, '!' => .{ 4, 4, 4, 0, 4 }, '?' => .{ 14, 17, 2, 4, 4 }, '-' => .{ 0, 0, 31, 0, 0 }, '_' => .{ 0, 0, 0, 0, 31 }, '/' => .{ 1, 2, 4, 8, 16 }, '>' => .{ 16, 8, 4, 8, 16 }, '<' => .{ 1, 2, 4, 2, 1 }, '=' => .{ 0, 31, 0, 31, 0 }, '|' => .{ 4, 4, 4, 4, 4 }, '+' => .{ 0, 4, 14, 4, 0 }, '\'' => .{ 4, 4, 8, 0, 0 }, '"' => .{ 10, 10, 0, 0, 0 }, '#' => .{ 10, 31, 10, 31, 10 }, '*' => .{ 0, 21, 14, 21, 0 }, else => null,
    };
    const rows = if (index) |i| glyphs[i] else if (lower_index) |i| lowercase_glyphs[i] else special orelse .{ 0, 0, 0, 0, 0 };
    for (0..height) |row| for (0..width) |col| {
        const glyph_row = row / scale;
        const glyph_col = col / scale;
        const on = glyph_row < 5 and glyph_col < 5 and (rows[glyph_row] & (@as(u8, 1) << @intCast(4 - glyph_col))) != 0;
        surface.pixel(x + @as(isize, @intCast(col)), y + @as(isize, @intCast(row)), if (on) fg else bg);
    };
}

pub fn drawGlyphScaled(surface: *Surface, x: isize, y: isize, byte: u8, fg: Color, bg: Color, scale: usize) void {
    if (scale == 0) return;
    var base: [font_width * font_height * 4]u8 = @splat(0);
    var scratch = Surface.init(&base, font_width, font_height, font_width * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
    drawGlyph(&scratch, 0, 0, byte, fg, bg, normal_font_scale);
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
    glyph_scale: usize = normal_font_scale,
    left_padding: usize = 0,
    right_padding: usize = 0,
    top_padding: usize = 0,
    bottom_padding: usize = 0,
    fn cellW(self: *const Console) usize { return cellWidth(self.glyph_scale); }
    fn cellH(self: *const Console) usize { return cellHeight(self.glyph_scale); }
    pub fn clear(self: *Console) void {
        self.surface.fill(self.bg);
        self.x = @min(self.left_padding, self.surface.width);
        self.y = @min(self.top_padding, self.surface.height);
    }
    fn newline(self: *Console) void {
        const ch = self.cellH();
        const left = @min(self.left_padding, self.surface.width);
        const right = self.surface.width -| self.right_padding;
        const top = @min(self.top_padding, self.surface.height);
        const bottom = self.surface.height -| self.bottom_padding;
        self.x = left;
        self.y += ch;
        if (self.y + ch > bottom) {
            const rows = bottom -| top -| ch;
            for (0..rows) |row| for (left..right) |column| {
                const src = (top + row + ch) * self.surface.pitch + column * 4;
                const dst = (top + row) * self.surface.pitch + column * 4;
                for (0..4) |b| self.surface.bytes[dst + b] = self.surface.bytes[src + b];
            };
            self.y = top + (rows / ch) * ch;
            for (top + rows..bottom) |row| for (left..right) |column| self.surface.pixel(@intCast(column), @intCast(row), self.bg);
        }
    }
    pub fn write(self: *Console, text: []const u8) void {
        for (text) |c| switch (c) {
            '\n' => self.newline(),
            '\r' => self.x = @min(self.left_padding, self.surface.width),
            8, 127 => {
                const cw = self.cellW();
                const ch = self.cellH();
                const left = @min(self.left_padding, self.surface.width);
                const right = self.surface.width -| self.right_padding;
                if (self.x >= left + cw) self.x -= cw else if (self.y >= self.top_padding + ch) {
                    self.y -= ch;
                    self.x = left + ((right -| left) / cw) * cw -| cw;
                }
                drawGlyph(self.surface, @intCast(self.x), @intCast(self.y), ' ', self.fg, self.bg, self.glyph_scale);
            },
            else => {
                const cw = self.cellW();
                if (self.x + cw > self.surface.width -| self.right_padding) self.newline();
                if (self.y + self.cellH() > self.surface.height -| self.bottom_padding) self.newline();
                drawGlyph(self.surface, @intCast(self.x), @intCast(self.y), c, self.fg, self.bg, self.glyph_scale);
                self.x += cw;
            },
        };
    }
};

/// A single-row, horizontally scrolling input viewport. The full line remains
/// in the editor; only its rightmost cells are painted, with no console scroll.
pub const InputViewport = struct {
    x: usize,
    y: usize,
    columns: usize,

    pub fn begin(console: *Console) InputViewport {
        const cw = cellWidth(console.glyph_scale);
        const right = console.surface.width -| console.right_padding;
        if (console.x + cw > right) console.write("\n");
        return .{ .x = console.x, .y = console.y, .columns = (right -| console.x) / cw };
    }

    pub fn redraw(self: InputViewport, console: *Console, line: []const u8) void {
        const cw = cellWidth(console.glyph_scale);
        const ch = cellHeight(console.glyph_scale);
        console.surface.fillRect(self.x, self.y, self.columns * cw, ch, console.bg);
        const visible = line[line.len - @min(line.len, self.columns)..];
        for (visible, 0..) |c, i| {
            drawGlyph(console.surface, @intCast(self.x + i * cw), @intCast(self.y), c, console.fg, console.bg, console.glyph_scale);
        }
        console.x = self.x + visible.len * cw;
        console.y = self.y;
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
    var mem: [font_width * font_height * 4]u8 = @splat(0xaa);
    var s = Surface.init(&mem, font_width, font_height, font_width * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
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
    drawGlyph(&s, 0, 0, 'a', 0xffffff, 0, normal_font_scale);
    const lowercase = mem;
    @memset(&mem, 0);
    drawGlyph(&s, 0, 0, 'A', 0xffffff, 0, normal_font_scale);
    try std.testing.expect(!std.mem.eql(u8, &lowercase, &mem));
    @memset(&mem, 0);
    drawGlyph(&s, 0, 0, ' ', 0xffffff, 0, normal_font_scale);
    for (mem) |pixel| try std.testing.expectEqual(@as(u8, 0), pixel);
}
test "console wraps, backspaces, and scrolls within surface" {
    var mem: [36 * 40 * 4]u8 = @splat(0);
    var s = Surface.init(&mem, 36, 40, 36 * 4, rgb).?;
    var c = Console{ .surface = &s };
    c.write("ABC\x08\n123\nXYZ");
    try std.testing.expect(c.x <= s.width and c.y + font_height <= s.height);
}

test "normal and compact fonts have documented larger cell bounds" {
    try std.testing.expectEqual(@as(usize, 24), font_width);
    try std.testing.expectEqual(@as(usize, 28), font_height);
    try std.testing.expectEqual(@as(usize, 18), cellWidth(compact_font_scale));
    try std.testing.expectEqual(@as(usize, 20), cellHeight(compact_font_scale));
    var mem: [36 * 80 * 4]u8 = @splat(0);
    var s = Surface.init(&mem, 36, 80, 36 * 4, rgb).?;
    var c = Console{ .surface = &s, .glyph_scale = compact_font_scale, .bottom_padding = cellHeight(compact_font_scale) };
    c.write("one\ntwo\nthree\nfour\nfive");
    try std.testing.expect(c.y + cellHeight(c.glyph_scale) <= s.height - c.bottom_padding);
    try std.testing.expect(c.x <= s.width);
}

test "padded console keeps input, backspace, output, clear and scrolling inside all margins" {
    var mem: [200 * 160 * 4]u8 = @splat(0);
    var s = Surface.init(&mem, 200, 160, 200 * 4, rgb).?;
    var c = Console{ .surface = &s, .left_padding = 24, .right_padding = 24, .top_padding = 28, .bottom_padding = 28 };
    c.clear();
    try std.testing.expectEqual(@as(usize, 24), c.x);
    try std.testing.expectEqual(@as(usize, 28), c.y);
    c.write("kratos> echo abc\x08d\noutput line\nsecond line\nthird line");
    try std.testing.expect(c.x >= c.left_padding);
    try std.testing.expect(c.x <= s.width - c.right_padding);
    try std.testing.expect(c.y >= c.top_padding);
    try std.testing.expect(c.y + c.cellH() <= s.height - c.bottom_padding);
    for (0..s.height) |row| for (0..s.width) |column| {
        if (column >= c.left_padding and column < s.width - c.right_padding and row >= c.top_padding and row < s.height - c.bottom_padding) continue;
        const at = row * s.pitch + column * 4;
        for (0..4) |channel| try std.testing.expectEqual(@as(u8, 0), mem[at + channel]);
    };
    c.clear();
    try std.testing.expectEqual(@as(usize, 24), c.x);
    try std.testing.expectEqual(@as(usize, 28), c.y);
}

test "input viewport replaces long and short lines without stale pixels or padding writes" {
    const width = 320; const height = 200;
    var memory: [width * height * 4]u8 = @splat(0);
    var reference: [width * height * 4]u8 = @splat(0);
    for ([_]usize{ compact_font_scale, normal_font_scale }) |scale| {
        @memset(&memory, 0); @memset(&reference, 0);
        var s = Surface.init(&memory, width, height, width * 4, rgb).?;
        var r = Surface.init(&reference, width, height, width * 4, rgb).?;
        var c = Console{ .surface = &s, .glyph_scale = scale, .left_padding = 16, .right_padding = 16, .top_padding = 12, .bottom_padding = 12, .fg = 0xffffff };
        var expected = Console{ .surface = &r, .glyph_scale = scale, .left_padding = 16, .right_padding = 16, .top_padding = 12, .bottom_padding = 12, .fg = 0xffffff };
        c.clear(); expected.clear(); c.write("kratos> "); expected.write("kratos> ");
        const view = InputViewport.begin(&c); const ref_view = InputViewport.begin(&expected);
        const long = "echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaxyz";
        view.redraw(&c, long);
        ref_view.redraw(&expected, long[long.len - view.columns..]);
        try std.testing.expectEqualSlices(u8, &reference, &memory);
        view.redraw(&c, "echo x");
        ref_view.redraw(&expected, "echo x");
        try std.testing.expectEqualSlices(u8, &reference, &memory);
        view.redraw(&c, long);
        ref_view.redraw(&expected, long);
        try std.testing.expectEqualSlices(u8, &reference, &memory);
        for (0..height) |y| for (0..width) |x| {
            if (x >= 16 and x < width - 16 and y >= 12 and y < height - 12) continue;
            try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, memory[(y * width + x) * 4 ..][0..4]);
        };
    }
}
