const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const alignment = mol.alignment;
const molecular = @import("molecular");
const dna_module = molecular.dna;

test "globalAlignment: empty sequences" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("", alloc);
    defer seqB.deinit();

    const res = try alignment.globalAlignment(alloc, seqA.view(), seqB.view(), .{});
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, 0), res.score);
    try testing.expectEqualStrings("", res.aligned_a);
    try testing.expectEqualStrings("", res.aligned_b);
}

test "globalAlignment: one empty sequence" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("ACGT", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("", alloc);
    defer seqB.deinit();

    const res = try alignment.globalAlignment(alloc, seqA.view(), seqB.view(), .{ .gap_penalty = -2 });
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, -8), res.score);
    try testing.expectEqualStrings("ACGT", res.aligned_a);
    try testing.expectEqualStrings("----", res.aligned_b);
}

test "globalAlignment: exact match" {
    const alloc = testing.allocator;
    var seq = try dna_module.DNA2.init("ACGT", alloc);
    defer seq.deinit();

    const res = try alignment.globalAlignment(alloc, seq.view(), seq.view(), .{ .match_score = 1 });
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, 4), res.score);
    try testing.expectEqualStrings("ACGT", res.aligned_a);
    try testing.expectEqualStrings("ACGT", res.aligned_b);
}

test "globalAlignment: all mismatches" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("AAAA", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("TTTT", alloc);
    defer seqB.deinit();

    const res = try alignment.globalAlignment(alloc, seqA.view(), seqB.view(), .{ .mismatch_penalty = -1, .gap_penalty = -2 });
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, -4), res.score);
    try testing.expectEqualStrings("AAAA", res.aligned_a);
    try testing.expectEqualStrings("TTTT", res.aligned_b);
}

test "localAlignment: empty sequences" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("", alloc);
    defer seqB.deinit();

    const res = try alignment.localAlignment(alloc, seqA.view(), seqB.view(), .{});
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, 0), res.score);
    try testing.expectEqualStrings("", res.aligned_a);
    try testing.expectEqualStrings("", res.aligned_b);
}

test "localAlignment: no match" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("AAAA", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("TTTT", alloc);
    defer seqB.deinit();

    const res = try alignment.localAlignment(alloc, seqA.view(), seqB.view(), .{ .match_score = 1, .mismatch_penalty = -5, .gap_penalty = -5 });
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, 0), res.score);
    try testing.expectEqualStrings("", res.aligned_a);
    try testing.expectEqualStrings("", res.aligned_b);
}

test "localAlignment: exact match" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("GACGT", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("GACGT", alloc);
    defer seqB.deinit();

    const res = try alignment.localAlignment(alloc, seqA.view(), seqB.view(), .{ .match_score = 1 });
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, 5), res.score);
    try testing.expectEqualStrings("GACGT", res.aligned_a);
    try testing.expectEqualStrings("GACGT", res.aligned_b);
}

test "localAlignment: partial match" {
    const alloc = testing.allocator;
    var seqA = try dna_module.DNA2.init("TTTTGACGTAAAA", alloc);
    defer seqA.deinit();
    var seqB = try dna_module.DNA2.init("CCCGACGTCCC", alloc);
    defer seqB.deinit();

    const res = try alignment.localAlignment(alloc, seqA.view(), seqB.view(), .{ .match_score = 2, .mismatch_penalty = -3, .gap_penalty = -2 });
    defer res.deinit(alloc);

    try testing.expectEqual(@as(i32, 10), res.score);
    try testing.expectEqualStrings("GACGT", res.aligned_a);
    try testing.expectEqualStrings("GACGT", res.aligned_b);
}
