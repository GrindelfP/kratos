//! Validated flat KRU1 image: magic, little-endian payload length and entry offset.
const std = @import("std");
pub const page_size = 4096;
pub const Image = struct { payload: []const u8, entry: usize };
pub fn validate(bytes: []const u8) error{InvalidImage}!Image {
    if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "KRU1")) return error.InvalidImage;
    const length = std.mem.readInt(u32, bytes[4..8], .little);
    const entry = std.mem.readInt(u32, bytes[8..12], .little);
    if (length == 0 or length > page_size or bytes.len - 12 != length or entry >= length) return error.InvalidImage;
    return .{ .payload = bytes[12..], .entry = entry };
}
pub fn load(bytes: []const u8, destination: *[page_size]u8) error{InvalidImage}!usize {
    const image = try validate(bytes);
    @memset(destination, 0);
    @memcpy(destination[0..image.payload.len], image.payload);
    return image.entry;
}
test "validate and load bounded images without modifying destination on error" {
    var page: [page_size]u8 = @splat(0xaa);
    try std.testing.expectError(error.InvalidImage, load("", &page));
    try std.testing.expectEqual(@as(u8, 0xaa), page[0]);
    try std.testing.expectError(error.InvalidImage, validate("BAD!\x01\x00\x00\x00\x00\x00\x00\x00X"));
    try std.testing.expectError(error.InvalidImage, validate("KRU1\x00\x00\x00\x00\x00\x00\x00\x00"));
    try std.testing.expectError(error.InvalidImage, validate("KRU1\x01\x10\x00\x00\x00\x00\x00\x00X"));
    try std.testing.expectError(error.InvalidImage, validate("KRU1\x02\x00\x00\x00\x00\x00\x00\x00X"));
    try std.testing.expectError(error.InvalidImage, validate("KRU1\x01\x00\x00\x00\x00\x00\x00\x00XY"));
    try std.testing.expectError(error.InvalidImage, validate("KRU1\x01\x00\x00\x00\x01\x00\x00\x00X"));
    try std.testing.expectEqual(@as(usize, 0), try load("KRU1\x01\x00\x00\x00\x00\x00\x00\x00X", &page));
    try std.testing.expectEqual(@as(u8, 'X'), page[0]);
    try std.testing.expectEqual(@as(u8, 0), page[1]);
    var maximum: [12 + page_size]u8 = @splat(0x90);
    @memcpy(maximum[0..12], "KRU1\x00\x10\x00\x00\xff\x0f\x00\x00");
    try std.testing.expectEqual(@as(usize, page_size - 1), try load(&maximum, &page));
    try std.testing.expectEqual(@as(u8, 0x90), page[page_size - 1]);
}
