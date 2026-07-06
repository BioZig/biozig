const std = @import("std");

/// Computes the sum of a float slice stably using the Kahan summation algorithm.
pub fn kahanSum(slice: []const f64) f64 {
    const V = @Vector(8, f64);
    const vlen = 8;
    var sum_v: V = @splat(0.0);
    var c_v: V = @splat(0.0);

    var i: usize = 0;
    while (i + vlen <= slice.len) : (i += vlen) {
        const x_v: V = slice[i .. i + vlen][0..vlen].*;
        const y_v = x_v - c_v;
        const t_v = sum_v + y_v;
        c_v = (t_v - sum_v) - y_v;
        sum_v = t_v;
    }

    var sum: f64 = 0.0;
    var c: f64 = 0.0;
    inline for (0..vlen) |lane| {
        const x = sum_v[lane] - c_v[lane];
        const y = x - c;
        const t = sum + y;
        c = (t - sum) - y;
        sum = t;
    }

    while (i < slice.len) : (i += 1) {
        const x = slice[i];
        const y = x - c;
        const t = sum + y;
        c = (t - sum) - y;
        sum = t;
    }
    return sum;
}

/// Computes the mean of a float slice.
pub fn mean(slice: []const f64) f64 {
    if (slice.len == 0) return 0.0;
    return kahanSum(slice) / @as(f64, @floatFromInt(slice.len));
}

/// Computes the sample variance of a float slice.
pub fn variance(slice: []const f64) f64 {
    if (slice.len < 2) return 0.0;
    const m = mean(slice);

    const V = @Vector(8, f64);
    const vlen = 8;
    var sum_v: V = @splat(0.0);
    var c_v: V = @splat(0.0);
    const m_v: V = @splat(m);

    var i: usize = 0;
    while (i + vlen <= slice.len) : (i += vlen) {
        const x_v: V = slice[i .. i + vlen][0..vlen].*;
        const delta_v = x_v - m_v;
        const x_sq_v = delta_v * delta_v;
        const y_v = x_sq_v - c_v;
        const t_v = sum_v + y_v;
        c_v = (t_v - sum_v) - y_v;
        sum_v = t_v;
    }

    var m2: f64 = 0.0;
    var final_c: f64 = 0.0;
    inline for (0..vlen) |lane| {
        const x = sum_v[lane] - c_v[lane];
        const y = x - final_c;
        const t = m2 + y;
        final_c = (t - m2) - y;
        m2 = t;
    }

    while (i < slice.len) : (i += 1) {
        const delta = slice[i] - m;
        const x = delta * delta;
        const y = x - final_c;
        const t = m2 + y;
        final_c = (t - m2) - y;
        m2 = t;
    }

    return m2 / @as(f64, @floatFromInt(slice.len - 1));
}

/// Computes the sample covariance between two float slices of equal length.
pub fn covariance(x: []const f64, y: []const f64) f64 {
    std.debug.assert(x.len == y.len);
    if (x.len < 2) return 0.0;
    const x_mean = mean(x);
    const y_mean = mean(y);

    const V = @Vector(8, f64);
    const vlen = 8;
    var sum_v: V = @splat(0.0);
    var c_v: V = @splat(0.0);
    const xm_v: V = @splat(x_mean);
    const ym_v: V = @splat(y_mean);

    var i: usize = 0;
    while (i + vlen <= x.len) : (i += vlen) {
        const x_v: V = x[i .. i + vlen][0..vlen].*;
        const y_v: V = y[i .. i + vlen][0..vlen].*;
        const val_v = (x_v - xm_v) * (y_v - ym_v);
        
        const term_v = val_v - c_v;
        const t_v = sum_v + term_v;
        c_v = (t_v - sum_v) - term_v;
        sum_v = t_v;
    }

    var sum: f64 = 0.0;
    var final_c: f64 = 0.0;
    inline for (0..vlen) |lane| {
        const val = sum_v[lane] - c_v[lane];
        const term = val - final_c;
        const t = sum + term;
        final_c = (t - sum) - term;
        sum = t;
    }

    while (i < x.len) : (i += 1) {
        const val = (x[i] - x_mean) * (y[i] - y_mean);
        const term = val - final_c;
        const t = sum + term;
        final_c = (t - sum) - term;
        sum = t;
    }

    return sum / @as(f64, @floatFromInt(x.len - 1));
}

/// Computes the p-th quantile of a float slice using the standard R-7 method.
/// p must be in the range [0.0, 1.0].
pub fn quantile(slice: []const f64, p: f64, allocator: std.mem.Allocator) !f64 {
    std.debug.assert(p >= 0.0 and p <= 1.0);
    if (slice.len == 0) return 0.0;
    if (slice.len == 1) return slice[0];

    const copy = try allocator.alloc(f64, slice.len);
    defer allocator.free(copy);
    @memcpy(copy, slice);
    std.sort.block(f64, copy, {}, std.sort.asc(f64));

    const h = @as(f64, @floatFromInt(copy.len - 1)) * p;
    const index = @as(usize, @intFromFloat(@floor(h)));
    const frac = h - @floor(h);

    if (index >= copy.len - 1) {
        return copy[copy.len - 1];
    }
    return copy[index] + frac * (copy[index + 1] - copy[index]);
}

