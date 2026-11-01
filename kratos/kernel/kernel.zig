// KratOS minimal freestanding x86-64 kernel entry.

const std = @import("std");
const memory_map = @import("memory_map.zig");
const interrupts = @import("interrupts.zig");
const console = @import("console.zig");
const shell_commands = @import("shell_commands.zig");
const raster = @import("raster.zig");

const max_memory_map_entries = 128;

const LimineMemmapResponse = extern struct {
    revision: u64,
    entry_count: u64,
    entries: [*]const *const memory_map.LimineMemmapEntry,
};

const LimineMemmapRequest = extern struct {
    id: [4]u64,
    revision: u64,
    response: ?*const LimineMemmapResponse,
};

export var memory_map_request: LimineMemmapRequest linksection(".limine_requests") = .{
    .id = .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x67cf3d9d378a806f, 0xe304acdfc50c3c62 },
    .revision = 0,
    .response = null,
};

var raw_regions: [max_memory_map_entries]memory_map.LimineMemmapEntry = undefined;
var validated_regions: [max_memory_map_entries]memory_map.Region = undefined;
var allocation_cursors: [max_memory_map_entries]u64 = undefined;
var frame_allocator: memory_map.FrameAllocator = undefined;
var shell_writer_context: u8 = 0;
var framebuffer_surface: ?raster.Surface = null;
var framebuffer_console: ?raster.Console = null;

const LimineFramebuffer = extern struct {
    address: [*]volatile u8,
    width: u64,
    height: u64,
    pitch: u64,
    bpp: u16,
    memory_model: u8,
    red_size: u8,
    red_shift: u8,
    green_size: u8,
    green_shift: u8,
    blue_size: u8,
    blue_shift: u8,
    unused: [7]u8,
    edid_size: u64,
    edid: ?*anyopaque,
};
const LimineFramebufferResponse = extern struct { revision: u64, framebuffer_count: u64, framebuffers: [*]const *const LimineFramebuffer };
const LimineFramebufferRequest = extern struct { id: [4]u64, revision: u64, response: ?*const LimineFramebufferResponse };
export var framebuffer_request: LimineFramebufferRequest linksection(".limine_requests") = .{
    .id = .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x9d5827dcd881dd75, 0xa3148604f6fab11b },
    .revision = 0,
    .response = null,
};

fn initializeFramebuffer() void {
    const response = framebuffer_request.response orelse {
        console.write("KratOS: framebuffer unavailable; serial console active\r\n");
        return;
    };
    if (response.framebuffer_count == 0) {
        console.write("KratOS: no framebuffer; serial console active\r\n");
        return;
    }
    const fb = response.framebuffers[0].*;
    if (fb.bpp != 32 or fb.memory_model != 1 or fb.width > 16384 or fb.height > 16384 or fb.pitch > std.math.maxInt(usize)) {
        console.write("KratOS: unsupported framebuffer; serial console active\r\n");
        return;
    }
    const size = std.math.mul(usize, @intCast(fb.pitch), @intCast(fb.height)) catch {
        console.write("KratOS: invalid framebuffer size; serial console active\r\n");
        return;
    };
    const surface = raster.Surface.init(fb.address[0..size], @intCast(fb.width), @intCast(fb.height), @intCast(fb.pitch), .{
        .red_size = fb.red_size,
        .red_shift = fb.red_shift,
        .green_size = fb.green_size,
        .green_shift = fb.green_shift,
        .blue_size = fb.blue_size,
        .blue_shift = fb.blue_shift,
    }) orelse {
        console.write("KratOS: malformed framebuffer; serial console active\r\n");
        return;
    };
    framebuffer_surface = surface;
    framebuffer_console = .{ .surface = &framebuffer_surface.? };
    framebuffer_console.?.clear();
    framebuffer_console.?.write("KratOS framebuffer ready\n");
}

fn writeShellOutput(_: *anyopaque, bytes: []const u8) void {
    console.write(bytes);
    if (framebuffer_console) |*display| display.write(bytes);
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %al, %dx"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn serialWriteHex(value: u64) void {
    const digits = "0123456789abcdef";
    var shift: u6 = 60;
    while (true) : (shift -= 4) {
        outb(0x3f8, digits[@as(usize, @truncate((value >> shift) & 0xf))]);
        if (shift == 0) break;
    }
}

fn fatalBoot(message: []const u8) noreturn {
    console.write("KratOS: boot error: ");
    console.write(message);
    console.write("\r\n");
    while (true) asm volatile ("cli; hlt");
}

fn initializeMemoryMap() shell_commands.MemorySummary {
    const response = memory_map_request.response orelse fatalBoot("missing Limine memory map");
    if (response.entry_count == 0 or response.entry_count > max_memory_map_entries) {
        fatalBoot("invalid Limine memory map entry count");
    }
    const count: usize = @intCast(response.entry_count);
    for (0..count) |index| {
        raw_regions[index] = response.entries[index].*;
    }
    const regions = memory_map.validate(raw_regions[0..count], validated_regions[0..count]) catch {
        fatalBoot("invalid Limine memory map");
    };
    frame_allocator = memory_map.FrameAllocator.init(regions, allocation_cursors[0..count]) catch {
        fatalBoot("cannot initialize physical frame allocator");
    };
    const first_frame = frame_allocator.allocate() orelse fatalBoot("no usable physical frames");
    var usable_bytes: u64 = 0;
    for (regions) |region| {
        if (region.kind == .usable) usable_bytes += region.length;
    }
    console.write("KratOS: memory map entries=");
    serialWriteHex(count);
    console.write(" first usable frame=0x");
    serialWriteHex(first_frame);
    console.write("\r\n");
    return .{
        .map_entries = count,
        .usable_bytes = usable_bytes,
        .first_usable_frame = first_frame,
    };
}

fn runShell(memory: shell_commands.MemorySummary) noreturn {
    var context = shell_commands.Context{
        .memory = memory,
        .writer_context = &shell_writer_context,
        .write = writeShellOutput,
    };
    var line: [console.line_capacity]u8 = undefined;
    while (true) {
        console.write("kratos> ");
        const input = console.readLine(&line) orelse continue;
        const action = shell_commands.execute(&context, input) catch {
            console.write("Command line too long\r\n");
            continue;
        };
        if (action == .halt) {
            console.write("KratOS halted\r\n");
            while (true) asm volatile ("cli; hlt");
        }
    }
}

export var request_start: [4]u64 linksection(".limine_requests_start") = .{
    0xf6b8f4b39de7d1ae, 0xfab91a6940fcb9cf,
    0x785c6ed015d3e316, 0x181e920a7852b9d9,
};
export var base_revision: [3]u64 linksection(".limine_requests") = .{
    0xf9562b2d5c95a6c8, 0x6a7b384944536bdc, 0,
};
export var request_end: [2]u64 linksection(".limine_requests_end") = .{
    0xadc0e0531bb10d03, 0x9572709f31764c62,
};

export fn kratos_kernel_main() noreturn {
    console.init();
    console.write("KratOS: Limine x86_64 kernel entered\r\n");
    interrupts.install();
    const memory = initializeMemoryMap();
    initializeFramebuffer();
    runShell(memory);
}
