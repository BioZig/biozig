const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const gtf = ingestion.genomics.gtf;

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

test "gtf: single valid record, strand +" {
    const data = "chr1\tEnsembl\tgene\t1000\t5000\t.\t+\t.\tgene_id \"BRCA1\";\n";
    var fbs = SliceReader{ .buffer = data };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqualStrings("chr1", rec.seqname);
    try testing.expectEqual(@as(usize, 999), rec.start); // 1-based -> 0-based
    try testing.expectEqual(@as(usize, 4999), rec.end);
    try testing.expectEqual(@as(u8, '+'), rec.strand);
}

test "gtf: strand -" {
    const data = "chr1\tEnsembl\texon\t100\t200\t.\t-\t0\tgene_id \"X\";\n";
    var fbs = SliceReader{ .buffer = data };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqual(@as(u8, '-'), rec.strand);
}

test "gtf: score as dot yields null" {
    const data = "chr1\tEnsembl\tgene\t1\t100\t.\t+\t.\tattrs\n";
    var fbs = SliceReader{ .buffer = data };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqual(@as(?f64, null), rec.score);
}

test "gtf: numeric score field" {
    const data = "chr1\tEnsembl\tgene\t1\t100\t88.5\t+\t.\tattrs\n";
    var fbs = SliceReader{ .buffer = data };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqual(@as(?f64, 88.5), rec.score);
}

test "gtf: comment lines are skipped" {
    const data = "#!genome-build GRCh38\nchr1\tEnsembl\tgene\t1\t100\t.\t+\t.\tattrs\n";
    var fbs = SliceReader{ .buffer = data };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    const rec = (try it.next()).?;
    defer rec.deinit();
    try testing.expectEqualStrings("chr1", rec.seqname);
}

test "gtf: empty file" {
    var fbs = SliceReader{ .buffer = "" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectEqual(@as(?gtf.GtfRecord, null), try it.next());
}

// ─── Missing Fields ───────────────────────────────────────────────────────────

test "gtf: missing SOURCE" {
    var fbs = SliceReader{ .buffer = "chr1\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.GtfMissingSource, it.next());
}

test "gtf: missing FEATURE" {
    var fbs = SliceReader{ .buffer = "chr1\tsrc\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.GtfMissingFeature, it.next());
}

test "gtf: missing ATTRIBUTES" {
    var fbs = SliceReader{ .buffer = "chr1\tsrc\tgene\t1\t100\t.\t+\t.\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.GtfMissingAttributes, it.next());
}

// ─── Invalid Values ───────────────────────────────────────────────────────────

test "gtf: POS = 0 is invalid (GTF is 1-based)" {
    var fbs = SliceReader{ .buffer = "chr1\tsrc\tgene\t0\t100\t.\t+\t.\tattrs\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.InvalidGtfCoordinates, it.next());
}

test "gtf: start > end" {
    var fbs = SliceReader{ .buffer = "chr1\tsrc\tgene\t5000\t100\t.\t+\t.\tattrs\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.InvalidCoordinates, it.next());
}

test "gtf: invalid strand character" {
    var fbs = SliceReader{ .buffer = "chr1\tsrc\tgene\t1\t100\t.\tx\t.\tattrs\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.InvalidStrand, it.next());
}

test "gtf: non-numeric START" {
    var fbs = SliceReader{ .buffer = "chr1\tsrc\tgene\tABC\t100\t.\t+\t.\tattrs\n" };
    var it = gtf.gtfIterator(testing.allocator, &fbs);
    defer it.deinit();
    try testing.expectError(error.InvalidCharacter, it.next());
}
