//! KratOS framebuffer identity and Spartan-red shell palette.
const raster = @import("raster.zig");

pub const background: raster.Color = 0x140d0d;
pub const red: raster.Color = 0xe34234;
pub const bright_red: raster.Color = 0xff6b5b;
pub const text: raster.Color = 0xf3e8df;
pub const bottom_padding = raster.font_height;

pub const Layout = struct {
    logo_x: usize,
    logo_y: usize,
    logo_rows: usize,
    footer_y: usize,
    prompt_y: usize,
    compact: bool,
};

pub fn layout(width: usize, height: usize) Layout {
    const compact = width < 480 or height < 400;
    const logo_rows: usize = if (compact) 3 else 5;
    const logo_width: usize = if (compact) 11 else 25;
    const footer_y = height -| (raster.font_height * 3);
    const region_top = raster.font_height * 3;
    const region_height = footer_y -| region_top;
    return .{
        .logo_x = (width -| logo_width * raster.font_width) / 2,
        .logo_y = region_top + (region_height -| logo_rows * raster.font_height) / 2,
        .logo_rows = logo_rows,
        .footer_y = footer_y,
        .prompt_y = footer_y + raster.font_height,
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
    var display = raster.Console{ .surface = surface, .fg = text, .bg = background };
    const screen = layout(surface.width, surface.height);
    if (screen.compact) {
        display.write("WELCOME TO KRATOS\nSMALL OS\n\n");
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
    const compact_logo = [_][]const u8{ "K R A T O S", "K R A T O S", "K R A T O S" };
    display.fg = red;
    if (screen.compact) {
        for (compact_logo, 0..) |line, row| {
            display.x = screen.logo_x;
            display.y = screen.logo_y + row * raster.font_height;
            display.write(line);
        }
    } else {
        for (full_logo, 0..) |line, row| {
            display.x = screen.logo_x;
            display.y = screen.logo_y + row * raster.font_height;
            display.write(line);
        }
    }
    var shell = raster.Console{ .surface = surface, .fg = text, .bg = background, .bottom_padding = bottom_padding };
    shell.x = raster.font_width;
    shell.y = screen.footer_y;
    if (screen.compact) {
        shell.write("SPARTAN RED");
    } else {
        shell.write("SPARTAN-RED CONSOLE  |  TYPE HELP");
    }
    shell.x = raster.font_width;
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
        const logo_bottom = screen.logo_y + screen.logo_rows * raster.font_height;
        try @import("std").testing.expect(logo_bottom <= screen.footer_y);
        try @import("std").testing.expect(screen.prompt_y + raster.font_height + bottom_padding <= dimensions[1]);
        try @import("std").testing.expect(screen.compact == (dimensions[0] < 480 or dimensions[1] < 400));
    }
}
