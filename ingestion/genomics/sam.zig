const std = @import("std");

pub const SamRecord = struct {
    qname: []const u8,
    flag: u16,
    rname: []const u8,
    pos: usize, // 1-based POS in SAM, we keep it as 1-based or 0-based? Let's keep it as 1-based but standard POS.
    mapq: u8,
    cigar: []const u8,
    rnext: []const u8,
    pnext: usize,
    tlen: i64,
    seq: []const u8,
    qual: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: SamRecord) void {
        self.allocator.free(self.qname);
        self.allocator.free(self.rname);
        self.allocator.free(self.cigar);
        self.allocator.free(self.rnext);
        self.allocator.free(self.seq);
        self.allocator.free(self.qual);
    }

    pub fn validate(self: SamRecord) !void {
        if (self.qname.len == 0) return error.EmptyQName;
        if (self.rname.len == 0) return error.EmptyRName;
        if (self.cigar.len == 0) return error.EmptyCigar;
        if (self.seq.len > 0 and self.qual.len > 0 and self.seq.len != self.qual.len) {
            if (!std.mem.eql(u8, self.qual, "*")) {
                return error.SeqQualLengthMismatch;
            }
        }
    }
};

/// Streaming SAM Reader/Iterator
pub fn SamIterator(comptime ReaderType: type) type {
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

        pub fn next(self: *Self) !?SamRecord {
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
                if (line[0] == '@') continue; // Skip header lines for streaming records

                var fields = std.mem.splitScalar(u8, line, '\t');
                const qname = fields.next() orelse return error.SamMissingQname;
                const flag_str = fields.next() orelse return error.SamMissingFlag;
                const rname = fields.next() orelse return error.SamMissingRname;
                const pos_str = fields.next() orelse return error.SamMissingPos;
                const mapq_str = fields.next() orelse return error.SamMissingMapq;
                const cigar = fields.next() orelse return error.SamMissingCigar;
                const rnext = fields.next() orelse return error.SamMissingRnext;
                const pnext_str = fields.next() orelse return error.SamMissingPnext;
                const tlen_str = fields.next() orelse return error.SamMissingTlen;
                const seq = fields.next() orelse return error.SamMissingSeq;
                const qual = fields.next() orelse return error.SamMissingQual;

                const flag = try std.fmt.parseInt(u16, flag_str, 10);
                const pos = try std.fmt.parseInt(usize, pos_str, 10);
                const mapq = try std.fmt.parseInt(u8, mapq_str, 10);
                const pnext = try std.fmt.parseInt(usize, pnext_str, 10);
                const tlen = try std.fmt.parseInt(i64, tlen_str, 10);

                const rec = SamRecord{
                    .qname = try self.allocator.dupe(u8, qname),
                    .flag = flag,
                    .rname = try self.allocator.dupe(u8, rname),
                    .pos = pos,
                    .mapq = mapq,
                    .cigar = try self.allocator.dupe(u8, cigar),
                    .rnext = try self.allocator.dupe(u8, rnext),
                    .pnext = pnext,
                    .tlen = tlen,
                    .seq = try self.allocator.dupe(u8, seq),
                    .qual = try self.allocator.dupe(u8, qual),
                    .allocator = self.allocator,
                };
                errdefer rec.deinit();
                try rec.validate();
                return rec;
            }
        }
    };
}

/// Helper constructor for SamIterator
pub fn samIterator(allocator: std.mem.Allocator, reader: anytype) SamIterator(@TypeOf(reader)) {
    return SamIterator(@TypeOf(reader)).init(allocator, reader);
}

/// Serializes SAM record
pub fn serialize(writer: anytype, rec: SamRecord) !void {
    try rec.validate();
    try writer.print("{s}\t{}\t{s}\t{}\t{}\t{s}\t{s}\t{}\t{}\t{s}\t{s}\n", .{
        rec.qname,
        rec.flag,
        rec.rname,
        rec.pos,
        rec.mapq,
        rec.cigar,
        rec.rnext,
        rec.pnext,
        rec.tlen,
        rec.seq,
        rec.qual,
    });
}
