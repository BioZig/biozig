const std = @import("std");
const molecular = @import("molecular");
const protein = molecular.protein;

test "Protein basic operations - exhaustive" {
    const allocator = std.testing.allocator;
    const all_amino_acids = "ACDEFGHIKLMNPQRSTVWYX-*";
    var p = try protein.Protein.init(all_amino_acids, allocator);
    defer p.deinit();

    const view = p.view();
    try std.testing.expectEqual(@as(usize, 23), view.len);
    try std.testing.expectEqual(protein.AminoAcid.A, view.get(0));
    try std.testing.expectEqual(protein.AminoAcid.C, view.get(1));
    try std.testing.expectEqual(protein.AminoAcid.Stop, view.get(22));

    const w = view.molecularWeight();
    try std.testing.expect(w > 0.0);

    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 1), counts[@intFromEnum(protein.AminoAcid.A)]);
    try std.testing.expectEqual(@as(usize, 1), counts[@intFromEnum(protein.AminoAcid.Stop)]);
    try std.testing.expectEqual(@as(usize, 1), counts[@intFromEnum(protein.AminoAcid.W)]);
}

test "Protein empty string" {
    const allocator = std.testing.allocator;
    var p = try protein.Protein.init("", allocator);
    defer p.deinit();

    const view = p.view();
    try std.testing.expectEqual(@as(usize, 0), view.len);
    try std.testing.expectEqual(@as(f64, 0.0), view.molecularWeight());
}

test "Protein repeated amino acids" {
    const allocator = std.testing.allocator;
    var p = try protein.Protein.init("AAAAAAAAAA", allocator);
    defer p.deinit();

    const view = p.view();
    try std.testing.expectEqual(@as(usize, 10), view.len);
    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 10), counts[@intFromEnum(protein.AminoAcid.A)]);
    try std.testing.expectEqual(@as(usize, 0), counts[@intFromEnum(protein.AminoAcid.C)]);
}

test "Protein long sequence" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 5000);
    defer allocator.free(buf);
    @memset(buf, 'M');

    var p = try protein.Protein.init(buf, allocator);
    defer p.deinit();

    const view = p.view();
    try std.testing.expectEqual(@as(usize, 5000), view.len);
    try std.testing.expect(view.molecularWeight() > 1000.0);

    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 5000), counts[@intFromEnum(protein.AminoAcid.M)]);
}

test "Protein invalid characters" {
    const allocator = std.testing.allocator;
    const err = protein.Protein.init("ABCDJ", allocator);
    try std.testing.expectError(error.InvalidAminoAcid, err); // J is invalid
}

test "Protein weight calculation specifics" {
    const allocator = std.testing.allocator;
    var p = try protein.Protein.init("A", allocator);
    defer p.deinit();

    const view = p.view();
    const weight_a = view.molecularWeight();

    var p2 = try protein.Protein.init("G", allocator);
    defer p2.deinit();

    const weight_g = p2.view().molecularWeight();

    try std.testing.expect(weight_a != weight_g);
}

test "Protein sequence comparison" {
    const allocator = std.testing.allocator;
    var p1 = try protein.Protein.init("MWQ", allocator);
    defer p1.deinit();
    var p2 = try protein.Protein.init("MWQ", allocator);
    defer p2.deinit();

    try std.testing.expectEqual(p1.view().len, p2.view().len);
    for (0..p1.view().len) |i| {
        try std.testing.expectEqual(p1.get(i), p2.get(i));
    }
}
