// KratOS minimal freestanding x86-64 kernel entry.

const memory_map = @import("memory_map.zig");
const interrupts = @import("interrupts.zig");
const console = @import("console.zig");
const shell_commands = @import("shell_commands.zig");

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

fn writeShellOutput(_: *anyopaque, bytes: []const u8) void {
    console.write(bytes);
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
    runShell(memory);
}
