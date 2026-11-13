//! x86-64 IDT setup and exception dispatch. User test faults may recover;
//! all kernel-origin faults and unsupported exceptions remain fatal.

const Gate = packed struct(u128) {
    offset_low: u16,
    selector: u16,
    ist: u8 = 0,
    attributes: u8 = 0x8e,
    offset_middle: u16,
    offset_high: u32,
    reserved: u32 = 0,
};

const Idtr = packed struct {
    limit: u16,
    base: u64,
};

extern const kratos_exception_stub_table: [32]usize;
extern fn kratos_syscall_entry() void;
const syscalls = @import("user_syscalls.zig");
const system_image = @import("system_image.zig");
const writable_volume = @import("writable_volume.zig");
const console = @import("console.zig");

var idt: [129]Gate = @splat(.{
    .offset_low = 0,
    .selector = 0,
    .offset_middle = 0,
    .offset_high = 0,
});

/// Most recent exception, including recovered user faults.
pub var last_exception_vector: u64 = 0;
pub var last_exception_error: u64 = 0;

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %al, %dx"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn serialWrite(text: []const u8) void {
    for (text) |byte| {
        while (true) {
            const ready = asm volatile ("inb %dx, %al"
                : [value] "={al}" (-> u8),
                : [port] "{dx}" (@as(u16, 0x3fd)),
            );
            if ((ready & 0x20) != 0) break;
        }
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

pub fn install() void {
    const code_selector = asm volatile ("mov %%cs, %[selector]"
        : [selector] "=r" (-> u16),
    );
    for (idt[0..32], 0..) |*gate, vector| {
        const address = kratos_exception_stub_table[vector];
        gate.selector = code_selector;
        gate.offset_low = @truncate(address);
        gate.offset_middle = @truncate(address >> 16);
        gate.offset_high = @truncate(address >> 32);
    }
    const syscall_address = @intFromPtr(&kratos_syscall_entry);
    idt[128] = .{ .selector = code_selector, .attributes = 0xee, .offset_low = @truncate(syscall_address), .offset_middle = @truncate(syscall_address >> 16), .offset_high = @truncate(syscall_address >> 32) };
    const idtr = Idtr{ .limit = @intCast(@sizeOf(@TypeOf(idt)) - 1), .base = @intFromPtr(&idt) };
    asm volatile ("lidt (%[descriptor])"
        :
        : [descriptor] "r" (&idtr),
        : .{ .memory = true });
}

/// Called by the assembly boundary with maskable interrupts disabled.
extern fn kratos_user_recover() noreturn;
pub var user_active = false;
pub var user_vector: u64 = 0;
pub var user_error: u64 = 0;
pub var user_exit: u64 = 0;
pub var user_exited = false;
var user_files: syscalls.Files = undefined;

pub fn setSystemVolume(volume: *const system_image.Volume) void {
    user_files = .{ .volume = volume };
}
pub fn setDataVolume(volume: ?*const writable_volume.Volume, principal: u64) void {
    user_files.data = volume;
    user_files.principal = principal;
}
pub fn resetUserFiles() void {
    user_files.reset();
}

export fn kratos_syscall_dispatch(number: u64, arg1: u64, arg2: u64, arg3: u64, cs: u64) u64 {
    if (!user_active or cs & 3 != 3) {
        serialWrite("KratOS: fatal invalid syscall origin\r\n");
        while (true) asm volatile ("cli; hlt");
    }
    switch (syscalls.dispatch(number, arg1, arg2, arg3)) {
        .result => |value| return value,
        .output => |output| {
            if (output.length != 0) {
                const bytes: [*]const u8 = @ptrFromInt(output.address);
                console.write(bytes[0..@intCast(output.length)]);
            }
            return output.length;
        },
        .open => |request| {
            const path: [*]const u8 = @ptrFromInt(request.address);
            return user_files.open(path[0..@intCast(request.length)]);
        },
        .read => |request| {
            if (request.length == 0) return 0;
            const bytes: [*]u8 = @ptrFromInt(request.address);
            return user_files.read(request.handle, bytes[0..@intCast(request.length)]);
        },
        .close => |handle| return user_files.close(handle),
        .exit => |status| {
            user_exit = status;
            user_exited = true;
            user_active = false;
            kratos_user_recover();
        },
    }
}

export fn kratos_exception_dispatch(vector: u64, error_code: u64, instruction_pointer: u64, cs: u64) noreturn {
    last_exception_vector = vector;
    last_exception_error = error_code;
    if (user_active and cs & 3 == 3 and (vector == 6 or vector == 14)) {
        user_active = false;
        user_vector = vector;
        user_error = error_code;
        serialWrite("KratOS: user fault vector=0x");
        serialWriteHex(vector);
        serialWrite(" error=0x");
        serialWriteHex(error_code);
        serialWrite("\r\n");
        kratos_user_recover();
    }
    serialWrite("KratOS: fatal x86 exception vector=0x");
    serialWriteHex(vector);
    serialWrite(" error=0x");
    serialWriteHex(error_code);
    serialWrite(" rip=0x");
    serialWriteHex(instruction_pointer);
    serialWrite("\r\n");
    while (true) asm volatile ("cli; hlt");
}
