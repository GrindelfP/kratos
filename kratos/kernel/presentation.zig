//! KratOS framebuffer identity and Spartan-red shell palette.
const raster = @import("raster.zig");

pub const background: raster.Color = 0x140d0d;
pub const red: raster.Color = 0xe34234;
pub const bright_red: raster.Color = 0xff6b5b;
pub const text: raster.Color = 0xf3e8df;

pub fn clear(display: *raster.Console) void {
    display.clear();
    display.fg = bright_red;
    display.bg = background;
}

pub fn welcome(surface: *raster.Surface) raster.Console {
    surface.fill(background);
    var display = raster.Console{ .surface = surface, .fg = text, .bg = background };
    display.write("WELCOME TO KRATOS\nA small operating system, built to explore.\n\n");

    const logo = [_][]const u8{
        "K  K          OOO   SSS",
        "K K  rrr a a O   O S   ",
        "KK   r   aaa O   O  SS ",
        "K K  r   a a O   O    S",
        "K  K r   aaa  OOO  SSS ",
    };
    const width = logo[0].len * raster.font_width;
    const height = logo.len * raster.font_height;
    const x = (surface.width -| width) / 2;
    const y = (surface.height -| height) / 2;
    display.fg = red;
    for (logo, 0..) |line, row| {
        display.x = x;
        display.y = y + row * raster.font_height;
        display.write(line);
    }
    var shell = raster.Console{ .surface = surface, .fg = text, .bg = background };
    shell.x = raster.font_width;
    shell.y = surface.height -| (raster.font_height * 2);
    if (surface.width < 480) {
        shell.write("SPARTAN RED | HELP");
    } else {
        shell.write("SPARTAN-RED CONSOLE  |  TYPE HELP");
    }
    shell.x = raster.font_width;
    shell.y = surface.height -| raster.font_height;
    shell.fg = bright_red;
    return shell;
}

test "welcome paints a legible logo at minimum supported dimensions" {
    var memory: [320 * 200 * 4]u8 = @splat(0);
    var surface = raster.Surface.init(&memory, 320, 200, 320 * 4, .{ .red_size = 8, .red_shift = 16, .green_size = 8, .green_shift = 8, .blue_size = 8, .blue_shift = 0 }).?;
    _ = welcome(&surface);
    try @import("std").testing.expect(memory[0] != 0 or memory[2] != 0);
}
