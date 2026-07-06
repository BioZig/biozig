const std = @import("std");
const testing = std.testing;

/// Calculates Transition/Transversion (Ti/Tv) ratio between two aligned sequences.
/// Assumes sequences are of the same length and contain valid uppercase/lowercase DNA characters.
/// Ignores gaps ('-') or Ns.
pub fn calculateTiTvRatio(seq1: []const u8, seq2: []const u8) !f64 {
    if (seq1.len != seq2.len) return error.SequenceLengthMismatch;

    var transitions: f64 = 0;
    var transversions: f64 = 0;

    for (seq1, seq2) |c1, c2| {
        const b1 = std.ascii.toUpper(c1);
        const b2 = std.ascii.toUpper(c2);

        if (b1 == b2) continue;
        if (!isBase(b1) or !isBase(b2)) continue;

        if (isTransition(b1, b2)) {
            transitions += 1;
        } else {
            transversions += 1;
        }
    }

    if (transversions == 0.0) {
        if (transitions == 0.0) return 0.0;
        return std.math.inf(f64);
    }

    return transitions / transversions;
}

fn isBase(b: u8) bool {
    return b == 'A' or b == 'C' or b == 'G' or b == 'T';
}

fn isTransition(b1: u8, b2: u8) bool {
    // A <-> G
    if ((b1 == 'A' and b2 == 'G') or (b1 == 'G' and b2 == 'A')) return true;
    // C <-> T
    if ((b1 == 'C' and b2 == 'T') or (b1 == 'T' and b2 == 'C')) return true;
    return false;
}

pub const WindowMetrics = struct {
    gc_content: f64,
    gc_skew: f64,
};

/// Calculates GC Content and GC Skew for sliding windows of a given sequence.
/// Returns a slice of WindowMetrics allocated with the provided allocator.
/// Caller must free the result.
pub fn slidingWindowMetrics(allocator: std.mem.Allocator, seq: []const u8, window_size: usize, step_size: usize) ![]WindowMetrics {
    if (window_size == 0 or step_size == 0) return error.InvalidWindowParameters;
    if (seq.len == 0) return &[_]WindowMetrics{};

    var metrics = std.ArrayList(WindowMetrics).empty;
    errdefer metrics.deinit(allocator);

    var start: usize = 0;
    while (start < seq.len) {
        const end = @min(start + window_size, seq.len);
        const window = seq[start..end];

        var g: f64 = 0;
        var c: f64 = 0;
        var a: f64 = 0;
        var t: f64 = 0;

        for (window) |char| {
            const base = std.ascii.toUpper(char);
            switch (base) {
                'G' => g += 1,
                'C' => c += 1,
                'A' => a += 1,
                'T' => t += 1,
                else => {},
            }
        }

        const gc_total = g + c;
        const all_total = gc_total + a + t;

        const gc_content = if (all_total > 0) gc_total / all_total else 0.0;
        const gc_skew = if (gc_total > 0) (g - c) / gc_total else 0.0;

        try metrics.append(allocator, .{
            .gc_content = gc_content,
            .gc_skew = gc_skew,
        });

        start += step_size;
    }

    return metrics.toOwnedSlice(allocator);
}

test "calculateTiTvRatio" {
    // Test 1: Transition A <-> G
    try testing.expectApproxEqAbs(@as(f64, std.math.inf(f64)), try calculateTiTvRatio("A", "G"), 0.001);

    // Test 2: Transversion A <-> C
    try testing.expectApproxEqAbs(@as(f64, 0.0), try calculateTiTvRatio("A", "C"), 0.001);

    // Test 3: Mix of transitions and transversions
    // seq1: ACGTAA
    // seq2: GCATCC
    // A->G (Ti), C->C (match), G->A (Ti), T->T (match), A->C (Tv), A->C (Tv)
    // 2 Ti, 2 Tv -> ratio 1.0
    try testing.expectApproxEqAbs(@as(f64, 1.0), try calculateTiTvRatio("ACGTAA", "GCATCC"), 0.001);

    // Test 4: With Ns and gaps
    try testing.expectApproxEqAbs(@as(f64, 1.0), try calculateTiTvRatio("ACGTAAN-", "GCATCCN-"), 0.001);
}

test "slidingWindowMetrics" {
    const allocator = testing.allocator;

    const seq = "GCGCATAT";
    const metrics = try slidingWindowMetrics(allocator, seq, 4, 4);
    defer allocator.free(metrics);

    try testing.expectEqual(@as(usize, 2), metrics.len);
    try testing.expectApproxEqAbs(@as(f64, 1.0), metrics[0].gc_content, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), metrics[0].gc_skew, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), metrics[1].gc_content, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), metrics[1].gc_skew, 0.001);

    const metrics2 = try slidingWindowMetrics(allocator, "GGGCCC", 3, 3);
    defer allocator.free(metrics2);
    try testing.expectEqual(@as(usize, 2), metrics2.len);
    try testing.expectApproxEqAbs(@as(f64, 1.0), metrics2[0].gc_content, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 1.0), metrics2[0].gc_skew, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 1.0), metrics2[1].gc_content, 0.001);
    try testing.expectApproxEqAbs(@as(f64, -1.0), metrics2[1].gc_skew, 0.001);
}
