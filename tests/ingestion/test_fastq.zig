const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const fastq = ingestion.genomics.fastq;

// ─── Happy Path ───────────────────────────────────────────────────────────────

test "fastq: single valid record" {
    var it = fastq.FastqIterator.init("@read1\nACGT\n+\n!!!!\n");
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("read1", rec.header);
    try testing.expectEqualStrings("ACGT", rec.sequence);
    try testing.expectEqualStrings("!!!!", rec.quality);
}

test "fastq: multiple records parsed in sequence" {
    const data = "@r1\nACGT\n+\n!!!!\n@r2\nTTTT\n+\nIIII\n";
    var it = fastq.FastqIterator.init(data);
    const r1 = (try it.next()).?;
    try testing.expectEqualStrings("r1", r1.header);
    const r2 = (try it.next()).?;
    try testing.expectEqualStrings("r2", r2.header);
    try testing.expectEqual(@as(?fastq.FastqRecord, null), try it.next());
}

test "fastq: windows line endings (CRLF)" {
    var it = fastq.FastqIterator.init("@r1\r\nACGT\r\n+\r\n!!!!\r\n");
    const rec = (try it.next()).?;
    try testing.expectEqualStrings("r1", rec.header);
    try testing.expectEqualStrings("ACGT", rec.sequence);
}

// ─── Empty / EOF ──────────────────────────────────────────────────────────────

test "fastq: empty buffer" {
    var it = fastq.FastqIterator.init("");
    try testing.expectEqual(@as(?fastq.FastqRecord, null), try it.next());
}

test "fastq: blank lines only" {
    var it = fastq.FastqIterator.init("\n\n\n\n");
    try testing.expectEqual(@as(?fastq.FastqRecord, null), try it.next());
}

// ─── Structural / Malformed ───────────────────────────────────────────────────

test "fastq: missing @ header marker" {
    var it = fastq.FastqIterator.init("read1\nACGT\n+\n!!!!\n");
    try testing.expectError(error.MalformedFastqHeaderMissing, it.next());
}

test "fastq: empty sequence line" {
    var it = fastq.FastqIterator.init("@r1\n\n+\n!!!!\n");
    try testing.expectError(error.MalformedFastqEmptySequence, it.next());
}

test "fastq: missing + separator line" {
    var it = fastq.FastqIterator.init("@r1\nACGT\nACGT\n!!!!\n");
    try testing.expectError(error.MalformedFastqPlusLineMissing, it.next());
}

// ─── Validation: Sequence / Quality Mismatch ─────────────────────────────────

test "fastq: quality string shorter than sequence" {
    var it = fastq.FastqIterator.init("@r1\nACGTACGT\n+\n!!!!\n");
    try testing.expectError(error.SequenceQualityLengthMismatch, it.next());
}

test "fastq: quality string longer than sequence" {
    var it = fastq.FastqIterator.init("@r1\nACGT\n+\n!!!!IIII\n");
    try testing.expectError(error.SequenceQualityLengthMismatch, it.next());
}

// ─── Sequence / Quality Character Bounds ─────────────────────────────────────

test "fastq: invalid sequence character (digit)" {
    var it = fastq.FastqIterator.init("@r1\nACGT1234\n+\n!!!!!!!!\n");
    try testing.expectError(error.InvalidSequenceCharacter, it.next());
}

test "fastq: invalid sequence character (null byte)" {
    var it = fastq.FastqIterator.init("@r1\nACGT\x00CGT\n+\n!!!!!!!!\n");
    try testing.expectError(error.InvalidSequenceCharacter, it.next());
}

test "fastq: quality score below ASCII 33 (space)" {
    var it = fastq.FastqIterator.init("@r1\nACGT\n+\n!!! \n");
    try testing.expectError(error.InvalidQualityScoreCharacter, it.next());
}

test "fastq: quality score above ASCII 126 (DEL)" {
    var it = fastq.FastqIterator.init("@r1\nACGT\n+\n!!!\x7f\n");
    try testing.expectError(error.InvalidQualityScoreCharacter, it.next());
}

// ─── Serialize ────────────────────────────────────────────────────────────────

test "fastq: serialize empty header" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = fastq.FastqRecord{ .header = "", .sequence = "ACGT", .quality = "!!!!" };
    try testing.expectError(error.EmptyHeader, fastq.serialize(&aw.writer, rec));
}

test "fastq: serialize mismatched seq/qual length" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = fastq.FastqRecord{ .header = "r1", .sequence = "ACGT", .quality = "!!" };
    try testing.expectError(error.SequenceQualityLengthMismatch, fastq.serialize(&aw.writer, rec));
}

test "fastq: serialize valid record round-trips correctly" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    const rec = fastq.FastqRecord{ .header = "read1", .sequence = "ACGT", .quality = "!!!!" };
    try fastq.serialize(&aw.writer, rec);
    try testing.expectEqualStrings("@read1\nACGT\n+\n!!!!\n", aw.written());
}
