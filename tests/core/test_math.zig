const std = @import("std");
const core = @import("core");

test "math boundary conditions" {
    const math = core.math.DeterministicMath;

    // test infinity and NaN handling
    const inf = std.math.inf(f64);
    const nan = std.math.nan(f64);

    // Strict Add
    try std.testing.expectEqual(math.strictAdd(inf, 1.0), inf);
    try std.testing.expect(std.math.isNan(math.strictAdd(inf, -inf)));
    try std.testing.expect(std.math.isNan(math.strictAdd(nan, 1.0)));

    // Strict Sub
    try std.testing.expectEqual(math.strictSub(inf, 1.0), inf);
    try std.testing.expect(std.math.isNan(math.strictSub(inf, inf)));

    // Strict Mul
    try std.testing.expectEqual(math.strictMul(inf, 2.0), inf);
    try std.testing.expectEqual(math.strictMul(inf, -2.0), -inf);
    try std.testing.expect(std.math.isNan(math.strictMul(inf, 0.0)));

    // Strict Div
    try std.testing.expectEqual(math.strictDiv(1.0, 0.0), inf);
    try std.testing.expectEqual(math.strictDiv(-1.0, 0.0), -inf);
    try std.testing.expect(std.math.isNan(math.strictDiv(0.0, 0.0)));
}
