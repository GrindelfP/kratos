//! Bounded built-in shell command dispatcher. No I/O or allocation is performed
//! here; callers supply the writer and a compact snapshot of boot memory data.

pub const max_line_length = 128;

pub const Action = enum { continue_shell, halt, kratos, shutdown };

pub const MemorySummary = struct {
    map_entries: usize = 0,
    usable_bytes: u64 = 0,
    first_usable_frame: ?u64 = null,
};

pub const Context = struct {
    memory: MemorySummary = .{},
    writer_context: *anyopaque,
    write: *const fn (*anyopaque, []const u8) void,
    clear: *const fn (*anyopaque) void,
};

pub const Error = error{LineTooLong};

pub fn execute(context: *Context, line: []const u8) Error!Action {
    if (line.len > max_line_length) return error.LineTooLong;
    const input = trim(line);
    if (input.len == 0) return .continue_shell;

    const split = indexWhitespace(input);
    const command = input[0..split];
    const args = if (split < input.len) trim(input[split..]) else "";
    if (eql(command, "help")) {
        context.write(context.writer_context, "help about echo mem clear kratos halt shutdown\r\n");
    } else if (eql(command, "about")) {
        context.write(context.writer_context, "KratOS: a small hobby operating system\r\n");
    } else if (eql(command, "echo")) {
        var decoded: [max_line_length]u8 = undefined;
        const text = decodeEcho(args, &decoded) catch {
            context.write(context.writer_context, "echo: unmatched quote\r\n");
            return .continue_shell;
        };
        context.write(context.writer_context, text);
        context.write(context.writer_context, "\r\n");
    } else if (eql(command, "mem")) {
        context.write(context.writer_context, "Memory map entries: ");
        writeDecimal(context, context.memory.map_entries);
        context.write(context.writer_context, ", usable bytes: ");
        writeDecimal(context, context.memory.usable_bytes);
        context.write(context.writer_context, ", first usable frame: ");
        if (context.memory.first_usable_frame) |frame| {
            context.write(context.writer_context, "0x");
            writeHex(context, frame);
        } else {
            context.write(context.writer_context, "none");
        }
        context.write(context.writer_context, "\r\n");
    } else if (eql(command, "clear")) {
        context.clear(context.writer_context);
    } else if (eql(command, "kratos")) {
        return .kratos;
    } else if (eql(command, "halt")) {
        return .halt;
    } else if (eql(command, "shutdown")) {
        return .shutdown;
    } else {
        context.write(context.writer_context, "Unknown command: ");
        context.write(context.writer_context, command);
        context.write(context.writer_context, "\r\n");
    }
    return .continue_shell;
}

/// Removes matching single/double quote delimiters while retaining all other
/// bytes (including spaces). Backslash escaping is intentionally unsupported.
fn decodeEcho(args: []const u8, output: *[max_line_length]u8) error{UnmatchedQuote}![]const u8 {
    var len: usize = 0;
    var quote: ?u8 = null;
    for (args) |byte| {
        if (quote) |delimiter| {
            if (byte == delimiter) {
                quote = null;
            } else {
                output[len] = byte;
                len += 1;
            }
        } else if (byte == '\'' or byte == '"') {
            quote = byte;
        } else {
            output[len] = byte;
            len += 1;
        }
    }
    if (quote != null) return error.UnmatchedQuote;
    return output[0..len];
}

fn trim(text: []const u8) []const u8 {
    var first: usize = 0;
    var last = text.len;
    while (first < last and whitespace(text[first])) : (first += 1) {}
    while (last > first and whitespace(text[last - 1])) : (last -= 1) {}
    return text[first..last];
}

fn indexWhitespace(text: []const u8) usize {
    for (text, 0..) |byte, i| if (whitespace(byte)) return i;
    return text.len;
}

fn whitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n';
}

fn eql(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| if (a != b) return false;
    return true;
}

fn writeDecimal(context: *Context, value: u64) void {
    var digits: [20]u8 = undefined;
    var n = value;
    var index = digits.len;
    while (true) {
        index -= 1;
        digits[index] = @intCast(n % 10 + '0');
        n /= 10;
        if (n == 0) break;
    }
    context.write(context.writer_context, digits[index..]);
}

