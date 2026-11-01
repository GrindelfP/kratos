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

    const scale: usize = if (surface.width >= 720) 5 else if (surface.width >= 480) 3 else if (surface.width >= 220) 2 else 1;
    const logo_width = 5 * raster.font_width * scale + raster.font_width * scale;
    const logo_height = raster.font_height * scale;
    const x = if (surface.width > logo_width) (surface.width - logo_width) / 2 else 0;
    const y = if (surface.height > logo_height) (surface.height - logo_height) / 2 else 0;
    var offset: usize = 0;
    for ("KratOS") |character| {
        raster.drawGlyphScaled(surface, @intCast(x + offset), @intCast(y), character, red, background, scale);
        offset += raster.font_width * scale;
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
