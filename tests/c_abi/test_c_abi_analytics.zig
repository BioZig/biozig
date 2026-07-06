const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

pub const CBiozigDimRedResult = extern struct {
    data: [*c]const f64,
    rows: usize,
    cols: usize,
};

pub const CBiozigKMeansResult = extern struct {
    centroids: [*c]const f64,
    labels: [*c]const usize,
    k: usize,
    dim: usize,
    num_points: usize,
};

pub const CBiozigCorrelationResult = extern struct {
    coefficient: f64,
    p_value: f64,
};

extern fn biozig_analytics_pca(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    n_components: usize,
    threads: u16,
) callconv(.c) CBiozigDimRedResult;

extern fn biozig_analytics_tsne(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    threads: u16,
) callconv(.c) CBiozigDimRedResult;

extern fn biozig_analytics_kmeans(
    data: [*c]const f64,
    dim: usize,
    num_points: usize,
    k: usize,
    max_iter: usize,
    threads: u16,
) callconv(.c) CBiozigKMeansResult;

extern fn biozig_analytics_pearson(x: [*c]const f64, y: [*c]const f64, len: usize) callconv(.c) CBiozigCorrelationResult;

test "biozig_analytics_pca" {
    // We import c_api to ensure the module is compiled and symbols are exported
    _ = @import("c_api");

    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const data = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0 };

    const res = biozig_analytics_pca(@ptrCast(&data), 4, 3, 2, 1);
    try std.testing.expect(res.data != null);
    try std.testing.expectEqual(@as(usize, 4), res.rows);
    try std.testing.expectEqual(@as(usize, 2), res.cols);

    _ = biozig_context_destroy();
    const res_uninit = biozig_analytics_pca(@ptrCast(&data), 4, 3, 2, 1);
    try std.testing.expect(res_uninit.data == null);
    _ = biozig_context_create();
}

test "biozig_analytics_tsne" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const data = [_]f64{ 1.0, 2.0, 3.0, 4.0 };
    const res = biozig_analytics_tsne(@ptrCast(&data), 2, 2, 1);
    _ = res;
}

test "biozig_analytics_kmeans" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const data = [_]f64{ 1.0, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 7.0, 3.5, 5.0, 4.5, 5.0, 3.5, 4.5 };

    const res = biozig_analytics_kmeans(@ptrCast(&data), 2, 7, 2, 10, 1);
    try std.testing.expect(res.labels != null);
    try std.testing.expect(res.centroids != null);
    try std.testing.expectEqual(@as(usize, 2), res.k);
    try std.testing.expectEqual(@as(usize, 2), res.dim);
    try std.testing.expectEqual(@as(usize, 7), res.num_points);
}

test "biozig_analytics_pearson" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const x = [_]f64{ 1.0, 2.0, 3.0 };
    const y = [_]f64{ 2.0, 4.0, 6.0 };
    const res = biozig_analytics_pearson(@ptrCast(&x), @ptrCast(&y), 3);
    try std.testing.expect(res.coefficient > 0.99);
}
