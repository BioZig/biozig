const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const vcf = ingestion.genomics.vcf;

// ─── Happy Path ───────────────────────────────────────────────────────────────

test "vcf: single valid SNP record" {
    const data = "chr1\t1000\trs123\tA\tT\t.\t.\t.\n";
    var it = vcf.VcfIterator.init(data);
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
    try testing.expectEqual(@as(usize, 1000), rec.pos);
    try testing.expectEqualStrings("A", rec.ref);
    try testing.expectEqualStrings("T", rec.alt);
}

test "vcf: multiple ALT alleles expand to separate records" {
    const data = "chr1\t1000\t.\tA\tT,C\t.\t.\t.\n";
    var it = vcf.VcfIterator.init(data);
    const r1 = (try it.next()).?;
    try testing.expectEqualStrings("T", r1.alt);
    const r2 = (try it.next()).?;
    try testing.expectEqualStrings("C", r2.alt);
    try testing.expectEqual(@as(?vcf.VcfRecord, null), try it.next());
}

test "vcf: header comment lines are skipped" {
    const data = "##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\nchr1\t100\t.\tG\tA\t.\t.\t.\n";
    var it = vcf.VcfIterator.init(data);
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
}

test "vcf: empty lines between records are skipped" {
    const data = "chr1\t100\t.\tG\tA\t.\t.\t.\n\n\nchr2\t200\t.\tT\tC\t.\t.\t.\n";
    var it = vcf.VcfIterator.init(data);
    _ = try it.next();
    const r2 = (try it.next()).?;
    try testing.expectEqualStrings("chr2", r2.chrom);
}

// ─── Empty / EOF ──────────────────────────────────────────────────────────────

test "vcf: empty buffer" {
    var it = vcf.VcfIterator.init("");
    try testing.expectEqual(@as(?vcf.VcfRecord, null), try it.next());
}

test "vcf: only comment lines" {
    var it = vcf.VcfIterator.init("##fileformat=VCFv4.2\n##INFO=<ID=DP,Number=1>\n");
    try testing.expectEqual(@as(?vcf.VcfRecord, null), try it.next());
}

// ─── Missing Fields ───────────────────────────────────────────────────────────

test "vcf: missing CHROM field" {
    var it = vcf.VcfIterator.init("\t1000\t.\tA\tT\t.\t.\t.\n");
    // CHROM is empty string not missing - should return VcfMissingChrom or process
    // The parser calls fields.next() which will return "" for empty tab
    const rec = try it.next();
    // chrom will be empty string, which the parser allows through (no error check on empty chrom in iterator)
    // This documents current behavior: the iterator does not validate chrom emptiness, VcfRecord has no validate()
    _ = rec;
}

test "vcf: missing POS field (only 1 tab-field)" {
    var it = vcf.VcfIterator.init("chr1\n");
    try testing.expectError(error.VcfMissingPos, it.next());
}

test "vcf: missing REF field" {
    var it = vcf.VcfIterator.init("chr1\t100\t.\n");
    try testing.expectError(error.VcfMissingRef, it.next());
}

test "vcf: missing ALT field" {
    var it = vcf.VcfIterator.init("chr1\t100\t.\tA\n");
    try testing.expectError(error.VcfMissingAlt, it.next());
}

// ─── Invalid Field Values ─────────────────────────────────────────────────────

test "vcf: POS = 0 is invalid (VCF spec: 1-based)" {
    var it = vcf.VcfIterator.init("chr1\t0\t.\tA\tT\t.\t.\t.\n");
    try testing.expectError(error.InvalidVcfPosition, it.next());
}

test "vcf: non-numeric POS" {
    var it = vcf.VcfIterator.init("chr1\tABC\t.\tA\tT\t.\t.\t.\n");
    try testing.expectError(error.InvalidCharacter, it.next());
}

test "vcf: invalid REF allele (number in ref)" {
    var it = vcf.VcfIterator.init("chr1\t100\t.\t1A\tT\t.\t.\t.\n");
    try testing.expectError(error.InvalidRefAllele, it.next());
}

test "vcf: invalid ALT allele (punctuation)" {
    var it = vcf.VcfIterator.init("chr1\t100\t.\tA\tT!\t.\t.\t.\n");
    try testing.expectError(error.InvalidAltAllele, it.next());
}

test "vcf: empty ALT allele in multi-alt (trailing comma)" {
    // "T," means second alt is empty
    var it = vcf.VcfIterator.init("chr1\t100\t.\tA\tT,\t.\t.\t.\n");
    _ = try it.next(); // consume T
    try testing.expectError(error.InvalidAltAllele, it.next());
}

// ─── Serialize ────────────────────────────────────────────────────────────────

test "vcf: serialize empty chrom rejected" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = vcf.VcfRecord{ .chrom = "", .pos = 100, .id = ".", .ref = "A", .alt = "T" };
    try testing.expectError(error.EmptyChrom, vcf.serialize(&aw.writer, rec));
}

test "vcf: serialize valid record format" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = vcf.VcfRecord{ .chrom = "chr1", .pos = 1000, .id = "rs1", .ref = "A", .alt = "T" };
    try vcf.serialize(&aw.writer, rec);
    try testing.expect(std.mem.startsWith(u8, aw.written(), "chr1\t1000\trs1\tA\tT\t"));
}
