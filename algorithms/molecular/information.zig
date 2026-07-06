const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;

/// Calculates Shannon Entropy of a sequence.
pub fn shannonEntropy(sequence: DNA2View) f64 {
    if (sequence.len == 0) return 0.0;

    var counts = [_]usize{0} ** 4; // A, C, G, T

    if (sequence.start % 4 == 0) {
        const bytes_len = sequence.len / 4;
        const seq_bytes = sequence.bytes[sequence.start / 4 .. (sequence.start / 4) + bytes_len];

        var i: usize = 0;
        // Process in 64-bit (8-byte) chunks
        while (i + 8 <= seq_bytes.len) : (i += 8) {
            const word = std.mem.readInt(u64, seq_bytes[i .. i + 8][0..8], .little);
            const not_word = ~word;

            counts[0] += @popCount(not_word & (not_word >> 1) & 0x5555555555555555);
            counts[1] += @popCount(word & (not_word >> 1) & 0x5555555555555555);
            counts[2] += @popCount(not_word & (word >> 1) & 0x5555555555555555);
            counts[3] += @popCount(word & (word >> 1) & 0x5555555555555555);
        }

        // Process remaining bytes
        for (seq_bytes[i..]) |byte_val| {
            const not_byte = ~byte_val;
            counts[0] += @popCount(@as(u8, @truncate(not_byte & (not_byte >> 1) & 0x55)));
            counts[1] += @popCount(@as(u8, @truncate(byte_val & (not_byte >> 1) & 0x55)));
            counts[2] += @popCount(@as(u8, @truncate(not_byte & (byte_val >> 1) & 0x55)));
            counts[3] += @popCount(@as(u8, @truncate(byte_val & (byte_val >> 1) & 0x55)));
        }

        // Remainder
        for (bytes_len * 4..sequence.len) |idx| {
            counts[@intFromEnum(sequence.get(idx))] += 1;
        }
    } else {
        // Scalar fallback
        for (0..sequence.len) |idx| {
            counts[@intFromEnum(sequence.get(idx))] += 1;
        }
    }

    var entropy: f64 = 0.0;
    const len_f = @as(f64, @floatFromInt(sequence.len));

    for (counts) |count| {
        if (count > 0) {
            const p = @as(f64, @floatFromInt(count)) / len_f;
            entropy -= p * @log2(p);
        }
    }

    return entropy;
}

const DNA2ViewContext = struct {
    pub fn hash(ctx: @This(), view: DNA2View) u64 {
        _ = ctx;
        return view.hash();
    }
    pub fn eql(ctx: @This(), a: DNA2View, b: DNA2View) bool {
        _ = ctx;
        return a.equals(b);
    }
};

/// Calculates linguistic sequence complexity.
pub fn linguisticComplexity(allocator: std.mem.Allocator, sequence: DNA2View) !f64 {
    if (sequence.len == 0) return 0.0;

    var observed: usize = 0;
    var max_possible: usize = 0;

    for (1..sequence.len + 1) |k| {
        var kmer_set = std.HashMap(DNA2View, void, DNA2ViewContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer kmer_set.deinit();

        var i: usize = 0;
        while (i <= sequence.len - k) : (i += 1) {
            const kmer = sequence.slice(i, i + k);
            try kmer_set.put(kmer, {});
        }

        observed += kmer_set.count();

        const possible_for_len = sequence.len - k + 1;
        const theoretical_max: usize = if (k >= @bitSizeOf(usize) / 2) std.math.maxInt(usize) else @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(2 * k));
        max_possible += @min(theoretical_max, possible_for_len);
    }

    if (max_possible == 0) return 0.0;
    return @as(f64, @floatFromInt(observed)) / @as(f64, @floatFromInt(max_possible));
}

test "Sequence Information - Shannon Entropy" {
    const alloc = std.testing.allocator;
    var s1 = try dna_module.DNA2.init("AAAA", alloc);
    defer s1.deinit();
    const e1 = shannonEntropy(s1.view());
    try std.testing.expectEqual(@as(f64, 0.0), e1);

    var s2 = try dna_module.DNA2.init("ATCG", alloc);
    defer s2.deinit();
    const e2 = shannonEntropy(s2.view());
    try std.testing.expectEqual(@as(f64, 2.0), e2);
}

test "Sequence Information - Linguistic Complexity" {
    const alloc = std.testing.allocator;

    var s1 = try dna_module.DNA2.init("AAAA", alloc);
    defer s1.deinit();
    const c1 = try linguisticComplexity(alloc, s1.view());
    try std.testing.expectEqual(@as(f64, 0.4), c1);

    var s2 = try dna_module.DNA2.init("ATGC", alloc);
    defer s2.deinit();
    const c2 = try linguisticComplexity(alloc, s2.view());
    try std.testing.expectEqual(@as(f64, 1.0), c2);
}
