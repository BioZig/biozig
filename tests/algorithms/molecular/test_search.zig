const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const search = mol.search;
const molecular = @import("molecular");

test "SearchLayer - basic execution" {
    const dna_type = molecular.dna;
    var seq = try dna_type.DNA2.init("ACGTACGTACGT", testing.allocator);
    defer seq.deinit();

    var fm = try mol.indexing.FMIndex.init(testing.allocator, seq.view());
    defer fm.deinit();

    const mins = try mol.indexing.computeMinimizers(testing.allocator, seq.view(), 3, 3);
    defer testing.allocator.free(mins);

    var searcher = search.SearchLayer.init(testing.allocator, &fm, mins, seq.view());
    var query = try dna_type.DNA2.init("CGT", testing.allocator);
    defer query.deinit();

    const exact = searcher.exactMatch(query.view());
    try testing.expect(exact.end > exact.start);

    const approx = searcher.seedAndExtend(query.view(), 1);
    testing.allocator.free(approx);

    const banded = searcher.banding(query.view(), 5);
    testing.allocator.free(banded);

    const chained = searcher.chaining(mins);
    testing.allocator.free(chained);
}

test "SearchLayer - empty query" {
    const dna_type = molecular.dna;
    var seq = try dna_type.DNA2.init("ACGTACGTACGT", testing.allocator);
    defer seq.deinit();

    var fm = try mol.indexing.FMIndex.init(testing.allocator, seq.view());
    defer fm.deinit();

    const mins = try mol.indexing.computeMinimizers(testing.allocator, seq.view(), 3, 3);
    defer testing.allocator.free(mins);

    var searcher = search.SearchLayer.init(testing.allocator, &fm, mins, seq.view());
    var query = try dna_type.DNA2.init("", testing.allocator);
    defer query.deinit();

    const exact = searcher.exactMatch(query.view());
    try testing.expectEqual(@as(usize, 0), exact.start);

    const approx = searcher.seedAndExtend(query.view(), 1);
    try testing.expectEqual(@as(usize, 0), approx.len);
    testing.allocator.free(approx);

    const banded = searcher.banding(query.view(), 5);
    try testing.expectEqual(@as(usize, 0), banded.len);
    testing.allocator.free(banded);
}

test "SearchLayer - empty sequence and minimizers" {
    const dna_type = molecular.dna;
    var seq = try dna_type.DNA2.init("", testing.allocator);
    defer seq.deinit();

    var fm = try mol.indexing.FMIndex.init(testing.allocator, seq.view());
    defer fm.deinit();

    var mins = [_]mol.indexing.Minimizer{};
    var searcher = search.SearchLayer.init(testing.allocator, &fm, &mins, seq.view());

    const chained = searcher.chaining(&mins);
    try testing.expectEqual(@as(usize, 0), chained.len);
    testing.allocator.free(chained);
}
