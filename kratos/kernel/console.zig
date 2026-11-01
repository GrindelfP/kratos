//! Polled COM1 console for the QEMU serial setup.
//! A line holds at most `line_capacity` bytes. Extra input is rejected and
//! rings the bell; backspace can make room again. No allocation is used.

const input = @import("input.zig");
const shell_edit = @import("shell_edit.zig");
const commands = @import("shell_commands.zig");
const std = @import("std");
var history = shell_edit.History{};
const com1: u16 = 0x3f8;
pub const line_capacity = 128;
var pending_lf_after_cr = false;
const receive_error_mask: u8 = 0x1e; // overrun, parity, framing, or break

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

/// Read one UART byte without waiting; animation loops use this to remain
/// interruptible while preserving the same COM1 receive-error checks.
pub fn tryReadByte() ?u8 {
    const status = inb(com1 + 5);
    if ((status & receive_error_mask) != 0) {
        _ = inb(com1);
        return null;
    }
    if ((status & 1) == 0) return null;
    return inb(com1);
}

const Edit = union(enum) { none, echo: u8, erase, full, done };

const LineEditor = struct {
    bytes: [line_capacity]u8 = undefined,
    len: usize = 0,
    previous_was_cr: bool = false,
    invalid: bool = false,

    fn markReceiveError(self: *LineEditor) bool {
        if (self.invalid) return false;
        self.invalid = true;
        return true;
    }

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
        if (self.invalid) return .none;
        if (byte == 8 or byte == 127) {
            if (self.len == 0) return .none;
            self.len -= 1;
            return .erase;
        }
        if (self.len == line_capacity) {
            self.invalid = true;
            return .full;
        }
        self.bytes[self.len] = byte;
        self.len += 1;
        return .{ .echo = byte };
    }
};

/// Read one line, polling COM1. Returned bytes exclude the line terminator;
/// CRLF is treated as one terminator. A UART receive error or capacity overflow
/// discards the whole line through its terminator and returns null.
pub fn pollSerial(_: *anyopaque) ?input.Event {
    const status = inb(com1 + 5);
    if ((status & receive_error_mask) != 0) {
        if ((status & 1) != 0) _ = inb(com1);
        return .receive_error;
    }
    if ((status & 1) == 0) return null;
    return .{ .byte = inb(com1) };
}

pub fn readLine(buffer: []u8, inputs: *input.Inputs, echo_context: *anyopaque, echo: *const fn (*anyopaque, []const u8) void) ?[]u8 {
    var editor = LineEditor{ .previous_was_cr = pending_lf_after_cr };
    pending_lf_after_cr = false;
    while (true) {
        const event = inputs.poll() orelse continue;
        if (event == .up or event == .down) {
            if (editor.invalid) continue;
            const replacement = if (event == .up) history.up(editor.bytes[0..editor.len]) else history.down();
            if (replacement) |line| {
                for (0..editor.len) |_| echo(echo_context, "\x08 \x08");
                @memcpy(editor.bytes[0..line.len], line);
                editor.len = line.len;
                echo(echo_context, editor.bytes[0..editor.len]);
            }
            continue;
        }
        if (event == .tab) {
            if (editor.invalid) continue;
            switch (shell_edit.complete(editor.bytes[0..editor.len])) {
                .none => {},
                .unique => |name| {
                    var start: usize = 0;
                    while (start < editor.len and editor.bytes[start] == ' ') : (start += 1) {}
                    const suffix = name[editor.len - start..];
                    if (editor.len + suffix.len <= line_capacity) {
                        @memcpy(editor.bytes[editor.len..][0..suffix.len], suffix);
                        editor.len += suffix.len;
                        echo(echo_context, suffix);
                    }
                },
                .ambiguous => |prefix| {
                    echo(echo_context, "\r\n");
                    for (commands.names) |name| if (std.mem.startsWith(u8, name, prefix)) {
                        echo(echo_context, name);
                        echo(echo_context, " ");
                    };
                    echo(echo_context, "\r\nkratos> ");
                    echo(echo_context, editor.bytes[0..editor.len]);
                },
            }
            continue;
        }
        const byte = switch (event) {
            .receive_error => { if (editor.markReceiveError()) write("\x07"); continue; },
            .byte => |value| value,
            else => unreachable,
        };
        switch (editor.input(byte)) {
            .none => {},
            .echo => |value| echo(echo_context, &.{value}),
            .erase => echo(echo_context, "\x08 \x08"),
            .full => write("\x07"),
            .done => {
                pending_lf_after_cr = editor.previous_was_cr;
                echo(echo_context, "\r\n");
                if (editor.invalid) {
                    echo(echo_context, "Input error: line discarded\r\n");
                    return null;
                }
                history.submit(editor.bytes[0..editor.len]);
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

test "editor erases within bounds and invalidates an over-capacity line" {
    var editor = LineEditor{};
    for (0..line_capacity - 1) |_| try @import("std").testing.expect(editor.input('x') == .echo);
    try @import("std").testing.expect(editor.input(8) == .erase);
    try @import("std").testing.expect(editor.input('z') == .echo);
    try @import("std").testing.expectEqual(@as(usize, line_capacity - 1), editor.len);
    try @import("std").testing.expect(editor.input('x') == .echo);
    try @import("std").testing.expect(editor.input('y') == .full);
    try @import("std").testing.expect(editor.invalid);
    try @import("std").testing.expect(editor.input(8) == .none);
    try @import("std").testing.expectEqual(@as(usize, line_capacity), editor.len);
}

test "editor rejects the entire over-capacity line through its terminator" {
    var editor = LineEditor{};
    for (0..line_capacity) |_| _ = editor.input('x');
    try @import("std").testing.expect(editor.input('y') == .full);
    try @import("std").testing.expect(editor.invalid);
    try @import("std").testing.expect(editor.input('z') == .none);
    try @import("std").testing.expect(editor.input('\r') == .done);
    try @import("std").testing.expect(editor.invalid);
}

test "editor discards a partially received line after a UART error" {
    var editor = LineEditor{};
    try @import("std").testing.expect(editor.input('e') == .echo);
    try @import("std").testing.expect(editor.input('c') == .echo);
    try @import("std").testing.expect(editor.markReceiveError());
    try @import("std").testing.expect(!editor.markReceiveError());
    try @import("std").testing.expect(editor.input('h') == .none);
    try @import("std").testing.expect(editor.input('\n') == .done);
    try @import("std").testing.expect(editor.invalid);
}
