const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;

pub const AlignmentOptions = struct {
    match_score: i32 = 1,
    mismatch_penalty: i32 = -1,
    gap_penalty: i32 = -2,
};

pub const AlignmentResult = struct {
    score: i32,
    aligned_a: []const u8,
    aligned_b: []const u8,

    pub fn deinit(self: AlignmentResult, allocator: std.mem.Allocator) void {
        allocator.free(self.aligned_a);
        allocator.free(self.aligned_b);
    }
};

fn nucToChar(n: dna_module.Nucleotide) u8 {
    return switch (n) {
        .A => 'A',
        .C => 'C',
        .G => 'G',
        .T => 'T',
    };
}

/// Global Alignment using Needleman-Wunsch algorithm.
pub fn globalAlignment(allocator: std.mem.Allocator, a: DNA2View, b: DNA2View, opts: AlignmentOptions) !AlignmentResult {
    const rows = a.len + 1;
    const cols = b.len + 1;

    // Allocate score matrix
    var dp = try allocator.alloc(i32, rows * cols);
    defer allocator.free(dp);

    // Initialize first column and first row with gap penalties
    for (0..rows) |i| dp[i * cols + 0] = @as(i32, @intCast(i)) * opts.gap_penalty;
    for (0..cols) |j| dp[0 * cols + j] = @as(i32, @intCast(j)) * opts.gap_penalty;

    // Fill DP matrix
    for (1..rows) |i| {
        for (1..cols) |j| {
            const match = dp[(i - 1) * cols + (j - 1)] + if (a.get(i - 1) == b.get(j - 1)) opts.match_score else opts.mismatch_penalty;
            const delete = dp[(i - 1) * cols + j] + opts.gap_penalty;
            const insert = dp[i * cols + (j - 1)] + opts.gap_penalty;
            dp[i * cols + j] = @max(match, @max(delete, insert));
        }
    }

    // Backtrack to build aligned strings
    var align_a = std.ArrayList(u8).empty;
    var align_b = std.ArrayList(u8).empty;
    defer align_a.deinit(allocator);
    defer align_b.deinit(allocator);

    var i: usize = a.len;
    var j: usize = b.len;

    while (i > 0 or j > 0) {
        if (i > 0 and j > 0) {
            const score_current = dp[i * cols + j];
            const score_diag = dp[(i - 1) * cols + (j - 1)];
            const match_val = if (a.get(i - 1) == b.get(j - 1)) opts.match_score else opts.mismatch_penalty;

            if (score_current == score_diag + match_val) {
                try align_a.append(allocator, nucToChar(a.get(i - 1)));
                try align_b.append(allocator, nucToChar(b.get(j - 1)));
                i -= 1;
                j -= 1;
                continue;
            }
        }

        if (i > 0 and dp[i * cols + j] == dp[(i - 1) * cols + j] + opts.gap_penalty) {
            try align_a.append(allocator, nucToChar(a.get(i - 1)));
            try align_b.append(allocator, '-');
            i -= 1;
        } else {
            try align_a.append(allocator, '-');
            try align_b.append(allocator, nucToChar(b.get(j - 1)));
            j -= 1;
        }
    }

    std.mem.reverse(u8, align_a.items);
    std.mem.reverse(u8, align_b.items);

    return AlignmentResult{
        .score = dp[(rows - 1) * cols + (cols - 1)],
        .aligned_a = try align_a.toOwnedSlice(allocator),
        .aligned_b = try align_b.toOwnedSlice(allocator),
    };
}

