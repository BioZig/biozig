const std = @import("std");
const analytics = @import("analytics");

test "sequence metrics edge cases" {
    // Length mismatch
    try std.testing.expectError(error.SequenceLengthMismatch, analytics.sequence.metrics.calculateTiTvRatio("A", "AT"));

    // Zero window size
    try std.testing.expectError(error.InvalidWindowParameters, analytics.sequence.metrics.slidingWindowMetrics(std.testing.allocator, "A", 0, 1));
    // Zero step size
    try std.testing.expectError(error.InvalidWindowParameters, analytics.sequence.metrics.slidingWindowMetrics(std.testing.allocator, "A", 1, 0));
    // Empty seq
    const empty_res = try analytics.sequence.metrics.slidingWindowMetrics(std.testing.allocator, "", 1, 1);
    try std.testing.expectEqual(@as(usize, 0), empty_res.len);
    std.testing.allocator.free(empty_res);
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.sequence);
}
