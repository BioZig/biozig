const std = @import("std");
const core = @import("core");

test "bitpacking odd widths" {
    var buffer: [10]u8 = undefined;
    const array3 = core.bitpacking.PackedIntArray(3).init(&buffer, 20);
    array3.set(0, 7);
    array3.set(19, 5);
    try std.testing.expectEqual(array3.get(0), 7);
    try std.testing.expectEqual(array3.get(19), 5);

    const array7 = core.bitpacking.PackedIntArray(7).init(&buffer, 10);
    array7.set(0, 127);
    array7.set(9, 63);
    try std.testing.expectEqual(array7.get(0), 127);
    try std.testing.expectEqual(array7.get(9), 63);
    
    // bit reader boundary
    var reader = core.bitpacking.BitReader.init(&buffer);
    try std.testing.expectError(error.EndOfStream, reader.readBits(u32, 100));
}