test "kahan summation stability" {
    const vals = [_]f64{ 1.0, 1e10, 1.0, -1e10 };
    try std.testing.expectEqual(kahanSum(&vals), 2.0);
}

test "mean, variance, covariance" {
    const x = [_]f64{ 2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0 };
    const y = [_]f64{ 1.0, 3.0, 2.0, 4.0, 3.0, 4.0, 6.0, 8.0 };

    try std.testing.expectApproxEqAbs(@as(f64, 5.0), mean(&x), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 4.571428571428571), variance(&x), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 4.571428571428571), covariance(&x, &y), 1e-5);
}

test "quantiles" {
    const data = [_]f64{ 3.0, 6.0, 7.0, 8.0, 8.0, 10.0, 13.0, 15.0, 16.0, 20.0 };
    const q25 = try quantile(&data, 0.25, std.testing.allocator);
    const q50 = try quantile(&data, 0.50, std.testing.allocator);
    const q75 = try quantile(&data, 0.75, std.testing.allocator);

    try std.testing.expectApproxEqAbs(@as(f64, 7.25), q25, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 9.0), q50, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 14.5), q75, 1e-5);
}

test "vector operations" {
    const x = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0 };
    const y = [_]f64{ 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0 };
    
    // dot product
    const dot = dotProduct(&x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, 165.0), dot, 1e-5);
    
    // norm
    const n = norm(&x);
    try std.testing.expectApproxEqAbs(@as(f64, 16.8819430161), n, 1e-5);
    
    // vector add
    var add_res: [9]f64 = undefined;
    vectorAdd(&add_res, &x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), add_res[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), add_res[8], 1e-5);
    
    // vector sub
    var sub_res: [9]f64 = undefined;
    vectorSub(&sub_res, &x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, -8.0), sub_res[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 8.0), sub_res[8], 1e-5);
    
    // normalize
    var norm_arr = [_]f64{ 3.0, 4.0 };
    normalize(&norm_arr);
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), norm_arr[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), norm_arr[1], 1e-5);
}

/// Computes the dot product of two float slices of equal length.
pub fn dotProduct(x: []const f64, y: []const f64) f64 {
    std.debug.assert(x.len == y.len);
    const V = @Vector(8, f64);
    const vlen = 8;
    var sum_v: V = @splat(0.0);

    var i: usize = 0;
    while (i + vlen <= x.len) : (i += vlen) {
        const x_v: V = x[i .. i + vlen][0..vlen].*;
        const y_v: V = y[i .. i + vlen][0..vlen].*;
        sum_v += x_v * y_v;
    }

    var sum: f64 = 0.0;
    inline for (0..vlen) |lane| {
        sum += sum_v[lane];
    }

    while (i < x.len) : (i += 1) {
        sum += x[i] * y[i];
    }
    return sum;
}

/// Computes the element-wise addition of two float slices.
pub fn vectorAdd(result: []f64, x: []const f64, y: []const f64) void {
    std.debug.assert(x.len == y.len and x.len == result.len);
    const V = @Vector(8, f64);
    const vlen = 8;

    var i: usize = 0;
    while (i + vlen <= x.len) : (i += vlen) {
        const x_v: V = x[i .. i + vlen][0..vlen].*;
        const y_v: V = y[i .. i + vlen][0..vlen].*;
        result[i .. i + vlen][0..vlen].* = x_v + y_v;
    }

    while (i < x.len) : (i += 1) {
        result[i] = x[i] + y[i];
    }
}

/// Computes the element-wise subtraction of two float slices.
pub fn vectorSub(result: []f64, x: []const f64, y: []const f64) void {
    std.debug.assert(x.len == y.len and x.len == result.len);
    const V = @Vector(8, f64);
    const vlen = 8;

    var i: usize = 0;
    while (i + vlen <= x.len) : (i += vlen) {
        const x_v: V = x[i .. i + vlen][0..vlen].*;
        const y_v: V = y[i .. i + vlen][0..vlen].*;
        result[i .. i + vlen][0..vlen].* = x_v - y_v;
    }

    while (i < x.len) : (i += 1) {
        result[i] = x[i] - y[i];
    }
}

/// Computes the L2 norm of a float slice.
pub fn norm(x: []const f64) f64 {
    return @sqrt(dotProduct(x, x));
}

/// Normalizes a float slice in-place to have unit L2 norm.
pub fn normalize(x: []f64) void {
    const n = norm(x);
    if (n == 0.0) return;
    const inv_n = 1.0 / n;

    const V = @Vector(8, f64);
    const vlen = 8;
    const inv_v: V = @splat(inv_n);

    var i: usize = 0;
    while (i + vlen <= x.len) : (i += vlen) {
        const x_v: V = x[i .. i + vlen][0..vlen].*;
        x[i .. i + vlen][0..vlen].* = x_v * inv_v;
    }

    while (i < x.len) : (i += 1) {
        x[i] *= inv_n;
    }
}
