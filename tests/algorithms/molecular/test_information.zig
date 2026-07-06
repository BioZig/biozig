const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const information = mol.information;
const molecular = @import("molecular");
const dna = molecular.dna;

test "Shannon Entropy - Empty Sequence" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("", alloc);
    defer seq.deinit();

    const ent = information.shannonEntropy(seq.view());
    try testing.expectEqual(@as(f64, 0.0), ent);
}

test "Shannon Entropy - Uniform" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("ATCG", alloc);
    defer seq.deinit();

    const ent = information.shannonEntropy(seq.view());
    try testing.expectEqual(@as(f64, 2.0), ent);
}

test "Shannon Entropy - Single Nucleotide" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("AAAA", alloc);
    defer seq.deinit();

    const ent = information.shannonEntropy(seq.view());
    try testing.expectEqual(@as(f64, 0.0), ent);
}

test "Linguistic Complexity - Empty Sequence" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("", alloc);
    defer seq.deinit();

    const comp = try information.linguisticComplexity(alloc, seq.view());
    try testing.expectEqual(@as(f64, 0.0), comp);
}

test "Linguistic Complexity - Normal" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("ATGC", alloc);
    defer seq.deinit();

    const comp = try information.linguisticComplexity(alloc, seq.view());
    try testing.expectEqual(@as(f64, 1.0), comp);
}

test "Linguistic Complexity - Low Complexity" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("AAAA", alloc);
    defer seq.deinit();

    const comp = try information.linguisticComplexity(alloc, seq.view());
    try testing.expectEqual(@as(f64, 0.4), comp);
}
