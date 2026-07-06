const std = @import("std");
const core = @import("core");
const numerics = core.numerics;
const math_utils = @import("math_utils.zig");

/// Result of a hypothesis test.
pub const TestResult = struct {
    statistic: f64,
    p_value: f64,
};

/// Computes the p-value for a given t-statistic and degrees of freedom (two-tailed).
pub fn tPValue(t: f64, df: f64) f64 {
    const abs_t = @abs(t);
    const x = df / (df + abs_t * abs_t);
    return math_utils.regularizedIncompleteBeta(x, df / 2.0, 0.5);
}

/// One-sample Student's t-test.
pub fn studentTTestOneSample(data: []const f64, mu0: f64) TestResult {
    const n = @as(f64, @floatFromInt(data.len));
    const m = numerics.mean(data);
    const s = @sqrt(numerics.variance(data));
    const t = (m - mu0) / (s / @sqrt(n));
    return .{
        .statistic = t,
        .p_value = tPValue(t, n - 1.0),
    };
}

/// Two-sample Student's t-test (equal variance).
pub fn studentTTestTwoSample(a: []const f64, b: []const f64) TestResult {
    const na = @as(f64, @floatFromInt(a.len));
    const nb = @as(f64, @floatFromInt(b.len));
    const ma = numerics.mean(a);
    const mb = numerics.mean(b);
    const va = numerics.variance(a);
    const vb = numerics.variance(b);

    const df = na + nb - 2.0;
    const sp = @sqrt(((na - 1.0) * va + (nb - 1.0) * vb) / df);
    const t = (ma - mb) / (sp * @sqrt(1.0 / na + 1.0 / nb));

    return .{
        .statistic = t,
        .p_value = tPValue(t, df),
    };
}

/// Welch's t-test (unequal variance).
pub fn welchTTest(a: []const f64, b: []const f64) TestResult {
    const na = @as(f64, @floatFromInt(a.len));
    const nb = @as(f64, @floatFromInt(b.len));
    const ma = numerics.mean(a);
    const mb = numerics.mean(b);
    const va = numerics.variance(a);
    const vb = numerics.variance(b);

    const se_a = va / na;
    const se_b = vb / nb;
    const t = (ma - mb) / @sqrt(se_a + se_b);
    const df = std.math.pow(f64, se_a + se_b, 2.0) / (std.math.pow(f64, se_a, 2.0) / (na - 1.0) + std.math.pow(f64, se_b, 2.0) / (nb - 1.0));

    return .{
        .statistic = t,
        .p_value = tPValue(t, df),
    };
}

/// Paired t-test.
pub fn pairedTTest(a: []const f64, b: []const f64, allocator: std.mem.Allocator) !TestResult {
    std.debug.assert(a.len == b.len);
    const diffs = try allocator.alloc(f64, a.len);
    defer allocator.free(diffs);
    for (0..a.len) |i| {
        diffs[i] = a[i] - b[i];
    }
    return studentTTestOneSample(diffs, 0.0);
}

/// Chi-square goodness-of-fit test.
pub fn chiSquareTest(observed: []const f64, expected: []const f64) TestResult {
    std.debug.assert(observed.len == expected.len);
    var chi: f64 = 0.0;
    for (0..observed.len) |i| {
        const diff = observed[i] - expected[i];
        chi += diff * diff / expected[i];
    }
    const df = @as(f64, @floatFromInt(observed.len - 1));
    return .{
        .statistic = chi,
        .p_value = 1.0 - math_utils.regularizedIncompleteGammaP(df / 2.0, chi / 2.0),
    };
}

/// Fisher's Exact Test (2x2 contingency table, two-tailed).
pub fn fisherExactTest(a: usize, b: usize, c: usize, d: usize) f64 {
    const n = a + b + c + d;
    const row1_sum = a + b;
    const col1_sum = a + c;
    const hg = @import("distributions.zig").Hypergeometric{
        .N = n,
        .K = row1_sum,
        .n = col1_sum,
    };

    const p_observed = hg.pdf(a);
    var p_total: f64 = 0.0;

    // Iterate over all possible values of 'a' given row/col sums
    const min_a = if (row1_sum + col1_sum > n) row1_sum + col1_sum - n else 0;
    const max_a = @min(row1_sum, col1_sum);

    for (min_a..max_a + 1) |i| {
        const p_i = hg.pdf(i);
        if (p_i <= p_observed + 1e-12) {
            p_total += p_i;
        }
    }
    return @min(1.0, p_total);
}

