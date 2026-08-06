const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;

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

pub fn countKmers(allocator: std.mem.Allocator, sequence: DNA2View, k: usize) !std.HashMap(DNA2View, usize, DNA2ViewContext, std.hash_map.default_max_load_percentage) {
    var counts = std.HashMap(DNA2View, usize, DNA2ViewContext, std.hash_map.default_max_load_percentage).init(allocator);
    errdefer counts.deinit();

    if (sequence.len < k) return counts;

    for (0..sequence.len - k + 1) |i| {
        const kmer = sequence.slice(i, i + k);
        const entry = try counts.getOrPut(kmer);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return counts;
}

test "Sequence K-mers - Counting" {
    const alloc = std.testing.allocator;
    var seq = try dna_module.DNA2.init("ATATAT", alloc);
    defer seq.deinit();

    var counts = try countKmers(alloc, seq.view(), 2);
    defer counts.deinit();

    var kmer_at = try dna_module.DNA2.init("AT", alloc);
    defer kmer_at.deinit();
    var kmer_ta = try dna_module.DNA2.init("TA", alloc);
    defer kmer_ta.deinit();

    try std.testing.expectEqual(@as(usize, 3), counts.get(kmer_at.view()).?);
    try std.testing.expectEqual(@as(usize, 2), counts.get(kmer_ta.view()).?);
}
