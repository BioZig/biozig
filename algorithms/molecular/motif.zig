const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;

/// Search for exact matches of a motif string in a sequence.
/// Returns a list of zero-indexed starting positions.
pub fn searchMotifExact(allocator: std.mem.Allocator, sequence: DNA2View, motif: DNA2View) ![]usize {
    if (motif.len == 0 or motif.len > sequence.len) {
        return &[_]usize{};
    }

    var positions = std.ArrayList(usize).empty;
    errdefer positions.deinit(allocator);

    var i: usize = 0;
    while (i <= sequence.len - motif.len) : (i += 1) {
        if (sequence.slice(i, i + motif.len).equals(motif)) {
            try positions.append(allocator, i);
        }
    }

    return positions.toOwnedSlice(allocator);
}

/// A Position Weight Matrix (PWM) for DNA (A, C, G, T).
pub const PWM = struct {
    matrix: []const [4]f64,

    /// Scores a sequence window of the same length as the PWM against the PWM.
    pub fn scoreWindow(self: PWM, sequence: DNA2View) f64 {
        std.debug.assert(sequence.len == self.matrix.len);
        
        var score: f64 = 0.0;
        for (0..sequence.len) |i| {
            const idx: usize = @intFromEnum(sequence.get(i));
            score += self.matrix[i][idx];
        }
        return score;
    }

    /// Scans the entire sequence, returning the starting positions and scores of windows
    /// that score equal to or greater than the given threshold.
    pub fn scanThreshold(self: PWM, allocator: std.mem.Allocator, sequence: DNA2View, threshold: f64) ![]const Hit {
        if (sequence.len < self.matrix.len) return &[_]Hit{};

        var hits = std.ArrayList(Hit).empty;
        errdefer hits.deinit(allocator);

        var i: usize = 0;
        while (i <= sequence.len - self.matrix.len) : (i += 1) {
            const window = sequence.slice(i, i + self.matrix.len);
            const score = self.scoreWindow(window);
            if (score >= threshold) {
                try hits.append(allocator, .{ .position = i, .score = score });
            }
        }

        return hits.toOwnedSlice(allocator);
    }

    pub const Hit = struct {
        position: usize,
        score: f64,
    };
};

test "Sequence Motif - Exact Search" {
    const alloc = std.testing.allocator;
    var seq = try dna_module.DNA2.init("GATTACAGAT", alloc);
    defer seq.deinit();
    
    var motif = try dna_module.DNA2.init("GAT", alloc);
    defer motif.deinit();

    const res = try searchMotifExact(alloc, seq.view(), motif.view());
    defer alloc.free(res);
    
    try std.testing.expectEqual(@as(usize, 2), res.len);
    try std.testing.expectEqual(@as(usize, 0), res[0]);
    try std.testing.expectEqual(@as(usize, 7), res[1]);
}

test "Sequence Motif - PWM Scoring" {
    const alloc = std.testing.allocator;
    // Simple PWM for "TATA"
    //      A    C    G    T
    const pwm_data = [_][4]f64{
        .{ 0.1, 0.1, 0.1, 0.9 }, // T
        .{ 0.9, 0.1, 0.1, 0.1 }, // A
        .{ 0.1, 0.1, 0.1, 0.9 }, // T
        .{ 0.9, 0.1, 0.1, 0.1 }, // A
    };
    const pwm = PWM{ .matrix = &pwm_data };

    var seq = try dna_module.DNA2.init("GCTATAAA", alloc);
    defer seq.deinit();

    const hits = try pwm.scanThreshold(alloc, seq.view(), 3.0);
    defer alloc.free(hits);

    try std.testing.expectEqual(@as(usize, 1), hits.len);
    try std.testing.expectEqual(@as(usize, 2), hits[0].position); // "TATA" starts at index 2
    try std.testing.expect(hits[0].score > 3.5);
}
