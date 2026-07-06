const std = @import("std");
const alg = @import("algorithms");
const mol = alg.molecular;
const distance = mol.distance;
const dna_module = @import("molecular").dna;

test "hammingDistance - normal" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("GATTACA", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("GACTATA", alloc);
    defer b.deinit();

    const dist = try distance.hammingDistance(a.view(), b.view());
    try std.testing.expectEqual(@as(usize, 2), dist);
}

test "hammingDistance - different lengths" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("GATTACA", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("GAT", alloc);
    defer b.deinit();

    try std.testing.expectError(error.LengthMismatch, distance.hammingDistance(a.view(), b.view()));
}

test "hammingDistance - empty" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("", alloc);
    defer b.deinit();

    const dist = try distance.hammingDistance(a.view(), b.view());
    try std.testing.expectEqual(@as(usize, 0), dist);
}

test "hammingDistance - long byte aligned" {
    const alloc = std.testing.allocator;
    // 32 chars long
    var a = try dna_module.DNA2.init("GATTACAGATTACAGATTACAGATTACAGATT", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("GATTACAGATTACAGATTACAGATTACAGATA", alloc);
    defer b.deinit();

    const dist = try distance.hammingDistance(a.view(), b.view());
    try std.testing.expectEqual(@as(usize, 1), dist);
}

test "levenshteinDistance - normal" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("GATTACA", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("GATACCA", alloc);
    defer b.deinit();

    const dist = try distance.levenshteinDistance(alloc, a.view(), b.view());
    try std.testing.expectEqual(@as(usize, 2), dist);
}

test "levenshteinDistance - identical" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("GATTACA", alloc);
    defer a.deinit();

    const dist = try distance.levenshteinDistance(alloc, a.view(), a.view());
    try std.testing.expectEqual(@as(usize, 0), dist);
}

test "levenshteinDistance - empty a" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("GAT", alloc);
    defer b.deinit();

    const dist = try distance.levenshteinDistance(alloc, a.view(), b.view());
    try std.testing.expectEqual(@as(usize, 3), dist);
}

test "levenshteinDistance - empty both" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("", alloc);
    defer b.deinit();

    const dist = try distance.levenshteinDistance(alloc, a.view(), b.view());
    try std.testing.expectEqual(@as(usize, 0), dist);
}
