const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const indexing = mol.indexing;
const molecular = @import("molecular");
const dna = molecular.dna;

test "FMIndex - Empty Sequence" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("", alloc);
    defer seq.deinit();

    var fm = try indexing.FMIndex.init(alloc, seq.view());
    defer fm.deinit();

    var query = try dna.DNA2.init("A", alloc);
    defer query.deinit();

    const res = fm.count(query.view());
    try testing.expectEqual(@as(usize, 0), res.end - res.start);
}

test "FMIndex - Normal Query" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("ACGTACGT", alloc);
    defer seq.deinit();

    var fm = try indexing.FMIndex.init(alloc, seq.view());
    defer fm.deinit();

    var query = try dna.DNA2.init("CGT", alloc);
    defer query.deinit();
    const res = fm.count(query.view());
    try testing.expectEqual(@as(usize, 2), res.end - res.start);

    var query_empty = try dna.DNA2.init("", alloc);
    defer query_empty.deinit();
    const res_empty = fm.count(query_empty.view());
    try testing.expectEqual(@as(usize, 9), res_empty.end - res_empty.start);

    var query_not_found = try dna.DNA2.init("AAAA", alloc);
    defer query_not_found.deinit();
    const res_not = fm.count(query_not_found.view());
    try testing.expectEqual(@as(usize, 0), res_not.end - res_not.start);
}

test "Minimizers - Length Less Than Window + K" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("AC", alloc);
    defer seq.deinit();

    // length = 2, w = 2, k = 2. w+k-1 = 3 > 2.
    // computeMinimizers allows seq.len >= k.
    const mins = try indexing.computeMinimizers(alloc, seq.view(), 2, 2);
    defer alloc.free(mins);
    try testing.expectEqual(@as(usize, 0), mins.len);
}

test "Minimizers - Normal Sequences" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("ACGTACGTACGT", alloc);
    defer seq.deinit();

    const mins = try indexing.computeMinimizers(alloc, seq.view(), 3, 3);
    defer alloc.free(mins);
    try testing.expect(mins.len > 0);
}
