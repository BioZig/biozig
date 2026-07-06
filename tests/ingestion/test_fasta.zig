const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const fasta = ingestion.genomics.fasta;

test "fasta: empty file" {
    var it = fasta.FastaIterator.init("");
    try testing.expectEqual(@as(?fasta.FastaRecord, null), try it.next());
}

test "fasta: missing header" {
    var it = fasta.FastaIterator.init("ACGT\nACGT");
    try testing.expectError(error.MalformedFastaHeaderMissing, it.next());
}

test "fasta: empty sequence" {
    var it = fasta.FastaIterator.init(">seq1\n>seq2\nACGT");
    try testing.expectError(error.MalformedFastaEmptySequence, it.next());
}

test "fasta: invalid sequence character" {
    var it = fasta.FastaIterator.init(">seq1\nACGT!ACGT");
    try testing.expectError(error.InvalidSequenceCharacter, it.next());
}

test "fasta: null bytes in sequence" {
    var it = fasta.FastaIterator.init(">seq1\nACGT\x00ACGT");
    try testing.expectError(error.InvalidSequenceCharacter, it.next());
}

test "fasta: just > without header name" {
    var it = fasta.FastaIterator.init(">\nACGT");
    const rec = try it.next();
    try testing.expect(rec != null);
    try testing.expectEqualStrings("", rec.?.header);
}

test "fasta: blank lines inside sequence" {
    var it = fasta.FastaIterator.init(">seq1\nACGT\n\nACGT");
    const rec = try it.next();
    try testing.expect(rec != null);
    try testing.expectEqualStrings("seq1", rec.?.header);
    // sequence contains the blank line or is it parsed correctly?
    const clean = try rec.?.cleanSequence(testing.allocator);
    defer testing.allocator.free(clean);
    try testing.expectEqualStrings("ACGTACGT", clean);
}

test "fasta: windows line endings" {
    var it = fasta.FastaIterator.init(">seq1\r\nACGT\r\nACGT\r\n");
    const rec = try it.next();
    try testing.expect(rec != null);
    try testing.expectEqualStrings("seq1", rec.?.header);
    const clean = try rec.?.cleanSequence(testing.allocator);
    defer testing.allocator.free(clean);
    try testing.expectEqualStrings("ACGTACGT", clean);
}


