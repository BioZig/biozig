const std = @import("std");
const molecular = @import("molecular");
const dna = molecular.dna;

test "DNA2 basic operations - exhaustive" {
    const allocator = std.testing.allocator;
    const test_str = "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT";
    var d = try dna.DNA2.init(test_str, allocator);
    defer d.deinit();

    const view = d.view();
    try std.testing.expectEqual(@as(usize, 40), view.len);
    
    // Test get for all positions
    for (0..40) |i| {
        const expected: dna.Nucleotide = switch(i % 4) {
            0 => .A,
            1 => .C,
            2 => .G,
            3 => .T,
            else => unreachable,
        };
        try std.testing.expectEqual(expected, view.get(i));
    }
    
    // Slice tests
    const slice = view.slice(1, 4);
    try std.testing.expectEqual(@as(usize, 3), slice.len);
    try std.testing.expectEqual(dna.Nucleotide.C, slice.get(0));
    try std.testing.expectEqual(dna.Nucleotide.G, slice.get(1));
    try std.testing.expectEqual(dna.Nucleotide.T, slice.get(2));
    
    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 10), counts.a);
    try std.testing.expectEqual(@as(usize, 10), counts.c);
    try std.testing.expectEqual(@as(usize, 10), counts.g);
    try std.testing.expectEqual(@as(usize, 10), counts.t);
    
    const gc = view.gcContent();
    try std.testing.expectEqual(@as(f64, 0.5), gc);
}

test "DNA2 empty string" {
    const allocator = std.testing.allocator;
    var d = try dna.DNA2.init("", allocator);
    defer d.deinit();
    const view = d.view();
    try std.testing.expectEqual(@as(usize, 0), view.len);
    try std.testing.expectEqual(@as(f64, 0.0), view.gcContent());
    
    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 0), counts.a);
    try std.testing.expectEqual(@as(usize, 0), counts.c);
    try std.testing.expectEqual(@as(usize, 0), counts.g);
    try std.testing.expectEqual(@as(usize, 0), counts.t);
}

test "DNA2 reverse and complement exhaustive" {
    const allocator = std.testing.allocator;
    var d = try dna.DNA2.init("ACGT", allocator);
    defer d.deinit();
    
    var rev = try d.view().reverse(allocator);
    defer rev.deinit();
    try std.testing.expectEqual(dna.Nucleotide.T, rev.get(0));
    try std.testing.expectEqual(dna.Nucleotide.G, rev.get(1));
    try std.testing.expectEqual(dna.Nucleotide.C, rev.get(2));
    try std.testing.expectEqual(dna.Nucleotide.A, rev.get(3));
    
    var comp = try d.view().complement(allocator);
    defer comp.deinit();
    try std.testing.expectEqual(dna.Nucleotide.T, comp.get(0));
    try std.testing.expectEqual(dna.Nucleotide.G, comp.get(1));
    try std.testing.expectEqual(dna.Nucleotide.C, comp.get(2));
    try std.testing.expectEqual(dna.Nucleotide.A, comp.get(3));
    
    var rev_comp = try d.view().reverseComplement(allocator);
    defer rev_comp.deinit();
    try std.testing.expectEqual(dna.Nucleotide.A, rev_comp.get(0));
    try std.testing.expectEqual(dna.Nucleotide.C, rev_comp.get(1));
    try std.testing.expectEqual(dna.Nucleotide.G, rev_comp.get(2));
    try std.testing.expectEqual(dna.Nucleotide.T, rev_comp.get(3));
}

test "DNA2 invalid characters" {
    const allocator = std.testing.allocator;
    const err = dna.DNA2.init("ACGTX", allocator);
    try std.testing.expectError(error.InvalidNucleotide, err);
}

test "DNA4 exhaustive basic operations" {
    const allocator = std.testing.allocator;
    var d = try dna.DNA4.init("ARNY", allocator);
    defer d.deinit();

    const view = d.view();
    try std.testing.expectEqual(@as(usize, 4), view.len);
    try std.testing.expectEqual(dna.IUPAC.A, view.get(0));
    try std.testing.expectEqual(dna.IUPAC.R, view.get(1));
    try std.testing.expectEqual(dna.IUPAC.N, view.get(2));
    try std.testing.expectEqual(dna.IUPAC.Y, view.get(3));
    
    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 1), counts.a);
    try std.testing.expectEqual(@as(usize, 3), counts.other);
    
    var comp = try view.complement(allocator);
    defer comp.deinit();
    try std.testing.expectEqual(dna.IUPAC.T, comp.get(0));
    try std.testing.expectEqual(dna.IUPAC.Y, comp.get(1));
    try std.testing.expectEqual(dna.IUPAC.N, comp.get(2));
    try std.testing.expectEqual(dna.IUPAC.R, comp.get(3));
}

