const std = @import("std");
const hungarian = @import("ATLAZ").hungarian;

test "Hungarian: 3x3 known optimal assignment" {
    const allocator = std.testing.allocator;
    
    var cost_matrix = try allocator.alloc([]f64, 3);
    defer allocator.free(cost_matrix);
    
    // Cost matrix:
    // 2.0  3.0  3.0
    // 3.0  2.0  3.0
    // 3.0  3.0  2.0
    // Optimal matching should be the diagonal (2.0 + 2.0 + 2.0 = 6.0)
    for (0..3) |i| {
        cost_matrix[i] = try allocator.alloc(f64, 3);
        for (0..3) |j| {
            cost_matrix[i][j] = if (i == j) 2.0 else 3.0;
        }
    }
    defer {
        for (cost_matrix) |row| allocator.free(row);
    }
    
    const matches = try hungarian.hungarian(allocator, cost_matrix);
    defer allocator.free(matches);
    
    try std.testing.expectEqual(@as(usize, 3), matches.len);
    
    var total_cost: f64 = 0.0;
    for (matches) |m| {
        try std.testing.expectEqual(m.row, m.col);
        total_cost += cost_matrix[m.row][m.col];
    }
    
    try std.testing.expect(@abs(total_cost - 6.0) < 0.0001);
}

test "Hungarian: 10x10 Random Matrix Stress Test" {
    const allocator = std.testing.allocator;
    const n: usize = 10;
    
    var cost_matrix = try allocator.alloc([]f64, n);
    defer allocator.free(cost_matrix);
    
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    for (0..n) |i| {
        cost_matrix[i] = try allocator.alloc(f64, n);
        for (0..n) |j| {
            cost_matrix[i][j] = random.float(f64) * 100.0;
        }
    }
    defer {
        for (cost_matrix) |row| allocator.free(row);
    }
    
    const matches = try hungarian.hungarian(allocator, cost_matrix);
    defer allocator.free(matches);
    
    try std.testing.expectEqual(n, matches.len);
    
    var row_seen = try allocator.alloc(bool, n);
    defer allocator.free(row_seen);
    @memset(row_seen, false);
    
    var col_seen = try allocator.alloc(bool, n);
    defer allocator.free(col_seen);
    @memset(col_seen, false);
    
    var total_cost: f64 = 0.0;
    for (matches) |m| {
        try std.testing.expect(!row_seen[m.row]);
        try std.testing.expect(!col_seen[m.col]);
        row_seen[m.row] = true;
        col_seen[m.col] = true;
        total_cost += cost_matrix[m.row][m.col];
    }
    
    // Verify all rows and columns are matched exactly once
    for (0..n) |i| {
        try std.testing.expect(row_seen[i]);
        try std.testing.expect(col_seen[i]);
    }
}
