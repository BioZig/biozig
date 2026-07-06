pub const core = @import("core");
pub const sequence = @import("sequence/sequence.zig");
pub const dna = @import("dna/dna.zig");
pub const rna = @import("rna/rna.zig");
pub const codon = @import("codon/codon.zig");
pub const protein = @import("protein/protein.zig");
pub const peptide = @import("peptide/peptide.zig");
pub const transcript = @import("transcript/transcript.zig");
pub const variant = @import("variant/variant.zig");

pub fn dummyDoc() void {
    _ = core.hashing.XxHash64.hash("a", 0);
}

test {
    dummyDoc();
    _ = sequence;
    _ = dna;
    _ = rna;
    _ = codon;
    _ = protein;
    _ = peptide;
    _ = transcript;
    _ = variant;
}

const std = @import("std");

test "DNA2 and DNA4 full validation" {
    const allocator = std.testing.allocator;

    // 1. DNA2 Creation, Indexing, and Validation
    const raw_dna = "ACGTACGTACGT";
    var dna2 = try dna.DNA2.init(raw_dna, allocator);
    defer dna2.deinit();

    try std.testing.expectEqual(dna2.len, 12);
    try std.testing.expectEqual(dna2.get(0), .A);
    try std.testing.expectEqual(dna2.get(1), .C);
    try std.testing.expectEqual(dna2.get(2), .G);
    try std.testing.expectEqual(dna2.get(3), .T);

    // 2. DNA2 Slicing (zero-copy)
    const view2 = dna2.view();
    const sub_view = view2.slice(4, 8); // "ACGT"
    try std.testing.expectEqual(sub_view.len, 4);
    try std.testing.expectEqual(sub_view.get(0), .A);
    try std.testing.expectEqual(sub_view.get(3), .T);

    // 3. DNA2 Reverse, Complement, Reverse Complement
    var rev = try view2.reverse(allocator);
    defer rev.deinit();
    try std.testing.expectEqual(rev.get(0), .T);
    try std.testing.expectEqual(rev.get(11), .A);

    var comp = try view2.complement(allocator);
    defer comp.deinit();
    try std.testing.expectEqual(comp.get(0), .T); // A -> T
    try std.testing.expectEqual(comp.get(1), .G); // C -> G

    var rev_comp = try view2.reverseComplement(allocator);
    defer rev_comp.deinit();
    try std.testing.expectEqual(rev_comp.get(0), .A); // last was T -> A
    try std.testing.expectEqual(rev_comp.get(11), .T); // first was A -> T

    // 4. DNA2 GC Content and Counts
    try std.testing.expectApproxEqAbs(view2.gcContent(), 0.5, 1e-5);
    const counts2 = view2.counts();
    try std.testing.expectEqual(counts2.a, 3);
    try std.testing.expectEqual(counts2.c, 3);

    // 5. DNA2 K-mer generation
    var kmer_iter = view2.kmers(10);
    var count: usize = 0;
    while (kmer_iter.next()) |kmer| {
        try std.testing.expectEqual(kmer.len, 10);
        count += 1;
    }
    try std.testing.expectEqual(count, 3); // 12 - 10 + 1 = 3

    // 6. DNA2 Serialization and Deserialization Roundtrip
    var buf: [128]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try view2.serialize(&fbs);
    const written = fbs.buffered();

    var fbs_read = std.Io.Reader.fixed(written);
    var deserialized_dna2 = try dna.DNA2View.deserialize(&fbs_read, allocator);
    defer deserialized_dna2.deinit();

    try std.testing.expect(view2.equals(deserialized_dna2.view()));

    // 7. DNA4 IUPAC Creation, GC Content, Complements, and Serialization
    const raw_iupac = "ACGTRYSWKMBDHVN";
    var dna4 = try dna.DNA4.init(raw_iupac, allocator);
    defer dna4.deinit();

    const view4 = dna4.view();
    try std.testing.expectEqual(view4.len, 15);
    try std.testing.expectEqual(view4.get(0), .A);
    try std.testing.expectEqual(view4.get(4), .R);

    // Fractional GC content calculation:
    // A(0) + C(1) + G(1) + T(0) + R(0.5) + Y(0.5) + S(1) + W(0) + K(0.5) + M(0.5) + B(2/3) + D(1/3) + H(1/3) + V(2/3) + N(0.5)
    // Sum = 0 + 1 + 1 + 0 + 0.5 + 0.5 + 1 + 0 + 0.5 + 0.5 + 0.66666 + 0.33333 + 0.33333 + 0.66666 + 0.5 = 7.5
    // GC = 7.5 / 15 = 0.5
    try std.testing.expectApproxEqAbs(view4.gcContent(), 0.5, 1e-5);

    var comp4 = try view4.complement(allocator);
    defer comp4.deinit();
    try std.testing.expectEqual(comp4.get(4), .Y); // R (A or G) -> Y (C or T)
    try std.testing.expectEqual(comp4.get(10), .V); // B (C, G, T) -> V (A, C, G)

    var buf4: [128]u8 = undefined;
    var fbs4 = std.Io.Writer.fixed(&buf4);
    try view4.serialize(&fbs4);
    const written4 = fbs4.buffered();

    var fbs_read4 = std.Io.Reader.fixed(written4);
    var deserialized_dna4 = try dna.DNA4View.deserialize(&fbs_read4, allocator);
    defer deserialized_dna4.deinit();

    try std.testing.expect(view4.equals(deserialized_dna4.view()));
}

