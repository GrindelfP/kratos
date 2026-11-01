//! Bounded, hardware-independent set-1 keyboard decoding and input arbitration.
const std = @import("std");

pub const Event = union(enum) { byte: u8, tab, up, down, receive_error };
pub const Source = struct {
    context: *anyopaque,
    poll: *const fn (*anyopaque) ?Event,
};
pub const Inputs = struct {
    serial: Source,
    keyboard: Source,
    keyboard_first: bool = false,
    pub fn poll(self: *Inputs) ?Event {
        const first = if (self.keyboard_first) self.keyboard else self.serial;
        const second = if (self.keyboard_first) self.serial else self.keyboard;
        self.keyboard_first = !self.keyboard_first;
        return first.poll(first.context) orelse second.poll(second.context);
    }
};

pub const Decoder = struct {
    left_shift: bool = false,
    right_shift: bool = false,
    extended: bool = false,
    pause_bytes: u3 = 0,
    pub fn feed(self: *Decoder, scan: u8) ?Event {
        if (self.pause_bytes != 0) { self.pause_bytes -= 1; return null; }
        if (scan == 0xe1) { self.pause_bytes = 5; self.extended = false; return null; }
        if (scan == 0xe0) { self.extended = true; return null; }
        if (self.extended) {
            self.extended = false;
            return switch (scan) { 0x48 => .up, 0x50 => .down, else => null };
        }
        const released = scan & 0x80 != 0;
        const code = scan & 0x7f;
        if (code == 0x2a) { self.left_shift = !released; return null; }
        if (code == 0x36) { self.right_shift = !released; return null; }
        if (released) return null;
        const plain = "\x00\x001234567890-=\x08\tqwertyuiop[]\n\x00asdfghjkl;'`\x00\\zxcvbnm,./\x00*\x00 ";
        const shifted = "\x00\x00!@#$%^&*()_+\x08\tQWERTYUIOP{}\n\x00ASDFGHJKL:\"~\x00|ZXCVBNM<>?\x00*\x00 ";
        if (code >= plain.len) return null;
        const byte = if (self.left_shift or self.right_shift) shifted[code] else plain[code];
        if (byte == 0) return null;
        if (byte == '\t') return .tab;
        return .{ .byte = byte };
    }
};

test "set 1 decoding includes tab and extended arrows, not releases or unrelated keys" {
    var d = Decoder{};
    try std.testing.expectEqual(@as(u8, 'a'), d.feed(0x1e).?.byte);
    try std.testing.expect(d.feed(0x9e) == null);
    _ = d.feed(0x2a); _ = d.feed(0x36); _ = d.feed(0xaa);
    try std.testing.expectEqual(@as(u8, 'A'), d.feed(0x1e).?.byte);
    try std.testing.expectEqual(@as(u8, '"'), d.feed(0x28).?.byte);
    _ = d.feed(0xb6);
    try std.testing.expectEqual(@as(u8, 8), d.feed(0x0e).?.byte);
    try std.testing.expect(d.feed(0x0f).? == .tab);
    _ = d.feed(0xe0); try std.testing.expect(d.feed(0x48).? == .up);
    _ = d.feed(0xe0); try std.testing.expect(d.feed(0x50).? == .down);
    _ = d.feed(0xe0); try std.testing.expect(d.feed(0xc8) == null);
    _ = d.feed(0xe0); try std.testing.expect(d.feed(0x4b) == null);
    _ = d.feed(0xe1); for (0..5) |_| try std.testing.expect(d.feed(0x1e) == null);
}

test "arbitration polls both sources and alternates priority" {
    const Mock = struct {
        byte: ?u8,
        calls: usize = 0,
        fn poll(ctx: *anyopaque) ?Event {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.calls += 1;
            const b = self.byte orelse return null;
            self.byte = null;
            return .{ .byte = b };
        }
    };
    var a = Mock{ .byte = 's' }; var b = Mock{ .byte = 'k' };
    var inputs = Inputs{ .serial = .{ .context = &a, .poll = Mock.poll }, .keyboard = .{ .context = &b, .poll = Mock.poll } };
    try std.testing.expectEqual(@as(u8, 's'), inputs.poll().?.byte);
    try std.testing.expectEqual(@as(u8, 'k'), inputs.poll().?.byte);
    try std.testing.expect(inputs.poll() == null);
    try std.testing.expect(a.calls >= 2 and b.calls >= 2);
}
