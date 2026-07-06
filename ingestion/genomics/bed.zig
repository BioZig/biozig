const std = @import("std");

pub const BedRecord = struct {
    chrom: []const u8,
    start: usize,
    end: usize,
    name: ?[]const u8 = null,
    score: ?u32 = null,
    strand: ?u8 = null,

    pub fn validate(self: BedRecord) !void {
        if (self.chrom.len == 0) return error.EmptyChrom;
        if (self.start > self.end) return error.InvalidCoordinates;
        if (self.score) |s| {
            if (s > 1000) return error.InvalidScore;
        }
        if (self.strand) |st| {
            if (st != '+' and st != '-' and st != '.') return error.InvalidStrand;
        }
    }
};

/// Streaming zero-copy BED Reader/Iterator
pub const BedIterator = struct {
    buffer: []const u8,
    pos: usize,

    pub fn init(buffer: []const u8) BedIterator {
        return .{
            .buffer = buffer,
            .pos = 0,
        };
    }

    pub fn next(self: *BedIterator) !?BedRecord {
        while (self.pos < self.buffer.len) {
            const end_idx = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const line = std.mem.trimEnd(u8, self.buffer[self.pos..end_idx], "\r");
            self.pos = end_idx + 1;

            if (line.len == 0) continue;
            if (line[0] == '#') continue; // skip comments
            if (std.mem.startsWith(u8, line, "track") or std.mem.startsWith(u8, line, "browser")) continue;

            var fields = std.mem.splitScalar(u8, line, '\t');
            if (std.mem.indexOfScalar(u8, line, '\t') == null) {
                fields = std.mem.splitScalar(u8, line, ' ');
            }

            const chrom = fields.next() orelse return error.BedMissingChrom;
            const start_str = fields.next() orelse return error.BedMissingStart;
            const end_str = fields.next() orelse return error.BedMissingEnd;

            var name: ?[]const u8 = null;
            var score: ?u32 = null;
            var strand: ?u8 = null;

            if (fields.next()) |n| {
                if (n.len > 0) name = n;
            }
            if (fields.next()) |s| {
                if (s.len > 0 and !std.mem.eql(u8, s, ".")) {
                    score = try std.fmt.parseInt(u32, s, 10);
                }
            }
            if (fields.next()) |st| {
                if (st.len > 0 and !std.mem.eql(u8, st, ".")) {
                    strand = st[0];
                }
            }

            const start = try std.fmt.parseInt(usize, start_str, 10);
            const end = try std.fmt.parseInt(usize, end_str, 10);

            const rec = BedRecord{
                .chrom = chrom,
                .start = start,
                .end = end,
                .name = name,
                .score = score,
                .strand = strand,
            };
            try rec.validate();
            return rec;
        }
        return null;
    }
};

/// Helper constructor for backward compatibility, although it takes a buffer now.
pub fn bedIterator(buffer: []const u8) BedIterator {
    return BedIterator.init(buffer);
}

/// Serializes BedRecord
pub fn serialize(writer: anytype, rec: BedRecord) !void {
    try rec.validate();
    try writer.print("{s}\t{}\t{}", .{ rec.chrom, rec.start, rec.end });
    if (rec.name) |n| {
        try writer.print("\t{s}", .{n});
        if (rec.score) |s| {
            try writer.print("\t{}", .{s});
            if (rec.strand) |st| {
                try writer.print("\t{c}", .{st});
            }
        }
    } else if (rec.score) |s| {
        try writer.print("\t.\t{}", .{s});
        if (rec.strand) |st| {
            try writer.print("\t{c}", .{st});
        }
    } else if (rec.strand) |st| {
        try writer.print("\t.\t.\t{c}", .{st});
    }
    try writer.writeAll("\n");
}

test "benchmark zero-copy BED iterator" {
    const test_data =
        "chr1\t1000\t2000\tfeature1\t100\t+\n" ** 10000;

    var it = BedIterator.init(test_data);
    var count: usize = 0;
    while (try it.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 10000), count);
}
