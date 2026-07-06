const std = @import("std");

pub const Gff3Record = struct {
    seqid: []const u8,
    source: []const u8,
    feature_type: []const u8,
    start: usize, // 0-based coordinate internally
    end: usize,   // 0-based coordinate internally (inclusive)
    score: ?f64 = null,
    strand: u8,
    phase: ?u8 = null,
    attributes: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Gff3Record) void {
        self.allocator.free(self.seqid);
        self.allocator.free(self.source);
        self.allocator.free(self.feature_type);
        self.allocator.free(self.attributes);
    }

    pub fn validate(self: Gff3Record) !void {
        if (self.seqid.len == 0) return error.EmptySeqid;
        if (self.source.len == 0) return error.EmptySource;
        if (self.feature_type.len == 0) return error.EmptyFeatureType;
        if (self.start > self.end) return error.InvalidCoordinates;
        if (self.strand != '+' and self.strand != '-' and self.strand != '.' and self.strand != '?') {
            return error.InvalidStrand;
        }
        if (self.phase) |p| {
            if (p != '0' and p != '1' and p != '2' and p != '.') {
                return error.InvalidPhase;
            }
        }
    }
};

/// Streaming GFF3 Reader/Iterator
pub fn Gff3Iterator(comptime ReaderType: type) type {
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

        pub fn next(self: *Self) !?Gff3Record {
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
                if (line[0] == '#') continue; // skip comments and headers

                var fields = std.mem.splitScalar(u8, line, '\t');
                const seqid = fields.next() orelse return error.Gff3MissingSeqid;
                const source = fields.next() orelse return error.Gff3MissingSource;
                const feature_type = fields.next() orelse return error.Gff3MissingFeatureType;
                const start_str = fields.next() orelse return error.Gff3MissingStart;
                const end_str = fields.next() orelse return error.Gff3MissingEnd;
                const score_str = fields.next() orelse return error.Gff3MissingScore;
                const strand_str = fields.next() orelse return error.Gff3MissingStrand;
                const phase_str = fields.next() orelse return error.Gff3MissingPhase;
                const attributes = fields.next() orelse return error.Gff3MissingAttributes;

                const parsed_start = try std.fmt.parseInt(usize, start_str, 10);
                const parsed_end = try std.fmt.parseInt(usize, end_str, 10);

                if (parsed_start == 0 or parsed_end == 0) return error.InvalidGff3Coordinates;

                var score: ?f64 = null;
                if (!std.mem.eql(u8, score_str, ".")) {
                    score = try std.fmt.parseFloat(f64, score_str);
                }

                var phase: ?u8 = null;
                if (phase_str.len > 0) {
                    phase = phase_str[0];
                }

                const rec = Gff3Record{
                    .seqid = try self.allocator.dupe(u8, seqid),
                    .source = try self.allocator.dupe(u8, source),
                    .feature_type = try self.allocator.dupe(u8, feature_type),
                    .start = parsed_start - 1, // 1-based inclusive -> 0-based
                    .end = parsed_end - 1,     // 1-based inclusive -> 0-based
                    .score = score,
                    .strand = if (strand_str.len > 0) strand_str[0] else '.',
                    .phase = phase,
                    .attributes = try self.allocator.dupe(u8, attributes),
                    .allocator = self.allocator,
                };
                rec.validate() catch |err| {
                    rec.deinit();
                    return err;
                };
                return rec;
            }
        }
    };
}

/// Helper constructor for Gff3Iterator
pub fn gff3Iterator(allocator: std.mem.Allocator, reader: anytype) Gff3Iterator(@TypeOf(reader)) {
    return Gff3Iterator(@TypeOf(reader)).init(allocator, reader);
}

/// Serializes Gff3Record
pub fn serialize(writer: anytype, rec: Gff3Record) !void {
    try rec.validate();
    try writer.print("{s}\t{s}\t{s}\t{}\t{}\t", .{
        rec.seqid,
        rec.source,
        rec.feature_type,
        rec.start + 1,
        rec.end + 1,
    });
    if (rec.score) |s| {
        try writer.print("{d:.4}\t", .{s});
    } else {
        try writer.writeAll(".\t");
    }
    try writer.print("{c}\t", .{rec.strand});
    if (rec.phase) |p| {
        try writer.print("{c}\t", .{p});
    } else {
        try writer.writeAll(".\t");
    }
    try writer.print("{s}\n", .{rec.attributes});
}
