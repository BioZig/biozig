const std = @import("std");
const core = @import("core");
const numerics = core.numerics;
const descriptive = @import("descriptive.zig");

pub const LinearRegressionResult = struct {
    slope: f64,
    intercept: f64,
    r_squared: f64,
    adjusted_r_squared: f64,
    residuals: []f64,
};

/// Computes simple linear regression: y = slope * x + intercept.
pub fn simpleLinearRegression(x: []const f64, y: []const f64, allocator: std.mem.Allocator) !LinearRegressionResult {
    std.debug.assert(x.len == y.len);
    const n = @as(f64, @floatFromInt(x.len));
    if (n < 2) return error.InsufficientData;

    const mx = numerics.mean(x);
    const my = numerics.mean(y);
    const cov = numerics.covariance(x, y);
    const var_x = numerics.variance(x);

    const slope = cov / var_x;
    const intercept = my - slope * mx;

    var residuals = try allocator.alloc(f64, x.len);
    var ss_res: f64 = 0.0;
    var ss_tot: f64 = 0.0;

    for (0..x.len) |i| {
        const pred = slope * x[i] + intercept;
        residuals[i] = y[i] - pred;
        ss_res += residuals[i] * residuals[i];
        ss_tot += (y[i] - my) * (y[i] - my);
    }

    const r_squared = 1.0 - (ss_res / ss_tot);
    // Adjusted R2 = 1 - [(1-R2)*(n-1) / (n-k-1)] where k=1 for simple LR
    const adjusted_r_squared = 1.0 - ((1.0 - r_squared) * (n - 1.0) / (n - 2.0));

    return .{
        .slope = slope,
        .intercept = intercept,
        .r_squared = r_squared,
        .adjusted_r_squared = adjusted_r_squared,
        .residuals = residuals,
    };
}

/// Computes Multiple Linear Regression: Y = X * Beta.
/// Uses normal equations: Beta = (X'X)^-1 X'Y.
/// Note: This is a basic implementation for small-to-medium datasets.
pub fn multipleLinearRegression(
    X: [][]const f64, // Matrix of predictors (n x k)
    Y: []const f64, // Vector of responses (n)
    allocator: std.mem.Allocator,
) !struct { coefficients: []f64, r_squared: f64, adjusted_r_squared: f64 } {
    const n = Y.len;
    const k = X.len; // number of features
    if (n <= k + 1) return error.InsufficientData;

    // Implementation of MLR using matrix operations.
    // I'll need a way to invert X'X.
    // Since I don't have a full matrix library in core yet,
    // I'll implement a small Gauss-Jordan elimination for now.

    // Create augmented matrix [X'X | X'Y]
    // X'X is k+1 x k+1 (including intercept)
    const m = k + 1;
    var augmented = try allocator.alloc([]f64, m);
    defer {
        for (augmented) |row| allocator.free(row);
        allocator.free(augmented);
    }
    for (0..m) |i| {
        augmented[i] = try allocator.alloc(f64, m + 1);
        @memset(augmented[i], 0.0);
    }

    // Fill X'X and X'Y
    for (0..m) |i| {
        for (0..m) |j| {
            var sum: f64 = 0.0;
            for (0..n) |idx| {
                const xi = if (i == 0) 1.0 else X[i - 1][idx];
                const xj = if (j == 0) 1.0 else X[j - 1][idx];
                sum += xi * xj;
            }
            augmented[i][j] = sum;
        }
        var sum_y: f64 = 0.0;
        for (0..n) |idx| {
            const xi = if (i == 0) 1.0 else X[i - 1][idx];
            sum_y += xi * Y[idx];
        }
        augmented[i][m] = sum_y;
    }

    // Gauss-Jordan elimination
    for (0..m) |i| {
        // Pivot
        var pivot_row = i;
        while (pivot_row < m and @abs(augmented[pivot_row][i]) < 1e-12) : (pivot_row += 1) {}
        if (pivot_row == m) return error.SingularMatrix;

        const tmp = augmented[i];
        augmented[i] = augmented[pivot_row];
        augmented[pivot_row] = tmp;

        const factor = augmented[i][i];
        for (i..m + 1) |j| augmented[i][j] /= factor;

        for (0..m) |row| {
            if (row != i) {
                const f = augmented[row][i];
                for (i..m + 1) |col| {
                    augmented[row][col] -= f * augmented[i][col];
                }
            }
        }
    }

    var coefficients = try allocator.alloc(f64, m);
    for (0..m) |i| coefficients[i] = augmented[i][m];

    // Stats
    const my = numerics.mean(Y);
    var ss_res: f64 = 0.0;
    var ss_tot: f64 = 0.0;
    for (0..n) |i| {
        var pred = coefficients[0];
        for (0..k) |j| pred += coefficients[j + 1] * X[j][i];
        ss_res += (Y[i] - pred) * (Y[i] - pred);
        ss_tot += (Y[i] - my) * (Y[i] - my);
    }
    const r_squared = 1.0 - (ss_res / ss_tot);
    const adjusted_r_squared = 1.0 - ((1.0 - r_squared) * (@as(f64, @floatFromInt(n)) - 1.0) / (@as(f64, @floatFromInt(n)) - @as(f64, @floatFromInt(k)) - 1.0));

    return .{
        .coefficients = coefficients,
        .r_squared = r_squared,
        .adjusted_r_squared = adjusted_r_squared,
    };
}

test "simple linear regression" {
    const x = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const y = [_]f64{ 2.0, 4.0, 5.0, 4.0, 5.0 };
    const res = try simpleLinearRegression(&x, &y, std.testing.allocator);
    defer std.testing.allocator.free(res.residuals);

    try std.testing.expectApproxEqAbs(@as(f64, 0.6), res.slope, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 2.2), res.intercept, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), res.r_squared, 1e-10);
}

test "multiple linear regression" {
    const x1 = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const x2 = [_]f64{ 1.0, 3.0, 2.0, 5.0, 4.0 }; // Not collinear with x1
    const y = [_]f64{ 10.0, 11.0, 12.0, 13.0, 14.0 };
    var X = [_][]const f64{ &x1, &x2 };

    const res = try multipleLinearRegression(&X, &y, std.testing.allocator);
    defer std.testing.allocator.free(res.coefficients);

    // Stats
    const y2 = [_]f64{ 7.0, 8.0, 9.0, 10.0, 11.0 }; // y = x1 + 6
    const res2 = try multipleLinearRegression(&X, &y2, std.testing.allocator);
    defer std.testing.allocator.free(res2.coefficients);

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), res2.r_squared, 1e-10);
}
