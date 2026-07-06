const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const gff3 = ingestion.genomics.gff3;

const DummyReader = struct {
    buffer: []const u8,
    pos: usize = 0,
    pub fn readByte(self: *DummyReader) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const b = self.buffer[self.pos];
        self.pos += 1;
        return b;
    }
};

fn createReader(content: []const u8) DummyReader {
    return .{ .buffer = content };
}

test "gff3: empty file" {
    var reader = createReader("");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectEqual(@as(?gff3.Gff3Record, null), try it.next());
}

test "gff3: missing seqid" {
    var reader = createReader("\n");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectEqual(@as(?gff3.Gff3Record, null), try it.next());
}

test "gff3: missing source" {
    var reader = createReader("chr1");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.Gff3MissingSource, it.next());
}

test "gff3: missing feature type" {
    var reader = createReader("chr1\tSource");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.Gff3MissingFeatureType, it.next());
}

test "gff3: missing start" {
    var reader = createReader("chr1\tSource\tgene");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.Gff3MissingStart, it.next());
}

test "gff3: missing end" {
    var reader = createReader("chr1\tSource\tgene\t1000");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.Gff3MissingEnd, it.next());
}

test "gff3: invalid coordinates zero" {
    var reader = createReader("chr1\tSource\tgene\t0\t2000\t.\t+\t.\tID=1");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.InvalidGff3Coordinates, it.next());
}

test "gff3: start > end" {
    var reader = createReader("chr1\tSource\tgene\t2000\t1000\t.\t+\t.\tID=1");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.InvalidCoordinates, it.next());
}

test "gff3: invalid strand" {
    var reader = createReader("chr1\tSource\tgene\t1000\t2000\t.\tx\t.\tID=1");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.InvalidStrand, it.next());
}

test "gff3: invalid phase" {
    var reader = createReader("chr1\tSource\tgene\t1000\t2000\t.\t+\t3\tID=1");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    try testing.expectError(error.InvalidPhase, it.next());
}

test "gff3: success" {
    var reader = createReader("chr1\tSource\tgene\t1000\t2000\t.\t+\t.\tID=1");
    var it = gff3.gff3Iterator(testing.allocator, &reader);
    defer it.deinit();
    const rec = try it.next();
    defer rec.?.deinit();
    try testing.expect(rec != null);
    try testing.expectEqualStrings("chr1", rec.?.seqid);
    try testing.expectEqual(@as(usize, 999), rec.?.start); // 1-based to 0-based
}
