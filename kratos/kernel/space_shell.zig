//! Bounded recovery-shell browsing for the read-only system space.
const std = @import("std");
const namespace = @import("namespace.zig");
const system_image = @import("system_image.zig");

pub const max_listed_entries = 16;
pub const max_file_preview = 96;

pub const Browser = struct {
    volume: *const system_image.Volume,
    cwd: [namespace.max_path]u8 = undefined,
    cwd_len: usize = 7,
    writer_context: *anyopaque,
    write: *const fn (*anyopaque, []const u8) void,

    pub fn init(volume: *const system_image.Volume, writer_context: *anyopaque, write: *const fn (*anyopaque, []const u8) void) Browser {
        var result = Browser{ .volume = volume, .writer_context = writer_context, .write = write };
        @memcpy(result.cwd[0..7], "system:");
        return result;
    }

    pub fn execute(self: *Browser, command: []const u8, args: []const u8) void {
        if (std.mem.eql(u8, command, "spaces")) {
            self.write(self.writer_context, "Accessible spaces: ");
            if (self.volume.mount == null) self.write(self.writer_context, "none (system unavailable)\r\n") else self.write(self.writer_context, "system (only mounted space; principal grants arrive with ticket 0029)\r\n");
        } else if (std.mem.eql(u8, command, "pwd")) {
            self.write(self.writer_context, self.cwd[0..self.cwd_len]);
            self.write(self.writer_context, "\r\n");
        } else if (std.mem.eql(u8, command, "ls")) {
            self.list(args);
        } else if (std.mem.eql(u8, command, "cd")) {
            self.changeDirectory(args);
        } else if (std.mem.eql(u8, command, "cat")) {
            self.preview(args);
        }
    }

    fn resolve(self: *Browser, path: []const u8, output: *[namespace.max_path]u8) ?[]const u8 {
        const candidate = if (path.len == 0) self.cwd[0..self.cwd_len] else path;
        const canonical = namespace.canonicalize(self.cwd[0..self.cwd_len], candidate, output) catch {
            self.write(self.writer_context, "Invalid path (names use lowercase letters only)\r\n");
            return null;
        };
        if (!std.mem.startsWith(u8, canonical, "system:")) {
            self.write(self.writer_context, "Unknown space; only system is available\r\n");
            return null;
        }
        return canonical;
    }

    fn list(self: *Browser, path: []const u8) void {
        var canonical_buffer: [namespace.max_path]u8 = undefined;
        const canonical = self.resolve(path, &canonical_buffer) orelse return;
        const handle = self.volume.lookup(canonical) catch |err| {
            self.report(err);
            return;
        };
        var entries: [max_listed_entries]system_image.Entry = undefined;
        const count = self.volume.enumerate(handle, &entries) catch |err| {
            if (err == error.OutputTooSmall) self.write(self.writer_context, "Directory exceeds the 16-entry listing limit\r\n") else self.report(err);
            return;
        };
        if (count == 0) {
            self.write(self.writer_context, "(empty)\r\n");
            return;
        }
        for (entries[0..count]) |entry| {
            self.write(self.writer_context, entry.name);
            if (entry.kind == .directory) self.write(self.writer_context, "/");
            self.write(self.writer_context, "\r\n");
        }
    }

    fn changeDirectory(self: *Browser, path: []const u8) void {
        if (path.len == 0) {
            self.write(self.writer_context, "Usage: cd <path>\r\n");
            return;
        }
        var canonical_buffer: [namespace.max_path]u8 = undefined;
        const canonical = self.resolve(path, &canonical_buffer) orelse return;
        const handle = self.volume.lookup(canonical) catch |err| {
            self.report(err);
            return;
        };
        const entry = self.volume.stat(handle) catch |err| {
            self.report(err);
            return;
        };
        if (entry.kind != .directory) {
            self.write(self.writer_context, "Not a directory\r\n");
            return;
        }
        @memcpy(self.cwd[0..canonical.len], canonical);
        self.cwd_len = canonical.len;
    }

    fn preview(self: *Browser, path: []const u8) void {
        if (path.len == 0) {
            self.write(self.writer_context, "Usage: cat <text-file>\r\n");
            return;
        }
        var canonical_buffer: [namespace.max_path]u8 = undefined;
        const canonical = self.resolve(path, &canonical_buffer) orelse return;
        const handle = self.volume.lookup(canonical) catch |err| {
            self.report(err);
            return;
        };
        const entry = self.volume.stat(handle) catch |err| {
            self.report(err);
            return;
        };
        if (entry.kind != .file) {
            self.write(self.writer_context, "Not a file\r\n");
            return;
        }
        if (entry.file_type != .text) {
            self.write(self.writer_context, "Not a text file\r\n");
            return;
        }
        var bytes: [max_file_preview]u8 = undefined;
        const count = self.volume.read(handle, 0, &bytes) catch |err| {
            self.report(err);
            return;
        };
        self.write(self.writer_context, bytes[0..count]);
        if (entry.size > count) self.write(self.writer_context, "\r\n[preview limited to 96 bytes]");
        self.write(self.writer_context, "\r\n");
    }

    fn report(self: *Browser, err: system_image.Error) void {
        self.write(self.writer_context, switch (err) {
            error.Unavailable => "system space unavailable\r\n",
            error.InvalidPath => "Invalid path\r\n",
            error.NotFound => "Path not found\r\n",
            error.WrongKind => "Path component is not a directory\r\n",
            error.MalformedImage => "Malformed system image\r\n",
            error.OutputTooSmall => "Directory listing exceeds limit\r\n",
        });
    }
};

test "browser starts at system root and reports unavailable mount safely" {
    const Output = struct {
        bytes: [256]u8 = undefined,
        len: usize = 0,
        fn write(raw: *anyopaque, bytes: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            @memcpy(self.bytes[self.len..][0..bytes.len], bytes);
            self.len += bytes.len;
        }
    };
    var volume: system_image.Volume = .{};
    var output: Output = .{};
    var browser = Browser.init(&volume, &output, Output.write);
    browser.execute("pwd", "");
    browser.execute("spaces", "");
    browser.execute("ls", "");
    browser.execute("cd", "unknown:/folder");
    browser.execute("cd", "system:/missing");
    try std.testing.expect(std.mem.indexOf(u8, output.bytes[0..output.len], "Accessible spaces: none (system unavailable)") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.bytes[0..output.len], "Unknown space; only system is available") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.bytes[0..output.len], "system space unavailable") != null);
    try std.testing.expectEqualStrings("system:", browser.cwd[0..browser.cwd_len]);
}
