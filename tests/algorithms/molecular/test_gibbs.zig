const std = @import("std");
const alg = @import("algorithms");
const mol = alg.molecular;
const gibbs = mol.gibbs;

test "GibbsSampler - normal" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "ACGTACG", "ACCTACG", "ATGTACG" };
    var sampler = gibbs.GibbsSampler.init(alloc, &seqs, 4);
    const res = try sampler.sample(10);
    defer alloc.free(res);
    try std.testing.expectEqual(@as(usize, 3), res.len);
    for (res) |motif| {
        try std.testing.expectEqual(@as(usize, 4), motif.len);
    }
}

test "GibbsSampler - short sequences" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "AC", "A", "ATGTACG" };
    var sampler = gibbs.GibbsSampler.init(alloc, &seqs, 4);
    const res = try sampler.sample(10);
    defer alloc.free(res);
    try std.testing.expectEqual(@as(usize, 3), res.len);
    try std.testing.expectEqual(@as(usize, 2), res[0].len);
    try std.testing.expectEqual(@as(usize, 1), res[1].len);
    try std.testing.expectEqual(@as(usize, 4), res[2].len);
}

test "GibbsSampler - empty sequences" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "", "", "" };
    var sampler = gibbs.GibbsSampler.init(alloc, &seqs, 4);
    const res = try sampler.sample(5);
    defer alloc.free(res);
    try std.testing.expectEqual(@as(usize, 3), res.len);
    for (res) |motif| {
        try std.testing.expectEqual(@as(usize, 0), motif.len);
    }
}

test "GibbsSampler - zero iterations" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "ACGTACG", "ACCTACG", "ATGTACG" };
    var sampler = gibbs.GibbsSampler.init(alloc, &seqs, 4);
    const res = try sampler.sample(0);
    defer alloc.free(res);
    try std.testing.expectEqual(@as(usize, 3), res.len);
    for (res) |motif| {
        try std.testing.expectEqual(@as(usize, 4), motif.len);
    }
}

test "GibbsSampler - zero motif length" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "ACGT", "ACCT", "ATGT" };
    var sampler = gibbs.GibbsSampler.init(alloc, &seqs, 0);
    const res = try sampler.sample(5);
    defer alloc.free(res);
    try std.testing.expectEqual(@as(usize, 3), res.len);
    for (res) |motif| {
        try std.testing.expectEqual(@as(usize, 0), motif.len);
    }
}
