const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const bed = ingestion.genomics.bed;

// ─── Happy Path ───────────────────────────────────────────────────────────────

test "bed: minimal BED3 record (chrom, start, end)" {
    var it = bed.BedIterator.init("chr1\t1000\t2000\n");
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
    try testing.expectEqual(@as(usize, 1000), rec.start);
    try testing.expectEqual(@as(usize, 2000), rec.end);
    try testing.expectEqual(@as(?[]const u8, null), rec.name);
}

test "bed: full BED6 record" {
    var it = bed.BedIterator.init("chr1\t1000\t2000\tgene1\t900\t+\n");
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("gene1", rec.name.?);
    try testing.expectEqual(@as(?u32, 900), rec.score);
    try testing.expectEqual(@as(?u8, '+'), rec.strand);
}

test "bed: space-delimited instead of tab-delimited" {
    var it = bed.BedIterator.init("chr1 1000 2000\n");
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
    try testing.expectEqual(@as(usize, 1000), rec.start);
}

test "bed: track and browser lines are skipped" {
    const data = "track name=\"test\"\nbrowser position chr1\nchr1\t100\t200\n";
    var it = bed.BedIterator.init(data);
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
}

test "bed: comment lines are skipped" {
    const data = "# this is a comment\nchr1\t100\t200\n";
    var it = bed.BedIterator.init(data);
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
}

test "bed: empty lines are skipped" {
    const data = "\n\nchr1\t100\t200\n";
    var it = bed.BedIterator.init(data);
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("chr1", rec.chrom);
}

test "bed: windows CRLF line endings" {
    var it = bed.BedIterator.init("chr1\t1000\t2000\r\n");
    const rec = (try it.next()).?;
    try testing.expectEqual(@as(usize, 2000), rec.end);
}

// ─── Empty / EOF ──────────────────────────────────────────────────────────────

test "bed: empty buffer" {
    var it = bed.BedIterator.init("");
    try testing.expectEqual(@as(?bed.BedRecord, null), try it.next());
}

test "bed: only blank lines" {
    var it = bed.BedIterator.init("\n\n\n");
    try testing.expectEqual(@as(?bed.BedRecord, null), try it.next());
}

// ─── Missing Fields ───────────────────────────────────────────────────────────

test "bed: missing START" {
    var it = bed.BedIterator.init("chr1\n");
    try testing.expectError(error.BedMissingStart, it.next());
}

test "bed: missing END" {
    var it = bed.BedIterator.init("chr1\t100\n");
    try testing.expectError(error.BedMissingEnd, it.next());
}

// ─── Invalid Field Values ─────────────────────────────────────────────────────

test "bed: start > end (inverted coordinates)" {
    var it = bed.BedIterator.init("chr1\t2000\t1000\n");
    try testing.expectError(error.InvalidCoordinates, it.next());
}

test "bed: score exceeds 1000" {
    var it = bed.BedIterator.init("chr1\t100\t200\tgene1\t9999\t+\n");
    try testing.expectError(error.InvalidScore, it.next());
}

test "bed: invalid strand character" {
    var it = bed.BedIterator.init("chr1\t100\t200\tgene1\t900\tx\n");
    try testing.expectError(error.InvalidStrand, it.next());
}

test "bed: non-numeric start" {
    var it = bed.BedIterator.init("chr1\tABC\t2000\n");
    try testing.expectError(error.InvalidCharacter, it.next());
}

test "bed: non-numeric end" {
    var it = bed.BedIterator.init("chr1\t1000\tXYZ\n");
    try testing.expectError(error.InvalidCharacter, it.next());
}

// ─── Multiple Records ─────────────────────────────────────────────────────────

test "bed: multiple records iterate correctly" {
    const data = "chr1\t100\t200\nchr2\t300\t400\nchr3\t500\t600\n";
    var it = bed.BedIterator.init(data);
    const r1 = (try it.next()).?;
    try testing.expectEqualStrings("chr1", r1.chrom);
    const r2 = (try it.next()).?;
    try testing.expectEqualStrings("chr2", r2.chrom);
    const r3 = (try it.next()).?;
    try testing.expectEqualStrings("chr3", r3.chrom);
    try testing.expectEqual(@as(?bed.BedRecord, null), try it.next());
}

// ─── Serialize ────────────────────────────────────────────────────────────────

test "bed: serialize BED3 minimal" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = bed.BedRecord{ .chrom = "chr1", .start = 100, .end = 200 };
    try bed.serialize(&aw.writer, rec);
    try testing.expectEqualStrings("chr1\t100\t200\n", aw.written());
}

test "bed: serialize empty chrom rejected" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = bed.BedRecord{ .chrom = "", .start = 100, .end = 200 };
    try testing.expectError(error.EmptyChrom, bed.serialize(&aw.writer, rec));
}

test "bed: serialize inverted coordinates rejected" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = bed.BedRecord{ .chrom = "chr1", .start = 500, .end = 100 };
    try testing.expectError(error.InvalidCoordinates, bed.serialize(&aw.writer, rec));
}
