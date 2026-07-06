const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const msa = mol.msa;

test "MSA - Empty input" {
    var seqs = [_][]const u8{};
    var m = msa.MSA.init(testing.allocator, &seqs);
    const res = try m.alignProgressive(.{});
    defer if (res.len > 0) {
        for (res) |s| testing.allocator.free(s);
        testing.allocator.free(res);
    };
    try testing.expectEqual(@as(usize, 0), res.len);
}

test "MSA - Single sequence" {
    var seqs = [_][]const u8{"ACGT"};
    var m = msa.MSA.init(testing.allocator, &seqs);
    const res = try m.alignProgressive(.{});
    defer {
        for (res) |s| testing.allocator.free(s);
        testing.allocator.free(res);
    }
    try testing.expectEqual(@as(usize, 1), res.len);
    try testing.expectEqualStrings("ACGT", res[0]);
}

test "MSA - Multiple sequences" {
    var seqs = [_][]const u8{ "ACGT", "ACCT", "ATGT" };
    var m = msa.MSA.init(testing.allocator, &seqs);
    const res = try m.alignProgressive(.{});
    defer {
        for (res) |s| testing.allocator.free(s);
        testing.allocator.free(res);
    }
    try testing.expectEqual(@as(usize, 3), res.len);
    try testing.expectEqualStrings("ACGT", res[0]);
    try testing.expectEqualStrings("ACCT", res[1]);
    try testing.expectEqualStrings("ATGT", res[2]);
}

test "MSA - Sequences of different lengths" {
    var seqs = [_][]const u8{ "AC", "ACTG", "A" };
    var m = msa.MSA.init(testing.allocator, &seqs);
    const res = try m.alignProgressive(.{});
    defer {
        for (res) |s| testing.allocator.free(s);
        testing.allocator.free(res);
    }
    try testing.expectEqual(@as(usize, 3), res.len);
}
