const std = @import("std");
const core = @import("core");

test "simd edge cases" {
    // 0 length slice
    const float_empty: []f32 = &[_]f32{};
    try std.testing.expectEqual(core.simd.sumFloat(float_empty), 0.0);

    const int_empty: []u32 = &[_]u32{};
    try std.testing.expectEqual(core.simd.sumInt(int_empty), 0);

    // length not a multiple of vec_len (16)
    const float_odd = [_]f32{1.0, 2.0, 3.0};
    try std.testing.expectEqual(core.simd.sumFloat(&float_odd), 6.0);

    const text_empty: []const u8 = "";
    try std.testing.expectEqual(core.simd.countChar(text_empty, 'A'), 0);
    try std.testing.expectEqual(core.simd.countMismatches(text_empty, text_empty), 0);
}
