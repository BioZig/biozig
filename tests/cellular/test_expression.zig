const std = @import("std");
const testing = std.testing;
const cellular = @import("cellular");
const expr = cellular.expression;

test "DenseMatrix - Memory boundaries" {
    const alloc = testing.allocator;
    var dense = try expr.DenseMatrix.init(alloc, 3, 3);
    defer dense.deinit();
    
    dense.set(1, 1, 5.0);
    try testing.expectEqual(@as(f64, 5.0), dense.get(1, 1));
}

test "DenseMatrix - Row slices" {
    const alloc = testing.allocator;
    var dense = try expr.DenseMatrix.init(alloc, 2, 4);
    defer dense.deinit();
    
    const slice = dense.rowSlice(1);
    try testing.expectEqual(@as(usize, 4), slice.len);
}

test "SparseMatrix - CSR Conversion" {
    const alloc = testing.allocator;
    var dense = try expr.DenseMatrix.init(alloc, 2, 2);
    defer dense.deinit();
    dense.set(0, 1, 42.0);
    
    var sparse = try expr.SparseMatrix.fromDense(alloc, dense, .csr);
    defer sparse.deinit();
    
    try testing.expectEqual(@as(f64, 42.0), sparse.get(0, 1));
}
