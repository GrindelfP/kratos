//! Polled COM1 console for the QEMU serial setup.
//! A line holds at most `line_capacity` bytes. Extra input is rejected and
//! rings the bell; backspace can make room again. No allocation is used.

const com1: u16 = 0x3f8;
pub const line_capacity = 128;
var pending_lf_after_cr = false;

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

pub fn init() void {
    outb(com1 + 1, 0x00);
    outb(com1 + 3, 0x80);
    outb(com1, 0x03);
    outb(com1 + 1, 0x00);
    outb(com1 + 3, 0x03);
    outb(com1 + 2, 0xc7);
    outb(com1 + 4, 0x0b);
}

pub fn write(bytes: []const u8) void {
    for (bytes) |byte| {
        while ((inb(com1 + 5) & 0x20) == 0) {}
        outb(com1, byte);
    }
}

const Edit = union(enum) { none, echo: u8, erase, full, done };

const LineEditor = struct {
    bytes: [line_capacity]u8 = undefined,
    len: usize = 0,
    previous_was_cr: bool = false,

    fn input(self: *LineEditor, byte: u8) Edit {
        if (byte == '\n' and self.previous_was_cr) {
            self.previous_was_cr = false;
            return .none;
        }
        self.previous_was_cr = false;
        if (byte == '\r' or byte == '\n') {
            self.previous_was_cr = byte == '\r';
            return .done;
        }
        if (byte == 8 or byte == 127) {
            if (self.len == 0) return .none;
            self.len -= 1;
            return .erase;
        }
        if (self.len == line_capacity) return .full;
        self.bytes[self.len] = byte;
        self.len += 1;
        return .{ .echo = byte };
    }
};

/// Read one line, polling COM1. Returned bytes exclude the line terminator;
/// CRLF is treated as one terminator. When full, new characters are rejected
/// (BEL is echoed) until backspace removes a stored character.
pub fn readLine(buffer: []u8) []u8 {
    var editor = LineEditor{ .previous_was_cr = pending_lf_after_cr };
    pending_lf_after_cr = false;
    while (true) {
        while ((inb(com1 + 5) & 1) == 0) {}
        const action = editor.input(inb(com1));
        switch (action) {
            .none => {},
            .echo => |byte| write(&.{byte}),
            .erase => write("\x08 \x08"),
            .full => write("\x07"),
            .done => {
                pending_lf_after_cr = editor.previous_was_cr;
                write("\r\n");
                const count = @min(editor.len, buffer.len);
                @memcpy(buffer[0..count], editor.bytes[0..count]);
                return buffer[0..count];
            },
        }
    }
}

test "editor handles empty input and CRLF as one line" {
    var editor = LineEditor{};
    try @import("std").testing.expect(editor.input('\r') == .done);
    try @import("std").testing.expect(editor.input('\n') == .none);
    try @import("std").testing.expect(editor.len == 0);
}

test "editor carry state consumes LF after a completed CR line" {
    var first = LineEditor{};
    try @import("std").testing.expect(first.input('\r') == .done);
    var next = LineEditor{ .previous_was_cr = first.previous_was_cr };
    try @import("std").testing.expect(next.input('\n') == .none);
    try @import("std").testing.expectEqual(@as(usize, 0), next.len);
}

test "editor erases, bounds, and resumes after backspace" {
    var editor = LineEditor{};
    for (0..line_capacity) |_| try @import("std").testing.expect(editor.input('x') == .echo);
    try @import("std").testing.expect(editor.input('y') == .full);
    try @import("std").testing.expect(editor.input(8) == .erase);
    try @import("std").testing.expect(editor.input('z') == .echo);
    try @import("std").testing.expectEqual(@as(usize, line_capacity), editor.len);
}