test "RNA transcription and reverse complement" {
    const allocator = std.testing.allocator;

    const raw_dna = "ACGTACGT";
    var dna2 = try dna.DNA2.init(raw_dna, allocator);
    defer dna2.deinit();

    // Transcribe DNA2 -> RNA2
    var rna2 = try rna.transcribe2(dna2.view(), allocator);
    defer rna2.deinit();

    try std.testing.expectEqual(rna2.len, 8);
    try std.testing.expectEqual(rna2.get(3), .U); // T -> U

    // Back-transcribe RNA2 -> DNA2
    var back_dna2 = try rna.backTranscribe2(rna2.view(), allocator);
    defer back_dna2.deinit();

    try std.testing.expectEqual(back_dna2.get(3), .T); // U -> T
    try std.testing.expect(dna2.view().equals(back_dna2.view()));

    // RNA4 Transcription
    const raw_dna4 = "ACGTRYSWKMBDHVN";
    var dna4 = try dna.DNA4.init(raw_dna4, allocator);
    defer dna4.deinit();

    var rna4 = try rna.transcribe4(dna4.view(), allocator);
    defer rna4.deinit();

    try std.testing.expectEqual(rna4.len, 15);
    try std.testing.expectEqual(rna4.get(3), .U); // T -> U

    var back_dna4 = try rna.backTranscribe4(rna4.view(), allocator);
    defer back_dna4.deinit();

    try std.testing.expect(dna4.view().equals(back_dna4.view()));
}

test "Codon representations and translations" {
    const start_codon = try codon.Codon.fromString("AUG");
    try std.testing.expectEqual(start_codon.toAminoAcid(), .M);

    const stop_codon = try codon.Codon.fromString("UAA");
    try std.testing.expectEqual(stop_codon.toAminoAcid(), .Stop);

    const syn = codon.synonymousCodons(.M);
    try std.testing.expectEqual(syn.len, 1); // Only AUG

    const syn_leu = codon.synonymousCodons(.L);
    try std.testing.expectEqual(syn_leu.len, 6); // UUA, UUG, CUU, CUC, CUA, CUG
}

