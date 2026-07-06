const std = @import("std");

pub const GtfRecord = struct {
    seqname: []const u8,
    source: []const u8,
    feature: []const u8,
    start: usize, // 0-based coordinate internally
    end: usize,   // 0-based coordinate internally (inclusive)
    score: ?f64 = null,
    strand: u8,
    frame: ?u8 = null,
    attributes: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: GtfRecord) void {
        self.allocator.free(self.seqname);
        self.allocator.free(self.source);
        self.allocator.free(self.feature);
        self.allocator.free(self.attributes);
    }

    pub fn validate(self: GtfRecord) !void {
        if (self.seqname.len == 0) return error.EmptySeqname;
        if (self.source.len == 0) return error.EmptySource;
        if (self.feature.len == 0) return error.EmptyFeature;
        if (self.start > self.end) return error.InvalidCoordinates;
        if (self.strand != '+' and self.strand != '-' and self.strand != '.') {
            return error.InvalidStrand;
        }
        if (self.frame) |f| {
            if (f != '0' and f != '1' and f != '2' and f != '.') {
                return error.InvalidFrame;
            }
        }
    }
};

/// Streaming GTF Reader/Iterator
pub fn GtfIterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        allocator: std.mem.Allocator,
        line_buf: std.ArrayList(u8),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, reader: ReaderType) Self {
            return .{
                .reader = reader,
                .allocator = allocator,
                .line_buf = std.ArrayList(u8).empty,
            };
        }

        pub fn deinit(self: *Self) void {
            self.line_buf.deinit(self.allocator);
        }

        pub fn next(self: *Self) !?GtfRecord {
            while (true) {
                self.line_buf.clearRetainingCapacity();
                while (true) {
                    const b = self.reader.readByte() catch |err| {
                        if (err == error.EndOfStream) {
                            if (self.line_buf.items.len == 0) return null;
                            break;
                        }
                        return err;
                    };
                    if (b == '\n') break;
                    try self.line_buf.append(self.allocator, b);
                }

                const line = std.mem.trimEnd(u8, self.line_buf.items, "\r");
                if (line.len == 0) continue;
                if (line[0] == '#') continue; // skip comments

                var fields = std.mem.splitScalar(u8, line, '\t');
                const seqname = fields.next() orelse return error.GtfMissingSeqname;
                const source = fields.next() orelse return error.GtfMissingSource;
                const feature = fields.next() orelse return error.GtfMissingFeature;
                const start_str = fields.next() orelse return error.GtfMissingStart;
                const end_str = fields.next() orelse return error.GtfMissingEnd;
                const score_str = fields.next() orelse return error.GtfMissingScore;
                const strand_str = fields.next() orelse return error.GtfMissingStrand;
                const frame_str = fields.next() orelse return error.GtfMissingFrame;
                const attributes = fields.next() orelse return error.GtfMissingAttributes;

                const parsed_start = try std.fmt.parseInt(usize, start_str, 10);
                const parsed_end = try std.fmt.parseInt(usize, end_str, 10);

                if (parsed_start == 0 or parsed_end == 0) return error.InvalidGtfCoordinates;

                var score: ?f64 = null;
                if (!std.mem.eql(u8, score_str, ".")) {
                    score = try std.fmt.parseFloat(f64, score_str);
                }

                var frame: ?u8 = null;
                if (frame_str.len > 0) {
                    frame = frame_str[0];
                }

                const rec = GtfRecord{
                    .seqname = try self.allocator.dupe(u8, seqname),
                    .source = try self.allocator.dupe(u8, source),
                    .feature = try self.allocator.dupe(u8, feature),
                    .start = parsed_start - 1, // 1-based inclusive -> 0-based
                    .end = parsed_end - 1,     // 1-based inclusive -> 0-based
                    .score = score,
                    .strand = if (strand_str.len > 0) strand_str[0] else '.',
                    .frame = frame,
                    .attributes = try self.allocator.dupe(u8, attributes),
                    .allocator = self.allocator,
                };
                errdefer rec.deinit();
                try rec.validate();
                return rec;
            }
        }
    };
}

/// Helper constructor for GtfIterator
pub fn gtfIterator(allocator: std.mem.Allocator, reader: anytype) GtfIterator(@TypeOf(reader)) {
    return GtfIterator(@TypeOf(reader)).init(allocator, reader);
}

/// Serializes GtfRecord
pub fn serialize(writer: anytype, rec: GtfRecord) !void {
    try rec.validate();
    try writer.print("{s}\t{s}\t{s}\t{}\t{}\t", .{
        rec.seqname,
        rec.source,
        rec.feature,
        rec.start + 1,
        rec.end + 1,
    });
    if (rec.score) |s| {
        try writer.print("{d:.4}\t", .{s});
    } else {
        try writer.writeAll(".\t");
    }
    try writer.print("{c}\t", .{rec.strand});
    if (rec.frame) |f| {
        try writer.print("{c}\t", .{f});
    } else {
        try writer.writeAll(".\t");
    }
    try writer.print("{s}\n", .{rec.attributes});
}
