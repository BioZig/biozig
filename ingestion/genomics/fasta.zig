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

pub const FastaStreamState = enum {
    init,
    header,
    sequence,
    eof,
};

pub fn FastaStreamIterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        buffer: []u8,
        pos: usize = 0,
        valid_len: usize = 0,
        eof: bool = false,
        state: FastaStreamState = .init,
        
        const Self = @This();

        pub fn init(reader: ReaderType, buffer: []u8) Self {
            return .{
                .reader = reader,
                .buffer = buffer,
            };
        }

        fn fill(self: *Self) !void {
            if (self.eof) return;
            if (self.pos > 0 and self.valid_len > self.pos) {
                std.mem.copyForwards(u8, self.buffer[0 .. self.valid_len - self.pos], self.buffer[self.pos .. self.valid_len]);
                self.valid_len -= self.pos;
            } else if (self.pos == self.valid_len) {
                self.valid_len = 0;
            }
            self.pos = 0;
            var data: [1][]u8 = .{ self.buffer[self.valid_len..] };
            const read_len = self.reader.readVec(&data) catch |err| switch (err) {
                error.EndOfStream => @as(usize, 0),
                else => return err,
            };
            if (read_len == 0) {
                self.eof = true;
            }
            self.valid_len += read_len;
        }

        pub fn nextHeader(self: *Self, header_buf: []u8) !?[]const u8 {
            while (true) {
                if (self.pos == self.valid_len) {
                    if (self.eof) return null;
                    try self.fill();
                    if (self.pos == self.valid_len) return null;
                }

                if (self.state != .header) {
                    const next_gt = std.mem.indexOfScalarPos(u8, self.buffer[0..self.valid_len], self.pos, '>');
                    if (next_gt) |idx| {
                        self.pos = idx;
                        self.state = .header;
                    } else {
                        self.pos = self.valid_len;
                        continue;
                    }
                }

                const nl = std.mem.indexOfScalarPos(u8, self.buffer[0..self.valid_len], self.pos, '\n');
                if (nl) |idx| {
                    const line = self.buffer[self.pos + 1 .. idx];
                    const trimmed = std.mem.trimEnd(u8, line, "\r");
                    const len_to_copy = @min(trimmed.len, header_buf.len);
                    std.mem.copyForwards(u8, header_buf[0..len_to_copy], trimmed[0..len_to_copy]);
                    self.pos = idx + 1;
                    self.state = .sequence;
                    return header_buf[0..len_to_copy];
                } else {
                    if (self.eof) {
                        const line = self.buffer[self.pos + 1 .. self.valid_len];
                        const trimmed = std.mem.trimEnd(u8, line, "\r");
                        const len_to_copy = @min(trimmed.len, header_buf.len);
                        std.mem.copyForwards(u8, header_buf[0..len_to_copy], trimmed[0..len_to_copy]);
                        self.pos = self.valid_len;
                        self.state = .eof;
                        return header_buf[0..len_to_copy];
                    }
                    if (self.pos == 0 and self.valid_len == self.buffer.len) {
                        return error.BufferTooSmallForHeader;
                    }
                    try self.fill();
                }
            }
        }

        pub fn nextSequenceChunk(self: *Self) !?[]const u8 {
            if (self.state != .sequence) return null;

            while (true) {
                if (self.pos == self.valid_len) {
                    if (self.eof) {
                        self.state = .eof;
                        return null;
                    }
                    try self.fill();
                    if (self.pos == self.valid_len) {
                        self.state = .eof;
                        return null;
                    }
                }

                if (self.buffer[self.pos] == '>') {
                    self.state = .header;
                    return null;
                }

                const next_nl = std.mem.indexOfScalarPos(u8, self.buffer[0..self.valid_len], self.pos, '\n');
                const next_gt = std.mem.indexOfScalarPos(u8, self.buffer[0..self.valid_len], self.pos, '>');

                const end_idx = if (next_nl) |nl| 
                    (if (next_gt) |gt| @min(nl, gt) else nl)
                else 
                    (if (next_gt) |gt| gt else self.valid_len);

                if (end_idx > self.pos) {
                    const chunk = self.buffer[self.pos..end_idx];
                    const trimmed = std.mem.trimEnd(u8, chunk, "\r");
                    self.pos = end_idx;
                    
                    for (trimmed) |c| {
                        if (!std.ascii.isAlphabetic(c) and c != '*' and c != '-') {
                            return error.InvalidSequenceCharacter;
                        }
                    }

                    if (trimmed.len > 0) return trimmed;
                    continue;
                } else if (next_nl) |nl| {
                    if (nl == self.pos) {
                        self.pos += 1;
                        continue;
                    }
                }
                
                if (end_idx == self.pos and next_gt != null and next_gt.? == self.pos) {
                    self.state = .header;
                    return null;
                }
            }
        }
    };
}

pub fn fastaStreamIterator(reader: anytype, buffer: []u8) FastaStreamIterator(@TypeOf(reader)) {
    return FastaStreamIterator(@TypeOf(reader)).init(reader, buffer);
}
