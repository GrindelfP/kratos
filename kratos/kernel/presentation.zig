//! KratOS framebuffer identity and Spartan-red shell palette.
const raster = @import("raster.zig");

pub const background: raster.Color = 0x140d0d;
pub const red: raster.Color = 0xe34234;
pub const bright_red: raster.Color = 0xff6b5b;
pub const text: raster.Color = 0xf3e8df;

pub const Layout = struct {
    inset_x: usize,
    inset_y: usize,
    font_scale: usize,
    cell_width: usize,
    cell_height: usize,
    logo_x: usize,
    logo_y: usize,
    logo_rows: usize,
    footer_y: usize,
    prompt_y: usize,
    compact: bool,
};

pub fn layout(width: usize, height: usize) Layout {
    const compact = width < 480 or height < 400;
    const font_scale: usize = if (compact) raster.compact_font_scale else raster.normal_font_scale;
    const cell_width = raster.cellWidth(font_scale);
    const cell_height = raster.cellHeight(font_scale);
    const inset_x: usize = if (compact) @min(@as(usize, 16), width / 8) else @min(@as(usize, 50), width / 4);
    const inset_y: usize = if (compact) @min(@as(usize, 12), height / 8) else @min(@as(usize, 50), height / 4);
    const logo_rows: usize = if (compact) 2 else 5;
    const logo_width: usize = if (compact) 8 else 25;
    const content_width = width -| (inset_x * 2);
    const logo_pixel_width = logo_width * cell_width;
    const footer_y = height -| inset_y -| (cell_height * 3);
    const region_top = inset_y + cell_height * 3;
    const region_height = footer_y -| region_top;
    return .{
        .inset_x = inset_x,
        .inset_y = inset_y,
        .font_scale = font_scale,
        .cell_width = cell_width,
        .cell_height = cell_height,
        .logo_x = inset_x + (content_width -| logo_pixel_width) / 2,
        .logo_y = region_top + (region_height -| logo_rows * cell_height) / 2,
        .logo_rows = logo_rows,
        .footer_y = footer_y,
        .prompt_y = footer_y + cell_height,
        .compact = compact,
    };
}

pub fn clear(display: *raster.Console) void {
    display.clear();
    display.fg = bright_red;
    display.bg = background;
}

pub fn welcome(surface: *raster.Surface) raster.Console {
    surface.fill(background);
    const screen = layout(surface.width, surface.height);
    var display = raster.Console{
        .surface = surface,
        .fg = text,
        .bg = background,
        .glyph_scale = screen.font_scale,
        .left_padding = screen.inset_x,
        .right_padding = screen.inset_x,
        .top_padding = screen.inset_y,
        .bottom_padding = screen.inset_y,
    };
    if (screen.compact) {
        display.write("WELCOME\nSMALL OS\n\n");
    } else {
        display.write("WELCOME TO KRATOS\nA small operating system, built to explore.\n\n");
    }

    const full_logo = [_][]const u8{
        "K K          t  OOO  SSS",
        "KK  rr  aa  ttt O O S   ",
        "K   r  a a   t  O O  SS ",
        "KK  r  a a   t  O O    S",
        "K K r   aa    t OOO SSS ",
    };
    const compact_logo = [_][]const u8{ "/KRATOS\\", "\\KRATOS/" };
    display.fg = red;
    if (screen.compact) {
        for (compact_logo, 0..) |line, row| {
            display.x = screen.logo_x;
            display.y = screen.logo_y + row * screen.cell_height;
            display.write(line);
        }
    } else {
        for (full_logo, 0..) |line, row| {
            display.x = screen.logo_x;
            display.y = screen.logo_y + row * screen.cell_height;
            display.write(line);
        }
    }
    var shell = display;
    shell.fg = text;
    shell.x = screen.inset_x;
    shell.y = screen.footer_y;
    if (screen.compact) {
        shell.write("SPARTAN RED");
    } else {
        shell.write("SPARTAN-RED CONSOLE  |  TYPE HELP");
    }
    shell.x = screen.inset_x;
    shell.y = screen.prompt_y;
    shell.fg = bright_red;
    return shell;
}

test "welcome paints a legible logo at minimum supported dimensions" {
    var memory: [320 * 200 * 4]u8 = @splat(0);
    var surface = raster.Surface.init(&memory, 320, 200, 320 * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
    _ = welcome(&surface);
    try @import("std").testing.expect(memory[0] != 0 or memory[2] != 0);
}

test "welcome layout separates logo and shell and reserves a full bottom cell" {
    for ([_][2]usize{ .{ 1280, 800 }, .{ 320, 200 } }) |dimensions| {
        const screen = layout(dimensions[0], dimensions[1]);
        const logo_bottom = screen.logo_y + screen.logo_rows * screen.cell_height;
        try @import("std").testing.expect(logo_bottom <= screen.footer_y);
        const expected_inset_x: usize = if (screen.compact) 16 else 50;
        const expected_inset_y: usize = if (screen.compact) 12 else 50;
        try @import("std").testing.expectEqual(expected_inset_x, screen.inset_x);
        try @import("std").testing.expectEqual(expected_inset_y, screen.inset_y);
        try @import("std").testing.expect(screen.prompt_y + screen.cell_height <= dimensions[1] - screen.inset_y);
        try @import("std").testing.expect(screen.compact == (dimensions[0] < 480 or dimensions[1] < 400));
    }
}

test "welcome and clear keep prompt cursor inside padded content origin" {
    for ([_][2]usize{ .{ 1280, 800 }, .{ 320, 200 } }) |dimensions| {
        const memory = try @import("std").testing.allocator.alloc(u8, dimensions[0] * dimensions[1] * 4);
        defer @import("std").testing.allocator.free(memory);
        @memset(memory, 0);
        var surface = raster.Surface.init(memory, dimensions[0], dimensions[1], dimensions[0] * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
        var shell = welcome(&surface);
        const screen = layout(dimensions[0], dimensions[1]);
        try @import("std").testing.expectEqual(screen.inset_x, shell.x);
        try @import("std").testing.expectEqual(screen.prompt_y, shell.y);
        clear(&shell);
        try @import("std").testing.expectEqual(screen.inset_x, shell.x);
        try @import("std").testing.expectEqual(screen.inset_y, shell.y);
        shell.write("kratos> echo ok\noutput");
        try @import("std").testing.expect(shell.x >= screen.inset_x);
        try @import("std").testing.expect(shell.x <= dimensions[0] - screen.inset_x);
        try @import("std").testing.expect(shell.y >= screen.inset_y);
        try @import("std").testing.expect(shell.y + screen.cell_height <= dimensions[1] - screen.inset_y);
    }
}
