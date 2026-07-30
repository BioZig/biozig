const std = @import("std");
const sparse = @import("analytics").matrix.sparse;
const hungarian = @import("hungarian.zig");


fn getBirth(p: sparse.PersistencePair) f64 { return p.birth_val; }
fn getDeath(p: sparse.PersistencePair) f64 { return p.death_val; }

pub fn buildCostMatrix(
    allocator: std.mem.Allocator,
    a: []const sparse.PersistencePair,
    b: []const sparse.PersistencePair,
) ![][]f64 {
    const n = a.len;
    const m = b.len;
    const k = n + m + 1;

    var cost_matrix = try allocator.alloc([]f64, k);
    errdefer {
        for (cost_matrix) |row| allocator.free(row);
        allocator.free(cost_matrix);
    }

    for (0..k) |i| {
        cost_matrix[i] = try allocator.alloc(f64, k);
        @memset(cost_matrix[i], std.math.inf(f64));
    }

    for (0..n) |i| {
        for (0..m) |j| {
            const dx = getBirth(a[i]) - getBirth(b[j]);
            const dy = getDeath(a[i]) - getDeath(b[j]);
            cost_matrix[i][j] = @sqrt(dx * dx + dy * dy);
        }
    }

    for (0..n) |i| {
        const dist = @abs(getDeath(a[i]) - getBirth(a[i])) / 2.0;
        for (m..k) |j| {
            if (j == m + i) {
                cost_matrix[i][j] = dist;
            }
        }
    }

    for (0..m) |j| {
        const dist = @abs(getDeath(b[j]) - getBirth(b[j])) / 2.0;
        for (n..k) |i| {
            if (i == n + j) {
                cost_matrix[i][j] = dist;
            }
        }
    }

    for (n..k) |i| {
        for (m..k) |j| {
            cost_matrix[i][j] = 0.0;
        }
    }

    return cost_matrix;
}

pub fn wassersteinDistance(
    allocator: std.mem.Allocator,
    a: []const sparse.PersistencePair,
    b: []const sparse.PersistencePair,
) !f64 {
    if (a.len == 0 and b.len == 0) return 0.0;
    
    var a_sorted = try allocator.alloc(f64, a.len);
    defer allocator.free(a_sorted);
    for (a, 0..) |p, i| a_sorted[i] = @abs(getDeath(p) - getBirth(p));
    
    var b_sorted = try allocator.alloc(f64, b.len);
    defer allocator.free(b_sorted);
    for (b, 0..) |p, i| b_sorted[i] = @abs(getDeath(p) - getBirth(p));
    
    std.mem.sort(f64, a_sorted, {}, std.sort.desc(f64));
    std.mem.sort(f64, b_sorted, {}, std.sort.desc(f64));
    
    var total_cost: f64 = 0;
    const min_len = @min(a_sorted.len, b_sorted.len);
    
    for (0..min_len) |i| {
        total_cost += @abs(a_sorted[i] - b_sorted[i]);
    }
    
    for (min_len..a_sorted.len) |i| {
        total_cost += a_sorted[i] / 2.0;
    }
    for (min_len..b_sorted.len) |i| {
        total_cost += b_sorted[i] / 2.0;
    }
    
    return total_cost;
}

pub fn wassersteinDistanceExact(
    allocator: std.mem.Allocator,
    a: []const sparse.PersistencePair,
    b: []const sparse.PersistencePair,
) !f64 {
    if (a.len == 0 and b.len == 0) return 0.0;
    
    if (a.len == 0) {
        var sum: f64 = 0;
        for (b) |pb| sum += @abs(getDeath(pb) - getBirth(pb)) / 2.0;
        return sum;
    }
    
    if (b.len == 0) {
        var sum: f64 = 0;
        for (a) |pa| sum += @abs(getDeath(pa) - getBirth(pa)) / 2.0;
        return sum;
    }

    const cost_matrix = try buildCostMatrix(allocator, a, b);
    defer {
        for (cost_matrix) |row| allocator.free(row);
        allocator.free(cost_matrix);
    }

    const matches = try hungarian.hungarian(allocator, cost_matrix);
    defer allocator.free(matches);

    var total_cost: f64 = 0;
    for (matches) |m| {
        const cost = cost_matrix[m.row][m.col];
        if (cost != std.math.inf(f64)) {
            total_cost += cost;
        }
    }

    return total_cost;
}
