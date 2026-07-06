const std = @import("std");

/// Represents the result of a GLM fit.
pub const GlmResult = struct {
    beta: f64,
    converged: bool,
    iterations: usize,
};

/// Fits a simple Negative Binomial GLM (log link) with a single intercept (or covariate) 
/// using Iteratively Reweighted Least Squares (IRLS).
/// `alpha` is the known dispersion parameter.
pub fn fitNbGlm1D(
    y: []const f64,
    x: []const f64,
    alpha: f64,
    max_iter: usize,
    tol: f64,
) GlmResult {
    var beta: f64 = 0.0; // Initial guess

    var sum_y: f64 = 0;
    for (y) |val| {
        sum_y += val;
    }
    const mean_y = sum_y / @as(f64, @floatFromInt(y.len));
    if (mean_y > 0) {
        beta = @log(mean_y);
    }

    var iter: usize = 0;
    var converged = false;

    while (iter < max_iter) : (iter += 1) {
        var score: f64 = 0;
        var information: f64 = 0;

        for (y, x) |y_i, x_i| {
            const eta = x_i * beta;
            const safe_eta = if (eta > 50.0) 50.0 else if (eta < -50.0) -50.0 else eta;
            const mu = @exp(safe_eta);
            
            const v = mu + alpha * mu * mu;
            
            const w = (mu * mu) / v; 
            
            score += x_i * w * (y_i - mu) / mu;
            information += x_i * x_i * w;
        }

        if (information == 0) {
            break; 
        }

        const delta = score / information;
        beta += delta;

        if (@abs(delta) < tol) {
            converged = true;
            break;
        }
    }

    return GlmResult{
        .beta = beta,
        .converged = converged,
        .iterations = iter,
    };
}

/// Empirical Bayes Shrinkage basics.
/// Shrinks gene-wise dispersions towards a common prior dispersion.
pub fn empiricalBayesShrinkage(
    allocator: std.mem.Allocator,
    dispersions: []const f64,
    prior_dispersion: f64,
    prior_df: f64,
) ![]f64 {
    const shrunk = try allocator.alloc(f64, dispersions.len);
    const df: f64 = 3.0; 
    
    for (dispersions, 0..) |disp, i| {
        shrunk[i] = (df * disp + prior_df * prior_dispersion) / (df + prior_df);
    }
    
    return shrunk;
}

test "Negative Binomial GLM IRLS" {
    const y = [_]f64{ 10.0, 12.0, 9.0, 15.0, 11.0 };
    const x = [_]f64{ 1.0, 1.0, 1.0, 1.0, 1.0 };
    const alpha = 0.1;

    const result = fitNbGlm1D(&y, &x, alpha, 100, 1e-6);

    try std.testing.expect(result.converged);
    
    const expected_mean = (10.0 + 12.0 + 9.0 + 15.0 + 11.0) / 5.0;
    const expected_beta = @log(expected_mean);
    try std.testing.expectApproxEqAbs(expected_beta, result.beta, 1e-4);
}

test "Empirical Bayes Shrinkage" {
    const allocator = std.testing.allocator;
    const dispersions = [_]f64{ 0.1, 0.5, 0.05, 0.2 };
    const prior_disp = 0.15;
    const prior_df = 5.0;

    const shrunk = try empiricalBayesShrinkage(allocator, &dispersions, prior_disp, prior_df);
    defer allocator.free(shrunk);

    try std.testing.expectEqual(@as(usize, 4), shrunk.len);

    const expected_0 = (3.0 * 0.1 + 5.0 * 0.15) / (3.0 + 5.0);
    try std.testing.expectApproxEqAbs(expected_0, shrunk[0], 1e-6);
    
    const expected_1 = (3.0 * 0.5 + 5.0 * 0.15) / (3.0 + 5.0);
    try std.testing.expectApproxEqAbs(expected_1, shrunk[1], 1e-6);
}
