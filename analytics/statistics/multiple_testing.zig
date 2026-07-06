const std = @import("std");

/// Bonferroni correction.
pub fn bonferroni(p_values: []f64, allocator: std.mem.Allocator) ![]f64 {
    const n = @as(f64, @floatFromInt(p_values.len));
    var adjusted = try allocator.alloc(f64, p_values.len);
    for (0..p_values.len) |i| {
        adjusted[i] = @min(1.0, p_values[i] * n);
    }
    return adjusted;
}

/// Holm-Bonferroni correction.
pub fn holm(p_values: []const f64, allocator: std.mem.Allocator) ![]f64 {
    const n = p_values.len;
    if (n == 0) return try allocator.alloc(f64, 0);

    const PVal = struct {
        p: f64,
        orig_idx: usize,
    };
    var pvals = try allocator.alloc(PVal, n);
    defer allocator.free(pvals);
    for (0..n) |i| pvals[i] = .{ .p = p_values[i], .orig_idx = i };

    std.sort.block(PVal, pvals, {}, struct {
        fn lessThan(_: void, a: PVal, b: PVal) bool {
            return a.p < b.p;
        }
    }.lessThan);

    var adjusted = try allocator.alloc(f64, n);
    var prev_adj: f64 = 0.0;
    for (0..n) |i| {
        const i_f = @as(f64, @floatFromInt(i));
        const n_f = @as(f64, @floatFromInt(n));
        const adj = @min(1.0, @max(prev_adj, pvals[i].p * (n_f - i_f)));
        adjusted[pvals[i].orig_idx] = adj;
        prev_adj = adj;
    }
    return adjusted;
}

/// Benjamini-Hochberg FDR correction.
pub fn benjaminiHochberg(p_values: []const f64, allocator: std.mem.Allocator) ![]f64 {
    const n = p_values.len;
    if (n == 0) return try allocator.alloc(f64, 0);

    const PVal = struct {
        p: f64,
        orig_idx: usize,
    };
    var pvals = try allocator.alloc(PVal, n);
    defer allocator.free(pvals);
    for (0..n) |i| pvals[i] = .{ .p = p_values[i], .orig_idx = i };

    std.sort.block(PVal, pvals, {}, struct {
        fn lessThan(_: void, a: PVal, b: PVal) bool {
            return a.p < b.p;
        }
    }.lessThan);

    var adjusted = try allocator.alloc(f64, n);
    var min_adj: f64 = 1.0;
    var i: usize = n;
    while (i > 0) {
        i -= 1;
        const i_f = @as(f64, @floatFromInt(i + 1));
        const n_f = @as(f64, @floatFromInt(n));
        const adj = @min(min_adj, pvals[i].p * n_f / i_f);
        adjusted[pvals[i].orig_idx] = adj;
        min_adj = adj;
    }
    return adjusted;
}

test "multiple testing corrections" {
    const pvals = [_]f64{ 0.01, 0.04, 0.05, 0.1 };
    const alloc = std.testing.allocator;

    const b = try bonferroni(@constCast(&pvals), alloc);
    defer alloc.free(b);
    try std.testing.expectApproxEqAbs(@as(f64, 0.04), b[0], 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.20), b[2], 1e-10);

    const bh = try benjaminiHochberg(&pvals, alloc);
    defer alloc.free(bh);
    // n=4
    // 0.01 * 4/1 = 0.04
    // 0.04 * 4/2 = 0.08
    // 0.05 * 4/3 = 0.0666...
    // 0.1 * 4/4 = 0.1
    // BH: sorted pvals: 0.01, 0.04, 0.05, 0.1
    // adj(4) = 0.1
    // adj(3) = min(0.1, 0.05*4/3) = 0.0666...
    // adj(2) = min(0.0666..., 0.04*4/2) = 0.0666...
    // adj(1) = min(0.0666..., 0.01*4/1) = 0.04
    try std.testing.expectApproxEqAbs(@as(f64, 0.04), bh[0], 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0666666666666), bh[2], 1e-10);
}
