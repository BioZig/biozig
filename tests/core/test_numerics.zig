const std = @import("std");
const core = @import("core");

test "numerics nan/inf edge cases" {
    const empty: []f64 = &[_]f64{};
    try std.testing.expectEqual(core.numerics.kahanSum(empty), 0.0);
    try std.testing.expectEqual(core.numerics.mean(empty), 0.0);
    try std.testing.expectEqual(core.numerics.variance(empty), 0.0);
    try std.testing.expectEqual(core.numerics.covariance(empty, empty), 0.0);

    const single = [_]f64{42.0};
    try std.testing.expectEqual(core.numerics.variance(&single), 0.0);
    try std.testing.expectEqual(core.numerics.covariance(&single, &single), 0.0);

    const q = try core.numerics.quantile(&single, 0.5, std.testing.allocator);
    try std.testing.expectEqual(q, 42.0);

    // Inf values
    const inf_arr = [_]f64{ std.math.inf(f64), std.math.inf(f64) };
    try std.testing.expect(std.math.isNan(core.numerics.kahanSum(&inf_arr)));
}
