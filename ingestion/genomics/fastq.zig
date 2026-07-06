const std = @import("std");

pub const FastqRecord = struct {
    header: []const u8,
    sequence: []const u8,
    quality: []const u8,

    pub fn validate(self: FastqRecord) !void {
        if (self.sequence.len != self.quality.len) {
            return error.SequenceQualityLengthMismatch;
        }
        for (self.sequence) |c| {
            if (!std.ascii.isAlphabetic(c) and c != '*') {
                return error.InvalidSequenceCharacter;
            }
        }
        for (self.quality) |q| {
            if (q < 33 or q > 126) {
                return error.InvalidQualityScoreCharacter;
            }
        }
    }
};

/// Streaming zero-copy FASTQ Iterator
pub const FastqIterator = struct {
    buffer: []const u8,
    pos: usize,

    pub fn init(buffer: []const u8) FastqIterator {
        return .{
            .buffer = buffer,
            .pos = 0,
        };
    }

    pub fn next(self: *FastqIterator) !?FastqRecord {
        while (self.pos < self.buffer.len) {
            // Software Prefetching: fetch ahead by 1 cache line (64 bytes) or 2 (128 bytes)
            const prefetch_pos = @min(self.pos + 256, self.buffer.len - 1);
            @prefetch(&self.buffer[prefetch_pos], .{ .rw = .read, .locality = 3, .cache = .data });

            // Line 1: Header
            const h_end = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const header_line = std.mem.trimEnd(u8, self.buffer[self.pos..h_end], "\r");
            self.pos = h_end;
            if (self.pos < self.buffer.len) self.pos += 1;

            if (header_line.len == 0) continue;
            if (header_line[0] != '@') return error.MalformedFastqHeaderMissing;
            const header = header_line[1..];

            // Line 2: Sequence
            const s_end = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const sequence = std.mem.trimEnd(u8, self.buffer[self.pos..s_end], "\r");
            self.pos = s_end;
            if (self.pos < self.buffer.len) self.pos += 1;

            if (sequence.len == 0) return error.MalformedFastqEmptySequence;

            // Line 3: +
            const p_end = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const plus_line = std.mem.trimEnd(u8, self.buffer[self.pos..p_end], "\r");
            self.pos = p_end;
            if (self.pos < self.buffer.len) self.pos += 1;

            if (plus_line.len == 0 or plus_line[0] != '+') return error.MalformedFastqPlusLineMissing;

            // Line 4: Quality
            const q_end = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const quality = std.mem.trimEnd(u8, self.buffer[self.pos..q_end], "\r");
            self.pos = q_end;
            if (self.pos < self.buffer.len) self.pos += 1;

            const rec = FastqRecord{
                .header = header,
                .sequence = sequence,
                .quality = quality,
            };

            try rec.validate();
            return rec;
        }
        return null;
    }
};

/// Helper constructor for FastqIterator
pub fn fastqIterator(buffer: []const u8) FastqIterator {
    return FastqIterator.init(buffer);
}

/// Serializes FASTQ format
pub fn serialize(writer: anytype, rec: FastqRecord) !void {
    if (rec.header.len == 0) return error.EmptyHeader;
    if (rec.sequence.len == 0) return error.EmptySequence;
    if (rec.sequence.len != rec.quality.len) return error.SequenceQualityLengthMismatch;
    try writer.print("@{s}\n{s}\n+\n{s}\n", .{ rec.header, rec.sequence, rec.quality });
}

test "benchmark zero-copy FASTQ iterator" {
    const test_data = 
        "@read1\nAGCT\n+\n!!!!\n" ** 10000;
    
    var it = FastqIterator.init(test_data);
    var count: usize = 0;
    while (try it.next()) |_| {
        count += 1;
    }
    
    try std.testing.expectEqual(@as(usize, 10000), count);
}