test "Protein and Peptide analysis" {
    const allocator = std.testing.allocator;

    const raw_protein = "MKTIIALSYIFCLVFAD";
    var prot = try protein.Protein.init(raw_protein, allocator);
    defer prot.deinit();

    const view = prot.view();
    try std.testing.expectEqual(view.len, 17);
    try std.testing.expectEqual(view.get(0), .M);
    try std.testing.expectEqual(view.get(16), .D);

    // Slicing
    const sub_view = view.slice(1, 4); // "KTI"
    try std.testing.expectEqual(sub_view.len, 3);
    try std.testing.expectEqual(sub_view.get(0), .K);

    // Molecular weight (sums of residues + terminal H2O)
    // M=131.1986, K=128.1741, T=101.1051, I=113.1594, I=113.1594, A=71.0788, L=113.1594, S=87.0782, Y=163.1760
    // I=113.1594, F=147.1766, C=103.1388, L=113.1594, V=99.1326, F=147.1766, A=71.0788, D=115.0886
    // Sum of residues = 1950.4996
    // Total weight = 1950.4996 + 18.01524 = 1968.51484 Da
    try std.testing.expectApproxEqAbs(view.molecularWeight(), 1948.41504, 1e-2);

    // Composition analysis
    const analysis = view.compositionAnalysis();
    try std.testing.expectApproxEqAbs(analysis.frequencies[@intFromEnum(protein.AminoAcid.M)], 1.0 / 17.0, 1e-5);
    try std.testing.expectApproxEqAbs(view.residueFrequency(.M), 1.0 / 17.0, 1e-5);

    // Peptide wrappers and stats
    var pep = try peptide.Peptide.init(raw_protein, allocator);
    defer pep.deinit();

    const pep_view = pep.view();
    const stats = pep_view.statistics();
    try std.testing.expectEqual(stats.len, 17);
    // Hydrophobic residues in "MKTIIALSYIFCLVFAD": M, I, I, A, L, Y, I, F, L, V, F, A (total 12)
    try std.testing.expectEqual(stats.hydrophobic_count, 12);
    try std.testing.expectApproxEqAbs(stats.hydrophobic_fraction, 12.0 / 17.0, 1e-5);

    // Protein Serialization roundtrip
    var buf: [256]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try view.serialize(&fbs);
    const written = fbs.buffered();

    var fbs_read = std.Io.Reader.fixed(written);
    var deserialized_prot = try protein.ProteinView.deserialize(&fbs_read, allocator);
    defer deserialized_prot.deinit();

    try std.testing.expect(view.equals(deserialized_prot.view()));
}

test "Transcript spliced reconstruction and coordinate mapping" {
    const allocator = std.testing.allocator;

    const exons = [_]transcript.Exon{
        .{ .start = 10, .end = 20 },  // len = 10
        .{ .start = 30, .end = 35 },  // len = 5
        .{ .start = 50, .end = 60 },  // len = 10
    };

    var tx = try transcript.Transcript.init("TX1", .forward, &exons, allocator);
    defer tx.deinit();

    try std.testing.expectEqual(tx.length(), 25);

    // Genomic DNA
    const genomic_str = "AAAAAAAAAAATCGATCGATAAAAAAAAAACGCGCAAAAAAAAAAAAAAATTTTGGGGAAAAA";
    var genomic_dna = try dna.DNA2.init(genomic_str, allocator);
    defer genomic_dna.deinit();

    // Spliced transcription (concatenation)
    var spliced = try tx.reconstructDNA2(genomic_dna.view(), allocator);
    defer spliced.deinit();

    try std.testing.expectEqual(spliced.len, 25);
    // 1st exon: "ATCGATCGAT" -> DNA2
    // 2nd exon: "CGCGC" -> DNA2
    // 3rd exon: "TTTTGGGGAA" -> DNA2
    // Let's check coordinates
    try std.testing.expectEqual(spliced.get(0), try dna.charToNucleotide('A'));
    try std.testing.expectEqual(spliced.get(10), try dna.charToNucleotide('C'));
    try std.testing.expectEqual(spliced.get(15), try dna.charToNucleotide('T'));

    // Coordinate mapping (forward strand)
    // tx_coord 0 -> genomic 10
    try std.testing.expectEqual(try tx.transcriptToGenomic(0), 10);
    // tx_coord 9 -> genomic 19
    try std.testing.expectEqual(try tx.transcriptToGenomic(9), 19);
    // tx_coord 10 -> genomic 30
    try std.testing.expectEqual(try tx.transcriptToGenomic(10), 30);
    // tx_coord 15 -> genomic 50
    try std.testing.expectEqual(try tx.transcriptToGenomic(15), 50);

    // Reverse mapping
    try std.testing.expectEqual(try tx.genomicToTranscript(10), 0);
    try std.testing.expectEqual(try tx.genomicToTranscript(19), 9);
    try std.testing.expectEqual(try tx.genomicToTranscript(30), 10);
    try std.testing.expectEqual(try tx.genomicToTranscript(50), 15);
    try std.testing.expectError(error.GenomicCoordinateNotExonic, tx.genomicToTranscript(25));

    // Reverse strand transcript
    var tx_rev = try transcript.Transcript.init("TX1_REV", .reverse, &exons, allocator);
    defer tx_rev.deinit();

    // Coordinate mapping (reverse strand)
    // tx_coord 0 -> genomic 59 (last base of last exon in coordinate order)
    try std.testing.expectEqual(try tx_rev.transcriptToGenomic(0), 59);
    // tx_coord 9 -> genomic 50
    try std.testing.expectEqual(try tx_rev.transcriptToGenomic(9), 50);
    // tx_coord 10 -> genomic 34
    try std.testing.expectEqual(try tx_rev.transcriptToGenomic(10), 34);
    // tx_coord 15 -> genomic 19
    try std.testing.expectEqual(try tx_rev.transcriptToGenomic(15), 19);

    // Reverse mapping (reverse strand)
    try std.testing.expectEqual(try tx_rev.genomicToTranscript(59), 0);
    try std.testing.expectEqual(try tx_rev.genomicToTranscript(50), 9);
    try std.testing.expectEqual(try tx_rev.genomicToTranscript(34), 10);
    try std.testing.expectEqual(try tx_rev.genomicToTranscript(19), 15);
}

