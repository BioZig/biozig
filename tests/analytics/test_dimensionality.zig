const std = @import("std");
const analytics = @import("analytics");

test "dimensionality pca edge cases" {
    const alloc = std.testing.allocator;
    var data = [_]f64{ 1.0, 2.0, 3.0, 4.0 };

    // Invalid thread count
    try std.testing.expectError(error.InvalidThreadCount, analytics.dimensionality.pca.pca(alloc, &data, 2, 2, 1, 0));
    // Invalid data size
    try std.testing.expectError(error.InvalidDataSize, analytics.dimensionality.pca.pca(alloc, &data, 3, 2, 1, 1));
    // Invalid component count
    try std.testing.expectError(error.InvalidComponentCount, analytics.dimensionality.pca.pca(alloc, &data, 2, 2, 0, 1));
    try std.testing.expectError(error.InvalidComponentCount, analytics.dimensionality.pca.pca(alloc, &data, 2, 2, 3, 1));

    // Normal test
    const res = try analytics.dimensionality.pca.pca(alloc, &data, 2, 2, 1, 1);
    defer alloc.free(res);
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.dimensionality);
}
