//! Lexical namespace parsing; this does not perform lookup or authorization.
const std = @import("std");

pub const max_name = 32;
pub const max_path = 255;
pub const max_components = 128;
pub const Error = error{Invalid};

pub fn validName(name: []const u8) bool {
    if (name.len == 0 or name.len > max_name) return false;
    for (name) |c| if (c < 'a' or c > 'z') {
        return false;
    };
    return true;
}

/// base must be a canonical absolute path. Output is written into caller storage.
pub fn canonicalize(base: []const u8, path: []const u8, out: *[max_path]u8) Error![]const u8 {
    if (path.len == 0 or path.len > max_path) return error.Invalid;
    var components: [max_components][]const u8 = undefined;
    var count: usize = 0;
    var selector: []const u8 = undefined;
    var rest: []const u8 = undefined;
    if (std.mem.indexOfScalar(u8, path, ':')) |colon| {
        selector = path[0..colon];
        if (!validName(selector)) return error.Invalid;
        rest = path[colon + 1 ..];
        if (rest.len != 0) {
            if (rest[0] != '/' or rest.len == 1) return error.Invalid;
            rest = rest[1..];
        }
    } else {
        if (base.len == 0 or base.len > max_path) return error.Invalid;
        const colon = std.mem.indexOfScalar(u8, base, ':') orelse return error.Invalid;
        selector = base[0..colon];
        if (!validName(selector)) return error.Invalid;
        const base_rest = base[colon + 1 ..];
        if (base_rest.len != 0) {
            if (base_rest[0] != '/' or base_rest.len == 1) return error.Invalid;
            var it = std.mem.splitScalar(u8, base_rest[1..], '/');
            while (it.next()) |part| {
                if (!validName(part) or count == max_components) return error.Invalid;
                components[count] = part;
                count += 1;
            }
        }
        rest = path;
    }
    var seen: usize = 0;
    if (rest.len != 0) {
        var it = std.mem.splitScalar(u8, rest, '/');
        while (it.next()) |part| {
            seen += 1;
            if (seen > max_components or part.len == 0) return error.Invalid;
            if (std.mem.eql(u8, part, ".")) continue;
            if (std.mem.eql(u8, part, "..")) {
                if (count == 0) return error.Invalid;
                count -= 1;
            } else {
                if (!validName(part) or count == max_components) return error.Invalid;
                components[count] = part;
                count += 1;
            }
        }
    }
    var len = selector.len + 1;
    for (components[0..count]) |part| len += 1 + part.len;
    if (len > max_path) return error.Invalid;
    @memcpy(out[0..selector.len], selector);
    out[selector.len] = ':';
    var pos = selector.len + 1;
    for (components[0..count]) |part| {
        out[pos] = '/';
        pos += 1;
        @memcpy(out[pos..][0..part.len], part);
        pos += part.len;
    }
    return out[0..pos];
}

test "names and canonical paths" {
    var out: [max_path]u8 = undefined;
    try std.testing.expect(validName("archive"));
    for ([_][]const u8{ "", "A", "a1", "a.b", "a:b", "a/b", "é", "abcdefghijklmnopqrstuvwxyzabcdefg" }) |name| try std.testing.expect(!validName(name));
    try std.testing.expectEqualStrings("mine:", try canonicalize("", "mine:", &out));
    try std.testing.expectEqualStrings("team:/work/file", try canonicalize("team:/work/draft", "../file", &out));
    try std.testing.expectEqualStrings("system:/packages/hello", try canonicalize("", "system:/packages/./hello", &out));
    for ([_][]const u8{ "", "/a", "a/", "a//b", "mine:/", "mine://a", "mine:a", "mine:/a:b", "../..", "A", "a1", "é" }) |path| try std.testing.expectError(error.Invalid, canonicalize("mine:", path, &out));
    try std.testing.expectError(error.Invalid, canonicalize("mine:/bad//base", "a", &out));
    try std.testing.expectError(error.Invalid, canonicalize("mine:", &(@as([256]u8, @splat('a'))), &out));
    try std.testing.expectError(error.Invalid, canonicalize("mine:/abcdefghijklmnopqrstuvwxyzabcdef", "abcdefghijklmnopqrstuvwxyzabcdef/abcdefghijklmnopqrstuvwxyzabcdef/abcdefghijklmnopqrstuvwxyzabcdef/abcdefghijklmnopqrstuvwxyzabcdef/abcdefghijklmnopqrstuvwxyzabcdef/abcdefghijklmnopqrstuvwxyzabcdef/abcdefghijklmnopqrstuvwxyzabcdef", &out));
}
