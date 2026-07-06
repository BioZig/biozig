const std = @import("std");
const analytics = @import("analytics");

test "statistics descriptive edge cases" {
    const alloc = std.testing.allocator;
    const empty = [_]f64{};

    try std.testing.expectEqual(@as(f64, 0.0), analytics.statistics.descriptive.weightedMean(&empty, &empty));

    const mode_res = try analytics.statistics.descriptive.mode(&empty, alloc);
    try std.testing.expect(mode_res == null);
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.statistics);
}
