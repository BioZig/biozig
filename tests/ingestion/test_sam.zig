const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const sam = ingestion.genomics.sam;

const SliceReader = struct {
    buffer: []const u8,
    pos: usize = 0,
    pub fn readByte(self: *@This()) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const b = self.buffer[self.pos];
        self.pos += 1;
        return b;
    }
};

// ─── Happy Path ───────────────────────────────────────────────────────────────

test "sam: single valid record" {
    const data = "read1\t0\tchr1\t100\t60\t4M\t*\t0\t0\tACGT\t!!!!\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqualStrings("read1", rec.qname);
    try testing.expectEqual(@as(u16, 0), rec.flag);
    try testing.expectEqualStrings("chr1", rec.rname);
    try testing.expectEqual(@as(usize, 100), rec.pos);
    try testing.expectEqualStrings("4M", rec.cigar);
    try testing.expectEqualStrings("ACGT", rec.seq);
}

test "sam: header @ lines are skipped" {
    const data = "@HD\tVN:1.6\n@SQ\tSN:chr1\tLN:248956422\nread1\t0\tchr1\t1\t60\t4M\t*\t0\t0\tACGT\t!!!!\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqualStrings("read1", rec.qname);
}

test "sam: quality wildcard (*) is accepted" {
    const data = "read1\t0\tchr1\t100\t60\t4M\t*\t0\t0\tACGT\t*\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqualStrings("*", rec.qual);
}

test "sam: empty file" {
    const data = "";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectEqual(@as(?sam.SamRecord, null), try it.next());
}

test "sam: only header lines, no records" {
    const data = "@HD\tVN:1.6\n@SQ\tSN:chr1\tLN:248956422\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectEqual(@as(?sam.SamRecord, null), try it.next());
}

// ─── Missing Fields ───────────────────────────────────────────────────────────

test "sam: missing RNAME (truncated at FLAG)" {
    const data = "read1\t0\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.SamMissingRname, it.next());
}

test "sam: missing CIGAR field" {
    const data = "read1\t0\tchr1\t100\t60\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.SamMissingCigar, it.next());
}

test "sam: missing SEQ field" {
    const data = "read1\t0\tchr1\t100\t60\t4M\t*\t0\t0\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.SamMissingSeq, it.next());
}

// ─── Invalid Field Values ─────────────────────────────────────────────────────

test "sam: non-numeric FLAG field" {
    const data = "read1\tXX\tchr1\t100\t60\t4M\t*\t0\t0\tACGT\t!!!!\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.InvalidCharacter, it.next());
}

test "sam: FLAG exceeds u16 max (65535)" {
    const data = "read1\t99999\tchr1\t100\t60\t4M\t*\t0\t0\tACGT\t!!!!\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.Overflow, it.next());
}

test "sam: MAPQ exceeds u8 max (255)" {
    const data = "read1\t0\tchr1\t100\t300\t4M\t*\t0\t0\tACGT\t!!!!\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.Overflow, it.next());
}

test "sam: seq/qual length mismatch" {
    const data = "read1\t0\tchr1\t100\t60\t4M\t*\t0\t0\tACGTACGT\t!!!!\n";
    var fbs = SliceReader{ .buffer = data };
    var it = sam.samIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.SeqQualLengthMismatch, it.next());
}

// ─── Validate ─────────────────────────────────────────────────────────────────

test "sam: validate empty qname" {
    const rec = sam.SamRecord{
        .qname = "",
        .flag = 0,
        .rname = "chr1",
        .pos = 1,
        .mapq = 60,
        .cigar = "4M",
        .rnext = "*",
        .pnext = 0,
        .tlen = 0,
        .seq = "ACGT",
        .qual = "!!!!",
        .allocator = testing.allocator,
    };
    try testing.expectError(error.EmptyQName, rec.validate());
}

test "sam: validate empty cigar" {
    const rec = sam.SamRecord{
        .qname = "read1",
        .flag = 0,
        .rname = "chr1",
        .pos = 1,
        .mapq = 60,
        .cigar = "",
        .rnext = "*",
        .pnext = 0,
        .tlen = 0,
        .seq = "ACGT",
        .qual = "!!!!",
        .allocator = testing.allocator,
    };
    try testing.expectError(error.EmptyCigar, rec.validate());
}
