const std = @import("std");
const core = @import("core");
const numerics = core.numerics;

/// Computes the weighted mean of a float slice.
pub fn weightedMean(slice: []const f64, weights: []const f64) f64 {
    std.debug.assert(slice.len == weights.len);
    if (slice.len == 0) return 0.0;

    var sum_wv: f64 = 0.0;
    var sum_w: f64 = 0.0;
    var c_wv: f64 = 0.0;
    var c_w: f64 = 0.0;

    for (0..slice.len) |i| {
        // Weighted value sum
        const wv = slice[i] * weights[i];
        const y_wv = wv - c_wv;
        const t_wv = sum_wv + y_wv;
        c_wv = (t_wv - sum_wv) - y_wv;
        sum_wv = t_wv;

        // Weight sum
        const y_w = weights[i] - c_w;
        const t_w = sum_w + y_w;
        c_w = (t_w - sum_w) - y_w;
        sum_w = t_w;
    }

    if (sum_w == 0.0) return 0.0;
    return sum_wv / sum_w;
}

/// Computes the median of a float slice.
pub fn median(slice: []const f64, allocator: std.mem.Allocator) !f64 {
    return try numerics.quantile(slice, 0.5, allocator);
}

/// Computes the mode of a float slice.
/// For floats, this returns the most frequent value.
pub fn mode(slice: []const f64, allocator: std.mem.Allocator) !?f64 {
    if (slice.len == 0) return null;
    var map = std.HashMap(f64, usize, struct {
        pub fn hash(_: @This(), key: f64) u64 {
            return @bitCast(key);
        }
        pub fn eql(_: @This(), a: f64, b: f64) bool {
            return a == b;
        }
    }, std.hash_map.default_max_load_percentage).init(allocator);
    defer map.deinit();

    for (slice) |x| {
        const entry = try map.getOrPut(x);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    var max_count: usize = 0;
    var result: ?f64 = null;
    var iter = map.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            result = entry.key_ptr.*;
        }
    }
    return result;
}

/// Computes the standard deviation of a float slice.
pub fn stdDev(slice: []const f64) f64 {
    return @sqrt(numerics.variance(slice));
}

/// Computes the coefficient of variation (CV) of a float slice.
pub fn coefficientOfVariation(slice: []const f64) f64 {
    const m = numerics.mean(slice);
    if (m == 0.0) return 0.0;
    return stdDev(slice) / m;
}

/// Computes the Median Absolute Deviation (MAD).
pub fn mad(slice: []const f64, allocator: std.mem.Allocator) !f64 {
    if (slice.len == 0) return 0.0;
    const med = try median(slice, allocator);

    var diffs = try allocator.alloc(f64, slice.len);
    defer allocator.free(diffs);

    for (0..slice.len) |i| {
        diffs[i] = @abs(slice[i] - med);
    }

    return try median(diffs, allocator);
}

/// Computes the quartiles (25th, 50th, 75th percentiles).
pub fn quartiles(slice: []const f64, allocator: std.mem.Allocator) ![3]f64 {
    return [3]f64{
        try numerics.quantile(slice, 0.25, allocator),
        try numerics.quantile(slice, 0.50, allocator),
        try numerics.quantile(slice, 0.75, allocator),
    };
}

/// Computes the p-th percentile.
pub fn percentile(slice: []const f64, p: f64, allocator: std.mem.Allocator) !f64 {
    std.debug.assert(p >= 0.0 and p <= 100.0);
    return try numerics.quantile(slice, p / 100.0, allocator);
}

test "weighted mean" {
    const vals = [_]f64{ 10.0, 20.0, 30.0 };
    const weights = [_]f64{ 1.0, 2.0, 3.0 };
    // (10*1 + 20*2 + 30*3) / (1+2+3) = (10 + 40 + 90) / 6 = 140 / 6 = 23.33333
    try std.testing.expectApproxEqAbs(@as(f64, 23.333333333333332), weightedMean(&vals, &weights), 1e-10);
}

test "median, mode, stdDev, cv, mad, quartiles" {
    const data = [_]f64{ 2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0 };
    const alloc = std.testing.allocator;

    try std.testing.expectApproxEqAbs(@as(f64, 4.5), try median(&data, alloc), 1e-10);
    try std.testing.expectEqual(@as(f64, 4.0), (try mode(&data, alloc)).?);
    try std.testing.expectApproxEqAbs(@as(f64, 2.138089935275812), stdDev(&data), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4276179870551624), coefficientOfVariation(&data), 1e-10);

    // MAD: median(|2-4.5|, |4-4.5|, |4-4.5|, |4-4.5|, |5-4.5|, |5-4.5|, |7-4.5|, |9-4.5|)
    // = median(2.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2.5, 4.5)
    // Sorted: 0.5, 0.5, 0.5, 0.5, 0.5, 2.5, 2.5, 4.5
    // Median of 8 elements: (0.5 + 0.5) / 2 = 0.5
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), try mad(&data, alloc), 1e-10);

    const q = try quartiles(&data, alloc);
    // Quantiles R-7:
    // 0.25 * (8-1) = 1.75 -> index 1 (val 4) + 0.75*(4-4) = 4
    // 0.5 * 7 = 3.5 -> index 3 (val 4) + 0.5*(5-4) = 4.5
    // 0.75 * 7 = 5.25 -> index 5 (val 5) + 0.25*(7-5) = 5.5
    try std.testing.expectApproxEqAbs(@as(f64, 4.0), q[0], 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 4.5), q[1], 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 5.5), q[2], 1e-10);
}
