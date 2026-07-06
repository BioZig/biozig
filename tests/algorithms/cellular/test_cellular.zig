const std = @import("std");
const cellular = @import("algorithms_cellular");

test "Cellular - Basic Stats" {
    const expr = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const mean = cellular.meanExpression(&expr);
    try std.testing.expectEqual(@as(f64, 3.0), mean);

    const variance = cellular.varianceExpression(&expr);
    try std.testing.expectEqual(@as(f64, 2.5), variance);

    try std.testing.expectEqual(@as(f64, 0.0), cellular.meanExpression(&[_]f64{}));
    try std.testing.expectEqual(@as(f64, 0.0), cellular.varianceExpression(&[_]f64{}));
    try std.testing.expectEqual(@as(f64, 0.0), cellular.varianceExpression(&[_]f64{1.0}));
}

test "Cellular - Spatial Distances and KdTree" {
    const alloc = std.testing.allocator;
    const px = [_]f64{ 0.0, 1.0, 0.0, 10.0 };
    const py = [_]f64{ 0.0, 0.0, 2.0, 10.0 };
    const points = cellular.CoordinateSet2D{ .x = &px, .y = &py };

    const neighbors = try cellular.spatialNeighborhood(alloc, 0.0, 0.0, points, 1.5);
    defer alloc.free(neighbors);

    // should find (1.0, 0.0), but not (0.0, 0.0) itself because distance > 0 is checked
    try std.testing.expectEqual(@as(usize, 1), neighbors.len);
    try std.testing.expectEqual(@as(usize, 1), neighbors[0].index);

    const stats = cellular.neighborhoodExpressionStats(neighbors, &[_]f64{ 10, 20, 30, 40 });
    try std.testing.expectEqual(@as(f64, 20.0), stats);

    try std.testing.expectEqual(@as(f64, 0.0), cellular.neighborhoodExpressionStats(&[_]cellular.SpatialNeighbor{}, &[_]f64{}));
}

test "Cellular - Empty KdTree" {
    const alloc = std.testing.allocator;
    const points = cellular.CoordinateSet2D{ .x = &[_]f64{}, .y = &[_]f64{} };
    const neighbors = try cellular.spatialNeighborhood(alloc, 0.0, 0.0, points, 1.5);
    defer alloc.free(neighbors);
    try std.testing.expectEqual(@as(usize, 0), neighbors.len);
}

test "Cellular - Cell Cycle" {
    const expr = [_]f64{ 1.0, 5.0, 0.5, 8.0 };
    const g1_s = [_]bool{ true, true, false, false };
    const g2_m = [_]bool{ false, false, true, true };

    const score = try cellular.scoreCellCycle(&expr, &g1_s, &g2_m);
    try std.testing.expectEqual(@as(f64, 3.0), score.g1_s);
    try std.testing.expectEqual(@as(f64, 4.25), score.g2_m);
    try std.testing.expectEqual(.G2M, score.phase);

    const bad_expr = [_]f64{ 1.0, 5.0, 0.5 };
    try std.testing.expectError(error.DimensionMismatch, cellular.scoreCellCycle(&bad_expr, &g1_s, &g2_m));
}
