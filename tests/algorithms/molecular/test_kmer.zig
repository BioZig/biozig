const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const kmer = mol.kmer;
const molecular = @import("molecular");
const dna = molecular.dna;

test "countKmers - Empty Sequence" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("", alloc);
    defer seq.deinit();

    var counts = try kmer.countKmers(alloc, seq.view(), 3);
    defer counts.deinit();
    try testing.expectEqual(@as(usize, 0), counts.count());
}

test "countKmers - Length Less Than K" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("AC", alloc);
    defer seq.deinit();

    var counts = try kmer.countKmers(alloc, seq.view(), 3);
    defer counts.deinit();
    try testing.expectEqual(@as(usize, 0), counts.count());
}

test "countKmers - Normal Sequence" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("ATATAT", alloc);
    defer seq.deinit();

    var counts = try kmer.countKmers(alloc, seq.view(), 2);
    defer counts.deinit();

    var kmer_at = try dna.DNA2.init("AT", alloc);
    defer kmer_at.deinit();
    var kmer_ta = try dna.DNA2.init("TA", alloc);
    defer kmer_ta.deinit();

    try testing.expectEqual(@as(usize, 3), counts.get(kmer_at.view()).?);
    try testing.expectEqual(@as(usize, 2), counts.get(kmer_ta.view()).?);
}