/// Wilcoxon Signed Rank test.
pub fn wilcoxonSignedRank(a: []const f64, b: []const f64, allocator: std.mem.Allocator) !TestResult {
    std.debug.assert(a.len == b.len);
    const n = a.len;

    const Diff = struct {
        abs_val: f64,
        sign: f64,
    };
    var diffs = std.ArrayList(Diff).init(allocator);
    defer diffs.deinit();

    for (0..n) |i| {
        const d = a[i] - b[i];
        if (d != 0.0) {
            try diffs.append(.{ .abs_val = @abs(d), .sign = if (d > 0) 1.0 else -1.0 });
        }
    }

    const n_non_zero = diffs.items.len;
    if (n_non_zero == 0) return .{ .statistic = 0.0, .p_value = 1.0 };

    std.sort.block(Diff, diffs.items, {}, struct {
        fn lessThan(_: void, lhs: Diff, rhs: Diff) bool {
            return lhs.abs_val < rhs.abs_val;
        }
    }.lessThan);

    var w_plus: f64 = 0.0;
    var i: usize = 0;
    while (i < n_non_zero) {
        var j = i + 1;
        while (j < n_non_zero and diffs.items[j].abs_val == diffs.items[i].abs_val) j += 1;
        const avg_rank = @as(f64, @floatFromInt(i + j + 1)) / 2.0;
        for (i..j) |k| {
            if (diffs.items[k].sign > 0) w_plus += avg_rank;
        }
        i = j;
    }

    const n_f = @as(f64, @floatFromInt(n_non_zero));
    const w_expected = n_f * (n_f + 1.0) / 4.0;
    const w_var = n_f * (n_f + 1.0) * (2.0 * n_f + 1.0) / 24.0;
    const z = @abs(w_plus - w_expected) / @sqrt(w_var);
    const p = 2.0 * (1.0 - (@import("distributions.zig").Normal{ .mu = 0.0, .sigma = 1.0 }).cdf(z));

    return .{
        .statistic = w_plus,
        .p_value = p,
    };
}

/// Mann-Whitney U test.
pub fn mannWhitneyU(a: []const f64, b: []const f64, allocator: std.mem.Allocator) !TestResult {
    const na = a.len;
    const nb = b.len;

    // Combine and rank
    const Combined = struct {
        val: f64,
        group: u8,
    };
    var combined = try allocator.alloc(Combined, na + nb);
    defer allocator.free(combined);
    for (0..na) |i| combined[i] = .{ .val = a[i], .group = 0 };
    for (0..nb) |i| combined[na + i] = .{ .val = b[i], .group = 1 };

    std.sort.block(Combined, combined, {}, struct {
        fn lessThan(_: void, lhs: Combined, rhs: Combined) bool {
            return lhs.val < rhs.val;
        }
    }.lessThan);

    var ranks = try allocator.alloc(f64, na + nb);
    defer allocator.free(ranks);
    var i: usize = 0;
    while (i < na + nb) {
        var j = i + 1;
        while (j < na + nb and combined[j].val == combined[i].val) j += 1;
        const avg_rank = @as(f64, @floatFromInt(i + j + 1)) / 2.0;
        for (i..j) |k| ranks[k] = avg_rank;
        i = j;
    }

    var r1: f64 = 0.0;
    for (0..na + nb) |k| {
        if (combined[k].group == 0) r1 += ranks[k];
    }

    const na_f = @as(f64, @floatFromInt(na));
    const nb_f = @as(f64, @floatFromInt(nb));
    const stat_u1 = r1 - (na_f * (na_f + 1.0)) / 2.0;
    const stat_u2 = na_f * nb_f - stat_u1;
    const u = @min(stat_u1, stat_u2);

    // Normal approximation (two-tailed)
    const mean_u = na_f * nb_f / 2.0;
    const sigma_u = @sqrt(na_f * nb_f * (na_f + nb_f + 1.0) / 12.0);
    const z = @abs(u - mean_u) / sigma_u;
    const p = 2.0 * (1.0 - (@import("distributions.zig").Normal{ .mu = 0.0, .sigma = 1.0 }).cdf(z));

    return .{
        .statistic = u,
        .p_value = p,
    };
}

test "t-test p-value" {
    // Reference: t=2.0, df=10 -> p ~ 0.07335
    try std.testing.expectApproxEqAbs(@as(f64, 0.07335), tPValue(2.0, 10.0), 1e-4);
}

test "student t-test one sample" {
    const data = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 }; // mean=3, var=2.5, n=5
    const res = studentTTestOneSample(&data, 3.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), res.statistic, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), res.p_value, 1e-10);
}
