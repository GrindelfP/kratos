// KratOS minimal freestanding x86-64 kernel entry.

const memory_map = @import("memory_map.zig");
const interrupts = @import("interrupts.zig");

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

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %al, %dx"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %dx, %al"
        : [value] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

fn serialInit() void {
    outb(0x3f9, 0x00);
    outb(0x3fb, 0x80);
    outb(0x3f8, 0x03);
    outb(0x3f9, 0x00);
    outb(0x3fb, 0x03);
    outb(0x3fa, 0xc7);
    outb(0x3fc, 0x0b);
}

fn serialWrite(text: []const u8) void {
    for (text) |byte| {
        while ((inb(0x3fd) & 0x20) == 0) {}
        outb(0x3f8, byte);
    }
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
    serialWrite("KratOS: boot error: ");
    serialWrite(message);
    serialWrite("\r\n");
    while (true) asm volatile ("cli; hlt");
}

fn initializeMemoryMap() void {
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
    serialWrite("KratOS: memory map entries=");
    serialWriteHex(count);
    serialWrite(" first usable frame=0x");
    serialWriteHex(first_frame);
    serialWrite("\r\n");
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
    serialInit();
    serialWrite("KratOS: Limine x86_64 kernel entered\r\n");
    interrupts.install();
    initializeMemoryMap();
    while (true) {
        asm volatile ("hlt");
    }
}