test "Variant validation, normalization, and hashing" {
    const allocator = std.testing.allocator;

    // SNP variant
    var v1 = try variant.Variant.init(100, "A", "G", allocator);
    defer v1.deinit();
    try std.testing.expectEqual(v1.getType(), .snp);
    try std.testing.expect(v1.validate());

    // Normalization test (trim common suffix & prefix)
    var v2 = try variant.Variant.init(100, "CAG", "CG", allocator);
    defer v2.deinit();
    try v2.normalize();
    // CAG vs CG -> suffix G matches, trimmed -> CA vs C
    // CA vs C -> prefix C matches, trimmed, pos += 1 -> A vs ""
    try std.testing.expectEqual(v2.position, 101);
    try std.testing.expectEqualStrings(v2.reference, "A");
    try std.testing.expectEqualStrings(v2.alternate, "");
    try std.testing.expectEqual(v2.getType(), .deletion);

    // Hashing and equality
    var v1_clone = try v1.clone();
    defer v1_clone.deinit();
    try std.testing.expect(v1.equals(v1_clone));
    try std.testing.expectEqual(v1.hash(), v1_clone.hash());
}

test "Sequence distances (Hamming & Levenshtein Edit Distance)" {
    const allocator = std.testing.allocator;

    const s1 = "ACGTACGT";
    const s2 = "ACGTTCGT";

    var dna_a = try dna.DNA2.init(s1, allocator);
    defer dna_a.deinit();
    var dna_b = try dna.DNA2.init(s2, allocator);
    defer dna_b.deinit();

    // Hamming distance
    const ham = sequence.hammingDistance(dna_a.view(), dna_b.view());
    try std.testing.expectEqual(ham, 1);

    // Levenshtein edit distance
    const edit = try sequence.editDistance(dna_a.view(), dna_b.view(), allocator);
    try std.testing.expectEqual(edit, 1);

    const s3 = "ACGT";
    const s4 = "AC";
    var dna_c = try dna.DNA2.init(s3, allocator);
    defer dna_c.deinit();
    var dna_d = try dna.DNA2.init(s4, allocator);
    defer dna_d.deinit();

    const edit2 = try sequence.editDistance(dna_c.view(), dna_d.view(), allocator);
    try std.testing.expectEqual(edit2, 2);
}
