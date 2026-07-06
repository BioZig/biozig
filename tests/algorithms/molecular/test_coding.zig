const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const coding = mol.coding;
const molecular = @import("molecular");
const dna_module = molecular.dna;

test "translateDNA: empty sequence" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("", alloc);
    defer seq.deinit();

    const protein = try coding.translateDNA(alloc, seq.view());
    defer alloc.free(protein);

    try testing.expectEqualStrings("", protein);
}

test "translateDNA: non-multiple of 3" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("ATGG", alloc);
    defer seq.deinit();

    const protein = try coding.translateDNA(alloc, seq.view());
    defer alloc.free(protein);

    try testing.expectEqualStrings("M", protein);
}

test "translateDNA: stops at stop codon" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("ATGTAAATG", alloc);
    defer seq.deinit();

    const protein = try coding.translateDNA(alloc, seq.view());
    defer alloc.free(protein);

    try testing.expectEqualStrings("M*", protein);
}

test "translateDNA: all amino acids" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("ATGCGT", alloc);
    defer seq.deinit();

    const protein = try coding.translateDNA(alloc, seq.view());
    defer alloc.free(protein);

    try testing.expectEqualStrings("MR", protein);
}

test "detectORFs: empty sequence" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("", alloc);
    defer seq.deinit();

    const orfs = try coding.detectORFs(alloc, seq.view(), 3);
    defer alloc.free(orfs);

    try testing.expectEqual(@as(usize, 0), orfs.len);
}

test "detectORFs: basic ORF" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("ATGGCCATGTAA", alloc);
    defer seq.deinit();

    const orfs = try coding.detectORFs(alloc, seq.view(), 3);
    defer alloc.free(orfs);

    try testing.expectEqual(@as(usize, 1), orfs.len);
    try testing.expectEqual(@as(usize, 0), orfs[0].start);
    try testing.expectEqual(@as(usize, 12), orfs[0].end);
    try testing.expectEqual(@as(usize, 12), orfs[0].length);
}

test "detectORFs: different frame" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("AATGGCCATGTAA", alloc);
    defer seq.deinit();

    const orfs = try coding.detectORFs(alloc, seq.view(), 3);
    defer alloc.free(orfs);

    try testing.expectEqual(@as(usize, 1), orfs.len);
    try testing.expectEqual(@as(usize, 1), orfs[0].start);
    try testing.expectEqual(@as(usize, 13), orfs[0].end);
    try testing.expectEqual(@as(usize, 12), orfs[0].length);
}

test "detectORFs: minimum length filter" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("ATGTAA", alloc);
    defer seq.deinit();

    const orfs_short = try coding.detectORFs(alloc, seq.view(), 3);
    defer alloc.free(orfs_short);
    try testing.expectEqual(@as(usize, 1), orfs_short.len);

    const orfs_long = try coding.detectORFs(alloc, seq.view(), 9);
    defer alloc.free(orfs_long);
    try testing.expectEqual(@as(usize, 0), orfs_long.len);
}
