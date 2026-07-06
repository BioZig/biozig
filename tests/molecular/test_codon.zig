const std = @import("std");
const molecular = @import("molecular");
const codon = molecular.codon;
const rna = molecular.rna;

test "Codon initialization and conversion - exhaustive" {
    const c1 = codon.Codon.init(rna.Nucleotide.A, rna.Nucleotide.U, rna.Nucleotide.G);
    try std.testing.expectEqual(codon.AminoAcid.M, c1.toAminoAcid());

    var buf: [3]u8 = undefined;
    c1.toString(&buf);
    try std.testing.expectEqualStrings("AUG", &buf);

    const c2 = try codon.Codon.fromString("UAA");
    try std.testing.expectEqual(codon.AminoAcid.Stop, c2.toAminoAcid());
}

test "Synonymous codons exhaustive" {
    const syn = codon.synonymousCodons(codon.AminoAcid.L);
    try std.testing.expectEqual(@as(usize, 6), syn.len);

    const syn_w = codon.synonymousCodons(codon.AminoAcid.W);
    try std.testing.expectEqual(@as(usize, 1), syn_w.len);

    const syn_stop = codon.synonymousCodons(codon.AminoAcid.Stop);
    try std.testing.expectEqual(@as(usize, 3), syn_stop.len);

    const syn_a = codon.synonymousCodons(codon.AminoAcid.A);
    try std.testing.expectEqual(@as(usize, 4), syn_a.len);

    const syn_m = codon.synonymousCodons(codon.AminoAcid.M);
    try std.testing.expectEqual(@as(usize, 1), syn_m.len);
}

test "All codons string parsing" {
    const all_strings = [_][]const u8{ "UUU", "UUC", "UUA", "UUG", "CUU", "CUC", "CUA", "CUG", "AUU", "AUC", "AUA", "AUG", "GUU", "GUC", "GUA", "GUG", "UCU", "UCC", "UCA", "UCG", "CCU", "CCC", "CCA", "CCG", "ACU", "ACC", "ACA", "ACG", "GCU", "GCC", "GCA", "GCG", "UAU", "UAC", "UAA", "UAG", "CAU", "CAC", "CAA", "CAG", "AAU", "AAC", "AAA", "AAG", "GAU", "GAC", "GAA", "GAG", "UGU", "UGC", "UGA", "UGG", "CGU", "CGC", "CGA", "CGG", "AGU", "AGC", "AGA", "AGG", "GGU", "GGC", "GGA", "GGG" };
    for (all_strings) |s| {
        const c = try codon.Codon.fromString(s);
        var b: [3]u8 = undefined;
        c.toString(&b);
        try std.testing.expectEqualStrings(s, &b);
    }
}

test "Invalid codons" {
    const err = codon.Codon.fromString("AXG");
    try std.testing.expectError(error.InvalidRNA_Nucleotide, err);
}

test "Codon array handling" {
    const c1 = try codon.Codon.fromString("AUG");
    const c2 = try codon.Codon.fromString("UAG");
    try std.testing.expect(c1.toAminoAcid() != c2.toAminoAcid());
    try std.testing.expectEqual(codon.AminoAcid.Stop, c2.toAminoAcid());
}

test "Codon memory operations" {
    var c_array: [5]codon.Codon = undefined;
    for (0..5) |i| {
        c_array[i] = codon.Codon.init(rna.Nucleotide.A, rna.Nucleotide.A, rna.Nucleotide.A);
    }

    for (0..5) |i| {
        try std.testing.expectEqual(codon.AminoAcid.K, c_array[i].toAminoAcid());
    }
}
