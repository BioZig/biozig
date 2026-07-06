const std = @import("std");
const analytics = @import("analytics");

test "matrix sparse edge cases" {
    const alloc = std.testing.allocator;
    const values = [_]f64{};
    const col_indices = [_]usize{};
    const row_ptr = [_]usize{0};
    
    const mat = analytics.matrix.sparse.CsrMatrix{
        .values = &values,
        .col_indices = &col_indices,
        .row_ptr = &row_ptr,
        .rows = 0,
        .cols = 0,
    };
    
    var vec = [_]f64{};
    const res = try analytics.matrix.sparse.multiplyCsrVector(alloc, mat, &vec, 1);
    defer alloc.free(res);
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.matrix);
}