/// Local Alignment using Smith-Waterman algorithm.
pub fn localAlignment(allocator: std.mem.Allocator, a: DNA2View, b: DNA2View, opts: AlignmentOptions) !AlignmentResult {
    const cols = b.len + 1;

    const V = 16;
    const SimdVec = @Vector(V, i32);
    const padded_a_len = (a.len + V - 1) / V * V;
    const padded_rows = padded_a_len + 1;

    // column-major DP matrix for better SIMD memory access
    var dp = try allocator.alloc(i32, padded_rows * cols);
    defer allocator.free(dp);
    @memset(dp, 0);

    // Build profiles for query sequence 'a'
    var profiles = try allocator.alloc(i32, 4 * padded_a_len);
    defer allocator.free(profiles);

    for (0..4) |c| {
        for (0..a.len) |i| {
            const is_match = @intFromEnum(a.get(i)) == c;
            profiles[c * padded_a_len + i] = if (is_match) opts.match_score else opts.mismatch_penalty;
        }
        for (a.len..padded_a_len) |i| {
            profiles[c * padded_a_len + i] = opts.mismatch_penalty;
        }
    }

    var max_score: i32 = 0;
    var max_i: usize = 0;
    var max_j: usize = 0;

    const gap_vec: SimdVec = @splat(opts.gap_penalty);
    const zero_vec: SimdVec = @splat(0);

    for (1..cols) |j| {
        const b_char = @intFromEnum(b.get(j - 1));

        var i: usize = 1;
        while (i <= a.len) : (i += V) {
            const offset = b_char * padded_a_len + i - 1;
            const match_arr: [V]i32 = profiles[offset..][0..V].*;
            const match_vec: SimdVec = match_arr;

            const diag_arr: [V]i32 = dp[(j - 1) * padded_rows + i - 1 ..][0..V].*;
            const diag_vec: SimdVec = diag_arr;

            const left_arr: [V]i32 = dp[(j - 1) * padded_rows + i ..][0..V].*;
            const left_vec: SimdVec = left_arr;

            const base_vec = @max(zero_vec, @max(diag_vec + match_vec, left_vec + gap_vec));

            const base_arr: [V]i32 = base_vec;
            @memcpy(dp[j * padded_rows + i .. j * padded_rows + i + V], &base_arr);
        }

        // Scalar fixup for vertical dependency (delete)
        var top_score: i32 = dp[j * padded_rows + 0]; // 0
        for (1..a.len + 1) |row_i| {
            const delete = top_score + opts.gap_penalty;
            const current = dp[j * padded_rows + row_i];
            const score = @max(current, delete);
            dp[j * padded_rows + row_i] = score;
            top_score = score;

            if (score > max_score) {
                max_score = score;
                max_i = row_i;
                max_j = j;
            }
        }
    }

    var align_a = std.ArrayList(u8).empty;
    var align_b = std.ArrayList(u8).empty;
    defer align_a.deinit(allocator);
    defer align_b.deinit(allocator);

    var backtrack_i = max_i;
    var backtrack_j = max_j;

    while (backtrack_i > 0 and backtrack_j > 0 and dp[backtrack_j * padded_rows + backtrack_i] > 0) {
        const score_current = dp[backtrack_j * padded_rows + backtrack_i];
        const score_diag = dp[(backtrack_j - 1) * padded_rows + (backtrack_i - 1)];
        const match_val = if (a.get(backtrack_i - 1) == b.get(backtrack_j - 1)) opts.match_score else opts.mismatch_penalty;

        if (score_current == score_diag + match_val) {
            try align_a.append(allocator, nucToChar(a.get(backtrack_i - 1)));
            try align_b.append(allocator, nucToChar(b.get(backtrack_j - 1)));
            backtrack_i -= 1;
            backtrack_j -= 1;
        } else if (score_current == dp[backtrack_j * padded_rows + backtrack_i - 1] + opts.gap_penalty) {
            try align_a.append(allocator, nucToChar(a.get(backtrack_i - 1)));
            try align_b.append(allocator, '-');
            backtrack_i -= 1;
        } else {
            try align_a.append(allocator, '-');
            try align_b.append(allocator, nucToChar(b.get(backtrack_j - 1)));
            backtrack_j -= 1;
        }
    }

    std.mem.reverse(u8, align_a.items);
    std.mem.reverse(u8, align_b.items);

    return AlignmentResult{
        .score = max_score,
        .aligned_a = try align_a.toOwnedSlice(allocator),
        .aligned_b = try align_b.toOwnedSlice(allocator),
    };
}

test "Sequence Alignment - Global (Needleman-Wunsch)" {
    const alloc = std.testing.allocator;
    var seqA = try dna_module.DNA2.init("GCATGC", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("GATTACA", alloc);
    defer seqB.deinit();

    const res = try globalAlignment(alloc, seqA.view(), seqB.view(), .{});
    defer res.deinit(alloc);

    try std.testing.expectEqual(@as(i32, -2), res.score);
}

test "Sequence Alignment - Local (Smith-Waterman)" {
    const alloc = std.testing.allocator;
    var seqA = try dna_module.DNA2.init("GGTTGACTA", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("TGTTACGG", alloc);
    defer seqB.deinit();

    const res = try localAlignment(alloc, seqA.view(), seqB.view(), .{ .match_score = 3, .mismatch_penalty = -3, .gap_penalty = -2 });
    defer res.deinit(alloc);

    try std.testing.expectEqual(@as(i32, 13), res.score);
    try std.testing.expectEqualStrings("GTTGAC", res.aligned_a);
    try std.testing.expectEqualStrings("GTT-AC", res.aligned_b);
}
