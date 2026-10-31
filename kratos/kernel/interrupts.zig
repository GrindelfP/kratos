//! Isolated x86-64 IDT setup and exception dispatch state.
//! The entry stubs are in interrupts.S; wire `install()` into kernel startup
//! only after the active linker/build integration is confirmed.

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

var idt: [32]Gate = @splat(.{
    .offset_low = 0,
    .selector = 0,
    .offset_middle = 0,
    .offset_high = 0,
});

/// Last fatal exception recorded. This is an inspection seam for a later
/// serial/debug reporter; it is not itself a user-visible diagnostic.
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
    for (&idt, 0..) |*gate, vector| {
        const address = kratos_exception_stub_table[vector];
        gate.selector = code_selector;
        gate.offset_low = @truncate(address);
        gate.offset_middle = @truncate(address >> 16);
        gate.offset_high = @truncate(address >> 32);
    }
    const idtr = Idtr{ .limit = @intCast(@sizeOf(@TypeOf(idt)) - 1), .base = @intFromPtr(&idt) };
    asm volatile ("lidt (%[descriptor])"
        :
        : [descriptor] "r" (&idtr),
        : .{ .memory = true });
}

/// Called by the assembly boundary. Fatal exceptions are intentionally
/// non-returning; the caller must keep maskable interrupts disabled for now.
export fn kratos_exception_dispatch(vector: u64, error_code: u64, instruction_pointer: u64) noreturn {
    last_exception_vector = vector;
    last_exception_error = error_code;
    serialWrite("KratOS: fatal x86 exception vector=0x");
    serialWriteHex(vector);
    serialWrite(" error=0x");
    serialWriteHex(error_code);
    serialWrite(" rip=0x");
    serialWriteHex(instruction_pointer);
    serialWrite("\r\n");
    while (true) asm volatile ("cli; hlt");
}
