const std = @import("std");
const cellular = @import("cellular");
const expression = cellular.expression;
const mtx = @import("mtx.zig");
const matrix = @import("matrix.zig");

test "matrix.zig parseSparseMmap O(NNZ) memory usage" {
    const testing = std.testing;
    const csv_content =
        \\SampleID,Gene1,Gene2,Gene3
        \\Cell1,0.0,1.5,0.0
        \\Cell2,2.0,0.0,3.0
    ;

    // We should be able to call matrix.parseSparseMmap
    var sparse = try matrix.parseSparseMmap(testing.allocator, csv_content, ',');
    defer sparse.deinit();

    try testing.expectEqual(@as(usize, 2), sparse.rows);
    try testing.expectEqual(@as(usize, 3), sparse.cols);
    try testing.expectEqual(@as(usize, 3), sparse.data.len);
    try testing.expectEqual(@as(f64, 1.5), sparse.data[0]);
    try testing.expectEqual(@as(f64, 2.0), sparse.data[1]);
    try testing.expectEqual(@as(f64, 3.0), sparse.data[2]);
}
