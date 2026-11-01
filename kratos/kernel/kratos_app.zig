//! Foreground kernel application orchestration; hardware adapters are callbacks.
const animation = @import("animation.zig");

pub const Frame = struct { x: usize, y: usize };
pub const Policy = struct {
    state: animation.State,
    pub fn init(width: usize, height: usize, seed: u64) Policy {
        return .{ .state = animation.State.init(width, height, seed) };
    }
    pub fn frame(self: *Policy, width: usize, height: usize) Frame {
        self.state.advance(width, height);
        return .{ .x = self.state.x, .y = self.state.y };
    }
};

test "frame policy delegates bounded motion without hardware dependencies" {
    var policy = Policy.init(4, 5, 77);
    for (0..100) |_| { const frame = policy.frame(4, 5); try @import("std").testing.expect(frame.x < 4 and frame.y < 5); }
}
