const std = @import("std");
const testing = std.testing;

const evolutionary = @import("evolutionary");

test "upgma - empty matrix" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var dist_matrix = [_][]const f64{};
    var labels = [_][]const u8{};
    
    const result = evolutionary.upgma(allocator, &dist_matrix, &labels);
    try testing.expectError(error.EmptyMatrix, result);
}

test "upgma - single element" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var d0 = [_]f64{0.0};
    var dist_matrix = [_][]const f64{&d0};
    var labels = [_][]const u8{"A"};
    
    const tree = try evolutionary.upgma(allocator, &dist_matrix, &labels);
    try testing.expectEqual(@as(usize, 1), tree.nodes.len);
    try testing.expectEqual(@as(usize, 0), tree.root);
    try testing.expect(tree.is_rooted);
}

test "upgma - normal matrix" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var dist_matrix = try allocator.alloc([]const f64, 3);
    var d0 = [_]f64{0.0, 0.2, 0.3};
    var d1 = [_]f64{0.2, 0.0, 0.4};
    var d2 = [_]f64{0.3, 0.4, 0.0};
    
    dist_matrix[0] = &d0;
    dist_matrix[1] = &d1;
    dist_matrix[2] = &d2;

    var labels = try allocator.alloc([]const u8, 3);
    labels[0] = "A";
    labels[1] = "B";
    labels[2] = "C";

    const tree = try evolutionary.upgma(allocator, dist_matrix, labels);
    try testing.expectEqual(@as(usize, 5), tree.nodes.len);
}

test "neighborJoining - normal matrix" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var dist_matrix = try allocator.alloc([]const f64, 3);
    var d0 = [_]f64{0.0, 0.2, 0.3};
    var d1 = [_]f64{0.2, 0.0, 0.4};
    var d2 = [_]f64{0.3, 0.4, 0.0};
    
    dist_matrix[0] = &d0;
    dist_matrix[1] = &d1;
    dist_matrix[2] = &d2;

    var labels = try allocator.alloc([]const u8, 3);
    labels[0] = "A";
    labels[1] = "B";
    labels[2] = "C";

    const tree = try evolutionary.neighborJoining(allocator, dist_matrix, labels);
    try testing.expectEqual(@as(usize, 4), tree.nodes.len);
}