test "DNA4 empty string" {
    const allocator = std.testing.allocator;
    var d = try dna.DNA4.init("", allocator);
    defer d.deinit();
    const view = d.view();
    try std.testing.expectEqual(@as(usize, 0), view.len);
    try std.testing.expectEqual(@as(f64, 0.0), view.gcContent());
}

test "DNA4 all IUPAC characters" {
    const allocator = std.testing.allocator;
    const all_chars = "ACGTURYSWKMBDHVN";
    var d = try dna.DNA4.init(all_chars, allocator);
    defer d.deinit();
    const view = d.view();
    try std.testing.expectEqual(@as(usize, 16), view.len);
    
    // GC content check for DNA4
    const gc = view.gcContent();
    // Approximate, mostly checking it doesn't crash and is > 0
    try std.testing.expect(gc > 0.0);
}

test "DNA2 long sequences" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 10000);
    defer allocator.free(buf);
    @memset(buf, 'A');
    
    var d = try dna.DNA2.init(buf, allocator);
    defer d.deinit();
    
    const view = d.view();
    try std.testing.expectEqual(@as(usize, 10000), view.len);
    try std.testing.expectEqual(@as(f64, 0.0), view.gcContent());
    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 10000), counts.a);
    try std.testing.expectEqual(@as(usize, 0), counts.c);
    try std.testing.expectEqual(@as(usize, 0), counts.g);
    try std.testing.expectEqual(@as(usize, 0), counts.t);
}

test "DNA4 long sequences" {
    const allocator = std.testing.allocator;
    const buf = try allocator.alloc(u8, 10000);
    defer allocator.free(buf);
    @memset(buf, 'N');
    
    var d = try dna.DNA4.init(buf, allocator);
    defer d.deinit();
    
    const view = d.view();
    try std.testing.expectEqual(@as(usize, 10000), view.len);
    const counts = view.counts();
    try std.testing.expectEqual(@as(usize, 10000), counts.other);
    
    const gc = view.gcContent();
    try std.testing.expectEqual(@as(f64, 0.5), gc);
}

test "DNA2 and DNA4 interoperability logic" {
    // Check that we can manipulate views effectively
    const allocator = std.testing.allocator;
    var d2 = try dna.DNA2.init("ACGT", allocator);
    defer d2.deinit();
    
    var d4 = try dna.DNA4.init("ACGT", allocator);
    defer d4.deinit();
    
    try std.testing.expectEqual(d2.view().len, d4.view().len);
    
    var d2_rev = try d2.view().reverse(allocator);
    defer d2_rev.deinit();
    
    var d4_rev = try d4.view().reverse(allocator);
    defer d4_rev.deinit();
    
    try std.testing.expectEqual(d2_rev.view().len, d4_rev.view().len);
}

test "IUPAC character mappings" {
    // Explicitly test complement mappings for DNA4 IUPAC 
    try std.testing.expectEqual(dna.IUPAC.T, dna.DNA4View.complementIUPAC(dna.IUPAC.A));
    try std.testing.expectEqual(dna.IUPAC.A, dna.DNA4View.complementIUPAC(dna.IUPAC.T));
    try std.testing.expectEqual(dna.IUPAC.G, dna.DNA4View.complementIUPAC(dna.IUPAC.C));
    try std.testing.expectEqual(dna.IUPAC.C, dna.DNA4View.complementIUPAC(dna.IUPAC.G));
    try std.testing.expectEqual(dna.IUPAC.N, dna.DNA4View.complementIUPAC(dna.IUPAC.N));
    try std.testing.expectEqual(dna.IUPAC.R, dna.DNA4View.complementIUPAC(dna.IUPAC.Y));
    try std.testing.expectEqual(dna.IUPAC.Y, dna.DNA4View.complementIUPAC(dna.IUPAC.R));
    try std.testing.expectEqual(dna.IUPAC.S, dna.DNA4View.complementIUPAC(dna.IUPAC.S));
    try std.testing.expectEqual(dna.IUPAC.W, dna.DNA4View.complementIUPAC(dna.IUPAC.W));
}