fn writeHex(context: *Context, value: u64) void {
    const digits = "0123456789abcdef";
    var output: [16]u8 = undefined;
    var shift: u6 = 60;
    for (&output) |*byte| {
        byte.* = digits[@as(usize, @truncate((value >> shift) & 0xf))];
        if (shift != 0) shift -= 4;
    }
    context.write(context.writer_context, &output);
}

const std = @import("std");

const TestOutput = struct {
    bytes: [512]u8 = undefined,
    len: usize = 0,
    fn write(raw: *anyopaque, text: []const u8) void {
        const self: *TestOutput = @ptrCast(@alignCast(raw));
        @memcpy(self.bytes[self.len..][0..text.len], text);
        self.len += text.len;
    }
    fn contents(self: *const TestOutput) []const u8 {
        return self.bytes[0..self.len];
    }
    fn clear(raw: *anyopaque) void {
        TestOutput.write(raw, "[screen cleared]\r\n");
    }
};

test "empty and whitespace input are no-ops; command arguments are preserved" {
    var output: TestOutput = .{};
    var context = Context{ .writer_context = &output, .write = TestOutput.write, .clear = TestOutput.clear };
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, " \t\r\n"));
    try std.testing.expectEqual(@as(usize, 0), output.len);
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "  echo   hello world  "));
    try std.testing.expectEqualStrings("hello world\r\n", output.contents());
}

test "known commands, unknown command, halt, and shutdown actions" {
    var output: TestOutput = .{};
    var context = Context{ .writer_context = &output, .write = TestOutput.write, .clear = TestOutput.clear };
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "help"));
    try std.testing.expectEqual(Action.kratos, try execute(&context, "kratos"));
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "about"));
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "clear"));
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "nonesuch arg"));
    try std.testing.expectEqual(Action.halt, try execute(&context, "halt"));
    try std.testing.expectEqual(Action.shutdown, try execute(&context, "shutdown"));
    try std.testing.expect(std.mem.indexOf(u8, output.contents(), "Unknown command: nonesuch") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.contents(), "\x1b") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.contents(), "[screen cleared]") != null);
}

test "mem uses supplied snapshot and formats values" {
    var output: TestOutput = .{};
    var context = Context{ .writer_context = &output, .write = TestOutput.write, .clear = TestOutput.clear, .memory = .{ .map_entries = 3, .usable_bytes = 4096, .first_usable_frame = 0x1234 } };
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "mem"));
    try std.testing.expect(std.mem.indexOf(u8, output.contents(), "entries: 3, usable bytes: 4096, first usable frame: 0x0000000000001234") != null);
}

test "rejects overlong lines before dispatch" {
    var output: TestOutput = .{};
    var context = Context{ .writer_context = &output, .write = TestOutput.write, .clear = TestOutput.clear };
    const line: [max_line_length + 1]u8 = @splat('x');
    try std.testing.expectError(error.LineTooLong, execute(&context, &line));
    try std.testing.expectEqual(@as(usize, 0), output.len);
}

test "echo removes matching quote delimiters and preserves argument bytes" {
    var output: TestOutput = .{};
    var context = Context{ .writer_context = &output, .write = TestOutput.write, .clear = TestOutput.clear };
    const cases = [_][2][]const u8{
        .{ "echo hello world", "hello world\r\n" },
        .{ "echo 'hello world'", "hello world\r\n" },
        .{ "echo \"hello world\"", "hello world\r\n" },
        .{ "echo ''", "\r\n" },
        .{ "echo \"a\"'b'", "ab\r\n" },
    };
    for (cases) |case| {
        output.len = 0;
        try std.testing.expectEqual(Action.continue_shell, try execute(&context, case[0]));
        try std.testing.expectEqualStrings(case[1], output.contents());
    }
}

test "echo rejects unmatched quotes without emitting partial output" {
    var output: TestOutput = .{};
    var context = Context{ .writer_context = &output, .write = TestOutput.write, .clear = TestOutput.clear };
    try std.testing.expectEqual(Action.continue_shell, try execute(&context, "echo 'unfinished"));
    try std.testing.expectEqualStrings("echo: unmatched quote\r\n", output.contents());
}
