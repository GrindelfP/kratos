//! Hardware-independent bounded screen movement and pseudo-random direction policy.
const std = @import("std");

/// 1.193182 MHz PIT base clock; channel 2 one-shot approximation of 20 ms.
pub const frame_period_ticks: u16 = 23864;

pub const Direction = enum { right, down, left, up };
pub const State = struct {
    x: usize,
    y: usize,
    direction: Direction = .right,
    random: u64,
    pub fn init(width: usize, height: usize, seed: u64) State {
        return .{ .x = (width -| 1) / 2, .y = (height -| 1) / 2, .random = if (seed == 0) 0x9e3779b97f4a7c15 else seed };
    }
    fn next(self: *State) u64 {
        self.random ^= self.random << 13;
        self.random ^= self.random >> 7;
        self.random ^= self.random << 17;
        return self.random;
    }
    pub fn advance(self: *State, width: usize, height: usize) void {
        if (width == 0 or height == 0) return;
        const dx: isize = switch (self.direction) { .right => 1, .left => -1, else => 0 };
        const dy: isize = switch (self.direction) { .down => 1, .up => -1, else => 0 };
        const nx = @as(isize, @intCast(self.x)) + dx;
        const ny = @as(isize, @intCast(self.y)) + dy;
        if (nx < 0 or ny < 0 or nx >= width or ny >= height) {
            self.direction = @enumFromInt(self.next() % 4);
        } else {
            self.x = @intCast(nx);
            self.y = @intCast(ny);
        }
    }
};

test "movement remains in bounds and collision changes direction deterministically" {
    var state = State.init(2, 2, 123);
    state.x = 1;
    state.y = 0;
    state.direction = .right;
    state.advance(2, 2);
    try std.testing.expect(state.x < 2 and state.y < 2);
    try std.testing.expect(state.direction != .right);
    var tiny = State.init(1, 1, 123);
    for (0..100) |_| { tiny.advance(1, 1); try std.testing.expectEqual(@as(usize, 0), tiny.x); try std.testing.expectEqual(@as(usize, 0), tiny.y); }
}

test "same seed yields same direction sequence and different seeds vary" {
    var a = State.init(20, 20, 12); var b = State.init(20, 20, 12); var c = State.init(20, 20, 91);
    for (0..100) |_| { a.advance(20, 20); b.advance(20, 20); c.advance(20, 20); try std.testing.expectEqual(a.direction, b.direction); }
    try std.testing.expect(a.random != c.random);
}

test "frame period is bounded and represents approximately twenty milliseconds" {
    try std.testing.expect(frame_period_ticks >= 23000 and frame_period_ticks <= 24000);
}
