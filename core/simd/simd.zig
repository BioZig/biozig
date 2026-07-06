const std = @import("std");

/// Vectorized summation of f32 slice using @Vector SIMD.
pub fn sumFloat(slice: []const f32) f32 {
    const vec_len = 16;
    var i: usize = 0;
    var acc = @as(@Vector(vec_len, f32), @splat(0.0));

    while (i + vec_len <= slice.len) : (i += vec_len) {
        const chunk = slice[i..][0..vec_len];
        const vec: @Vector(vec_len, f32) = chunk.*;
        acc += vec;
    }

    var sum = @reduce(.Add, acc);
    while (i < slice.len) : (i += 1) {
        sum += slice[i];
    }
    return sum;
}

/// Vectorized summation of u32 slice using @Vector SIMD.
pub fn sumInt(slice: []const u32) u32 {
    const vec_len = 16;
    var i: usize = 0;
    var acc = @as(@Vector(vec_len, u32), @splat(0));

    while (i + vec_len <= slice.len) : (i += vec_len) {
        const chunk = slice[i..][0..vec_len];
        const vec: @Vector(vec_len, u32) = chunk.*;
        acc += vec;
    }

    var sum = @reduce(.Add, acc);
    while (i < slice.len) : (i += 1) {
        sum += slice[i];
    }
    return sum;
}

/// Vectorized counting of occurrences of a byte using @Vector SIMD.
pub fn countChar(slice: []const u8, char: u8) usize {
    const vec_len = 32;
    var i: usize = 0;
    var total: usize = 0;
    const char_vec = @as(@Vector(vec_len, u8), @splat(char));

    while (i + vec_len <= slice.len) : (i += vec_len) {
        const chunk = slice[i..][0..vec_len];
        const vec: @Vector(vec_len, u8) = chunk.*;
        const matches = vec == char_vec;
        const match_ints = @select(u8, matches, @as(@Vector(vec_len, u8), @splat(1)), @as(@Vector(vec_len, u8), @splat(0)));
        total += @reduce(.Add, match_ints);
    }

    while (i < slice.len) : (i += 1) {
        if (slice[i] == char) {
            total += 1;
        }
    }
    return total;
}

/// Vectorized counting of mismatches between two slices (Hamming distance).
pub fn countMismatches(a: []const u8, b: []const u8) usize {
    std.debug.assert(a.len == b.len);
    const vec_len = 32;
    var i: usize = 0;
    var total: usize = 0;

    while (i + vec_len <= a.len) : (i += vec_len) {
        const chunk_a = a[i..][0..vec_len];
        const chunk_b = b[i..][0..vec_len];
        const vec_a: @Vector(vec_len, u8) = chunk_a.*;
        const vec_b: @Vector(vec_len, u8) = chunk_b.*;
        const mismatches = vec_a != vec_b;
        const mismatch_ints = @select(u8, mismatches, @as(@Vector(vec_len, u8), @splat(1)), @as(@Vector(vec_len, u8), @splat(0)));
        total += @reduce(.Add, mismatch_ints);
    }

    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) {
            total += 1;
        }
    }
    return total;
}

test "simd summation" {
    const float_data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0 };
    const float_sum = sumFloat(&float_data);
    try std.testing.expectApproxEqAbs(float_sum, 171.0, 1e-5);

    const int_data = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 };
    const int_sum = sumInt(&int_data);
    try std.testing.expectEqual(int_sum, 171);
}

test "simd countChar" {
    const text = "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT"; // len = 40
    try std.testing.expectEqual(countChar(text, 'A'), 10);
    try std.testing.expectEqual(countChar(text, 'C'), 10);
    try std.testing.expectEqual(countChar(text, 'N'), 0);
}

test "simd countMismatches" {
    const seq1 = "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT";
    const seq2 = "ACGTTCGTACGTACGTACGTACGTACGTACGTACGTACTT";
    try std.testing.expectEqual(countMismatches(seq1, seq2), 2);
}
