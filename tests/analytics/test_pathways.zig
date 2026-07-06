const std = @import("std");
const analytics = @import("analytics");

test "pathways enrichment edge cases" {
    const p_val = analytics.pathways.enrichment.hypergeometricPValue(100, 10, 10, 100);
    try std.testing.expectEqual(@as(f64, 0.0), p_val);
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.pathways);
}
