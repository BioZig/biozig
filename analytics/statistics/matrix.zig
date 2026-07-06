const std = @import("std");
const core = @import("core");
const numerics = core.numerics;
const descriptive = @import("descriptive.zig");
const correlation = @import("correlation.zig");

/// Computes the covariance matrix for a set of variables.
/// Variables are rows, observations are columns.
pub fn covarianceMatrix(data: [][]const f64, allocator: std.mem.Allocator) ![][]f64 {
    const k = data.len; // number of variables
    var matrix = try allocator.alloc([]f64, k);
    for (0..k) |i| {
        matrix[i] = try allocator.alloc(f64, k);
        for (0..i + 1) |j| {
            const cov = numerics.covariance(data[i], data[j]);
            matrix[i][j] = cov;
            matrix[j][i] = cov;
        }
    }
    return matrix;
}

/// Computes the correlation matrix for a set of variables.
pub fn correlationMatrix(data: [][]const f64, allocator: std.mem.Allocator) ![][]f64 {
    const k = data.len;
    var matrix = try allocator.alloc([]f64, k);
    for (0..k) |i| {
        matrix[i] = try allocator.alloc(f64, k);
        matrix[i][i] = 1.0;
        for (0..i) |j| {
            const res = try correlation.pearson(null, data[i], data[j]);
            const r = res.coefficient;
            matrix[i][j] = r;
            matrix[j][i] = r;
        }
    }
    return matrix;
}

/// Normalizes a dataset by centering and scaling (Z-score).
pub fn normalizeZScore(data: [][]f64) void {
    for (data) |row| {
        const m = numerics.mean(row);
        const s = descriptive.stdDev(row);
        if (s == 0.0) {
            for (row) |*x| x.* = 0.0;
        } else {
            for (row) |*x| x.* = (x.* - m) / s;
        }
    }
}

/// Scales data to a range [0, 1].
pub fn scaleMinMax(data: [][]f64) void {
    for (data) |row| {
        var min_val = std.math.inf(f64);
        var max_val = -std.math.inf(f64);
        for (row) |x| {
            min_val = @min(min_val, x);
            max_val = @max(max_val, x);
        }
        const range = max_val - min_val;
        if (range == 0.0) {
            for (row) |*x| x.* = 0.0;
        } else {
            for (row) |*x| x.* = (x.* - min_val) / range;
        }
    }
}
