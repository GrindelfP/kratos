//! Allocation-free shell history and command-name completion policy.
const std = @import("std");
const commands = @import("shell_commands.zig");
pub const capacity = commands.max_line_length;
pub const depth = 16;
const Line = struct {
    bytes: [capacity]u8 = undefined,
    len: usize = 0,
    fn set(self: *Line, value: []const u8) void {
        self.len = @min(value.len, capacity);
        @memcpy(self.bytes[0..self.len], value[0..self.len]);
    }
    fn text(self: *const Line) []const u8 { return self.bytes[0..self.len]; }
};
pub const History = struct {
    entries: [depth]Line = @splat(.{}),
    next: usize = 0,
    count: usize = 0,
    selected: usize = 0,
    draft: Line = .{},
    // Every non-blank submission is retained, including consecutive duplicates.
    pub fn submit(self: *History, text: []const u8) void {
        self.selected = 0;
        if (std.mem.trim(u8, text, " \t\r\n").len == 0) return;
        self.entries[self.next].set(text);
        self.next = (self.next + 1) % depth;
        self.count = @min(self.count + 1, depth);
    }
    pub fn up(self: *History, current: []const u8) ?[]const u8 {
        if (self.selected == self.count) return null;
        if (self.selected == 0) self.draft.set(current);
        self.selected += 1;
        return self.entries[(self.next + depth - self.selected) % depth].text();
    }
    pub fn down(self: *History) ?[]const u8 {
        if (self.selected == 0) return null;
        self.selected -= 1;
        if (self.selected == 0) return self.draft.text();
        return self.entries[(self.next + depth - self.selected) % depth].text();
    }
};
pub const Completion = union(enum) { none, unique: []const u8, ambiguous: []const u8 };
pub fn complete(line: []const u8) Completion {
    var start: usize = 0;
    while (start < line.len and line[start] == ' ') : (start += 1) {}
    const prefix = line[start..];
    for (prefix) |c| if (c == ' ' or c == '\t') { return .none; };
    var found: ?[]const u8 = null;
    for (commands.names) |name| {
        if (!std.mem.startsWith(u8, name, prefix)) continue;
        if (found != null) return .{ .ambiguous = prefix };
        found = name;
    }
    return if (found) |name| .{ .unique = name } else .none;
}

test "completion only matches first token" {
    try std.testing.expect(complete("  hel") == .ambiguous);
    try std.testing.expectEqualStrings("help", complete("  help").unique);
    try std.testing.expect(complete("h") == .ambiguous);
    try std.testing.expect(complete("") == .ambiguous);
    try std.testing.expect(complete("zzz") == .none);
    try std.testing.expect(complete("echo h") == .none);
}
test "history wraps, retains duplicates, restores draft and does not mutate entries" {
    var h = History{};
    h.submit("old");
    for (0..depth) |_| h.submit("same");
    h.submit(" ");
    try std.testing.expectEqualStrings("same", h.up("draft").?);
    try std.testing.expectEqualStrings("same", h.up("edited").?);
    for (2..depth) |_| _ = h.up("");
    try std.testing.expect(h.up("") == null);
    for (1..depth) |_| _ = h.down();
    try std.testing.expectEqualStrings("draft", h.down().?);
    try std.testing.expect(h.down() == null);
    try std.testing.expectEqualStrings("same", h.up("new").?);
}

test "history orders distinct entries and keeps browsing edits separate" {
    var h = History{};
    h.submit("first"); h.submit("second"); h.submit("third");
    try std.testing.expectEqualStrings("third", h.up("unfinished").?);
    try std.testing.expectEqualStrings("second", h.up("modified third").?);
    try std.testing.expectEqualStrings("first", h.up("modified second").?);
    try std.testing.expectEqualStrings("second", h.down().?);
    try std.testing.expectEqualStrings("third", h.down().?);
    try std.testing.expectEqualStrings("unfinished", h.down().?);
}
