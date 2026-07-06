const std = @import("std");
const molecular = @import("molecular");
const rna = molecular.rna;
const dna = molecular.dna;

test "RNA2 basic operations - exhaustive" {
    const allocator = std.testing.allocator;
    const test_str = "ACGUACGUACGUACGUACGU";
    var r = try rna.RNA2.init(test_str, allocator);
    defer r.deinit();

    const view = r.view();
    try std.testing.expectEqual(@as(usize, 20), view.len);

    // Test get for all positions
    for (0..20) |i| {
        const expected: rna.Nucleotide = switch (i % 4) {
            0 => .A,
            1 => .C,
            2 => .G,
            3 => .U,
            else => unreachable,
        };
        try std.testing.expectEqual(expected, view.get(i));
    }

    const slice = view.slice(1, 4);
    try std.testing.expectEqual(@as(usize, 3), slice.len);
    try std.testing.expectEqual(rna.Nucleotide.C, slice.get(0));

    const gc = view.gcContent();
    try std.testing.expectEqual(@as(f64, 0.5), gc);
}

test "RNA2 empty string" {
    const allocator = std.testing.allocator;
    var r = try rna.RNA2.init("", allocator);
    defer r.deinit();
    const view = r.view();
    try std.testing.expectEqual(@as(usize, 0), view.len);
    try std.testing.expectEqual(@as(f64, 0.0), view.gcContent());
}

test "RNA Transcription and Back-Transcription" {
    const allocator = std.testing.allocator;
    var d = try dna.DNA2.init("ACGT", allocator);
    defer d.deinit();

    var r_seq = try rna.transcribe2(d.view(), allocator);
    defer r_seq.deinit();

    try std.testing.expectEqual(rna.Nucleotide.A, r_seq.get(0));
    try std.testing.expectEqual(rna.Nucleotide.C, r_seq.get(1));
    try std.testing.expectEqual(rna.Nucleotide.G, r_seq.get(2));
    try std.testing.expectEqual(rna.Nucleotide.U, r_seq.get(3));

    var d2 = try rna.backTranscribe2(r_seq.view(), allocator);
    defer d2.deinit();
    try std.testing.expectEqual(dna.Nucleotide.A, d2.get(0));
    try std.testing.expectEqual(dna.Nucleotide.C, d2.get(1));
    try std.testing.expectEqual(dna.Nucleotide.G, d2.get(2));
    try std.testing.expectEqual(dna.Nucleotide.T, d2.get(3));
}

test "RNA4 Transcription" {
    const allocator = std.testing.allocator;
    var d = try dna.DNA4.init("ARYT", allocator);
    defer d.deinit();

    var r_seq = try rna.transcribe4(d.view(), allocator);
    defer r_seq.deinit();

    try std.testing.expectEqual(rna.IUPAC.A, r_seq.get(0));
    try std.testing.expectEqual(rna.IUPAC.R, r_seq.get(1));
    try std.testing.expectEqual(rna.IUPAC.Y, r_seq.get(2));
    try std.testing.expectEqual(rna.IUPAC.U, r_seq.get(3));
}

test "RNA2 long sequences" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 10000);
    defer allocator.free(buf);
    @memset(buf, 'U');

    var r_seq = try rna.RNA2.init(buf, allocator);
    defer r_seq.deinit();

    const view = r_seq.view();
    try std.testing.expectEqual(@as(usize, 10000), view.len);
    try std.testing.expectEqual(@as(f64, 0.0), view.gcContent());
}

test "RNA4 long sequences" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 10000);
    defer allocator.free(buf);
    @memset(buf, 'N');

    var r_seq = try rna.RNA4.init(buf, allocator);
    defer r_seq.deinit();

    const view = r_seq.view();
    try std.testing.expectEqual(@as(usize, 10000), view.len);
    try std.testing.expect(view.gcContent() > 0.0);
}

test "RNA2 invalid characters" {
    const allocator = std.testing.allocator;
    const err = rna.RNA2.init("ACGUX", allocator);
    try std.testing.expectError(error.InvalidRNA_Nucleotide, err);
}

test "RNA Transcription long sequences" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 5000);
    defer allocator.free(buf);
    @memset(buf, 'T');

    var d = try dna.DNA2.init(buf, allocator);
    defer d.deinit();

    var r_seq = try rna.transcribe2(d.view(), allocator);
    defer r_seq.deinit();

    try std.testing.expectEqual(@as(usize, 5000), r_seq.view().len);
    try std.testing.expectEqual(rna.Nucleotide.U, r_seq.get(0));
    try std.testing.expectEqual(rna.Nucleotide.U, r_seq.get(4999));
}

test "RNA4 Transcription long sequences" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 5000);
    defer allocator.free(buf);
    @memset(buf, 'N');

    var d = try dna.DNA4.init(buf, allocator);
    defer d.deinit();

    var r_seq = try rna.transcribe4(d.view(), allocator);
    defer r_seq.deinit();

    try std.testing.expectEqual(@as(usize, 5000), r_seq.view().len);
    try std.testing.expectEqual(rna.IUPAC.N, r_seq.get(0));
    try std.testing.expectEqual(rna.IUPAC.N, r_seq.get(4999));
}

test "RNA back transcription to DNA4" {
    const allocator = std.testing.allocator;
    var r_seq = try rna.RNA4.init("ARUY", allocator);
    defer r_seq.deinit();

    var d = try rna.backTranscribe4(r_seq.view(), allocator);
    defer d.deinit();

    try std.testing.expectEqual(dna.IUPAC.A, d.get(0));
    try std.testing.expectEqual(dna.IUPAC.R, d.get(1));
    try std.testing.expectEqual(dna.IUPAC.T, d.get(2));
    try std.testing.expectEqual(dna.IUPAC.Y, d.get(3));
}

test "RNA sequence matching and verification" {
    const allocator = std.testing.allocator;
    var r1 = try rna.RNA2.init("ACGU", allocator);
    defer r1.deinit();
    var r2 = try rna.RNA2.init("ACGU", allocator);
    defer r2.deinit();

    try std.testing.expectEqual(r1.view().len, r2.view().len);
    for (0..r1.view().len) |i| {
        try std.testing.expectEqual(r1.get(i), r2.get(i));
    }
}
