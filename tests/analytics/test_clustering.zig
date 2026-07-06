const std = @import("std");
const analytics = @import("analytics");

test "clustering kmeans edge cases" {
    const alloc = std.testing.allocator;
    var data = [_]f64{ 1.0, 1.0, 2.0, 2.0 };
    // Not enough data
    try std.testing.expectError(error.NotEnoughData, analytics.clustering.kmeans.kmeans(alloc, &data, 2, 3, 10, 1));
    // Invalid thread count
    try std.testing.expectError(error.InvalidThreadCount, analytics.clustering.kmeans.kmeans(alloc, &data, 2, 1, 10, 0));
    // Valid small
    const res = try analytics.clustering.kmeans.kmeans(alloc, &data, 2, 2, 10, 1);
    defer res.deinit(alloc);
    try std.testing.expectEqual(@as(usize, 2), res.centroids.len / 2);
}

test "clustering dbscan edge cases" {
    const alloc = std.testing.allocator;
    var data = [_]f64{ 1.0, 1.0, 2.0, 2.0 };
    // Invalid thread count
    try std.testing.expectError(error.InvalidThreadCount, analytics.clustering.dbscan.dbscan(alloc, &data, 2, 1.0, 2, 0));
    
    // NaN handling edge case (should not crash, might return all noise)
    var nan_data = [_]f64{ std.math.nan(f64), 1.0, 2.0, 2.0 };
    const res = try analytics.clustering.dbscan.dbscan(alloc, &nan_data, 2, 1.0, 2, 1);
    defer res.deinit(alloc);
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.clustering);
}
