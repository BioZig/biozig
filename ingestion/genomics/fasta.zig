const std = @import("std");
const molecular = @import("molecular");
const dna = molecular.dna;
const rna = molecular.rna;
const protein = molecular.protein;

pub const FastaRecord = struct {
    header: []const u8,
    sequence: []const u8, // Contains raw sequence lines, potentially with newlines

    /// Returns a new dynamically allocated slice with newlines removed.
    /// The caller is responsible for freeing it.
    pub fn cleanSequence(self: FastaRecord, allocator: std.mem.Allocator) ![]u8 {
        var clean = try std.ArrayList(u8).initCapacity(allocator, self.sequence.len);
        defer clean.deinit(allocator);
        for (self.sequence) |c| {
            if (c != '\n' and c != '\r') {
                clean.appendAssumeCapacity(c);
            }
        }
        return clean.toOwnedSlice(allocator);
    }
};

/// Streaming zero-copy FASTA Iterator
pub const FastaIterator = struct {
    buffer: []const u8,
    pos: usize,
    peek_header: ?[]const u8 = null,

    pub fn init(buffer: []const u8) FastaIterator {
        return .{
            .buffer = buffer,
            .pos = 0,
        };
    }

    pub fn next(self: *FastaIterator) !?FastaRecord {
        var header: []const u8 = "";

        if (self.peek_header) |h| {
            header = h;
            self.peek_header = null;
        } else {
            // Read until we find a header starting with '>'
            while (self.pos < self.buffer.len) {
                const end_idx = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
                const line = std.mem.trimEnd(u8, self.buffer[self.pos..end_idx], "\r");
                self.pos = end_idx;
                if (self.pos < self.buffer.len) self.pos += 1;

                if (line.len == 0) continue;
                if (line[0] == '>') {
                    header = line[1..];
                    break;
                } else {
                    return error.MalformedFastaHeaderMissing;
                }
            }
            if (self.pos >= self.buffer.len and header.len == 0) return null;
        }

        const seq_start = self.pos;
        var seq_end = seq_start;

        while (self.pos < self.buffer.len) {
            const end_idx = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const line = std.mem.trimEnd(u8, self.buffer[self.pos..end_idx], "\r");
            const next_pos = end_idx + (if (end_idx < self.buffer.len) @as(usize, 1) else 0);

            if (line.len == 0) {
                self.pos = next_pos;
                continue;
            }
            if (line[0] == '>') {
                self.peek_header = line[1..];
                self.pos = next_pos;
                break;
            }

            for (line) |c| {
                if (!std.ascii.isAlphabetic(c) and c != '*' and c != '-') {
                    return error.InvalidSequenceCharacter;
                }
            }

            seq_end = next_pos;
            self.pos = next_pos;
        }

        if (seq_start == seq_end) {
            return error.MalformedFastaEmptySequence;
        }

        return FastaRecord{
            .header = header,
            .sequence = std.mem.trimEnd(u8, self.buffer[seq_start..seq_end], "\r\n"),
        };
    }
};

/// Helper constructor for FastaIterator
pub fn fastaIterator(buffer: []const u8) FastaIterator {
    return FastaIterator.init(buffer);
}

/// Serializes FASTA format
pub fn serialize(writer: anytype, header: []const u8, sequence: []const u8) !void {
    if (header.len == 0) return error.EmptyHeader;
    if (sequence.len == 0) return error.EmptySequence;
    try writer.print(">{s}\n", .{header});
    var i: usize = 0;
    while (i < sequence.len) : (i += 80) {
        const end = @min(i + 80, sequence.len);
        try writer.print("{s}\n", .{sequence[i..end]});
    }
}

test "benchmark zero-copy FASTA iterator" {
    const test_data =
        ">seq1\nACGT\nACGT\n" ** 5000;

    var it = FastaIterator.init(test_data);
    var count: usize = 0;
    while (try it.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 5000), count);
}
