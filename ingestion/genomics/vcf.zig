const std = @import("std");

pub const VcfRecord = struct {
    chrom: []const u8,
    pos: usize,
    id: []const u8,
    ref: []const u8,
    alt: []const u8,
};

/// Streaming zero-copy VCF Iterator
pub const VcfIterator = struct {
    buffer: []const u8,
    pos: usize,
    alts_buffer: []const u8 = "",
    alts_pos: usize = 0,
    has_more_alts: bool = false,
    current_chrom: []const u8 = "",
    current_vcf_pos: usize = 0,
    current_id: []const u8 = "",
    current_ref: []const u8 = "",

    pub fn init(buffer: []const u8) VcfIterator {
        return .{
            .buffer = buffer,
            .pos = 0,
        };
    }

    pub fn next(self: *VcfIterator) !?VcfRecord {
        while (true) {
            // Serve remaining alts from the last parsed line if any
            if (self.has_more_alts or self.alts_pos < self.alts_buffer.len) {
                const start = self.alts_pos;
                const end_idx = std.mem.indexOfScalarPos(u8, self.alts_buffer, start, ',') orelse self.alts_buffer.len;
                const alt = self.alts_buffer[start..end_idx];
                self.alts_pos = end_idx;
                if (self.alts_pos < self.alts_buffer.len) {
                    self.alts_pos += 1; // skip comma
                    self.has_more_alts = true;
                } else {
                    self.has_more_alts = false;
                }

                if (alt.len == 0) return error.InvalidAltAllele;
                for (alt) |c| {
                    if (!std.ascii.isAlphabetic(c) and c != '*') return error.InvalidAltAllele;
                }

                return VcfRecord{
                    .chrom = self.current_chrom,
                    .pos = self.current_vcf_pos,
                    .id = self.current_id,
                    .ref = self.current_ref,
                    .alt = alt,
                };
            }

            if (self.pos >= self.buffer.len) return null;

            // Software Prefetching: fetch ahead by ~4 cache lines (256 bytes) to keep L1 cache hot
            const prefetch_pos = @min(self.pos + 256, self.buffer.len - 1);
            @prefetch(&self.buffer[prefetch_pos], .{ .rw = .read, .locality = 3, .cache = .data });

            const end_idx = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const line = std.mem.trimEnd(u8, self.buffer[self.pos..end_idx], "\r");
            self.pos = end_idx;
            if (self.pos < self.buffer.len) self.pos += 1;

            if (line.len == 0) continue;
            if (line[0] == '#') continue; // skip header lines

            var fields = std.mem.splitScalar(u8, line, '\t');
            const chrom = fields.next() orelse return error.VcfMissingChrom;
            const pos_str = fields.next() orelse return error.VcfMissingPos;
            const id = fields.next() orelse return error.VcfMissingId;
            const ref = fields.next() orelse return error.VcfMissingRef;
            const alt_raw = fields.next() orelse return error.VcfMissingAlt;

            const parsed_pos = try std.fmt.parseInt(usize, pos_str, 10);
            if (parsed_pos == 0) return error.InvalidVcfPosition;

            // Validate ref alleles
            for (ref) |c| {
                if (!std.ascii.isAlphabetic(c)) return error.InvalidRefAllele;
            }

            self.current_chrom = chrom;
            self.current_vcf_pos = parsed_pos;
            self.current_id = id;
            self.current_ref = ref;
            self.alts_buffer = alt_raw;
            self.alts_pos = 0;
        }
    }
};

/// Helper constructor for VcfIterator
pub fn vcfIterator(buffer: []const u8) VcfIterator {
    return VcfIterator.init(buffer);
}

/// Serializes VcfRecord to VCF format line
pub fn serialize(writer: anytype, rec: VcfRecord) !void {
    if (rec.chrom.len == 0) return error.EmptyChrom;
    try writer.print("{s}\t{}\t{s}\t{s}\t{s}\t.\t.\t.\n", .{
        rec.chrom,
        rec.pos,
        rec.id,
        rec.ref,
        rec.alt,
    });
}

test "benchmark zero-copy VCF iterator" {
    const test_data = 
        "chr1\t1000\tid1\tA\tT,C\n" ** 5000; // 10000 records total (2 alts per line)
    
    var it = VcfIterator.init(test_data);
    var count: usize = 0;
    while (try it.next()) |_| {
        count += 1;
    }
    
    try std.testing.expectEqual(@as(usize, 10000), count);
}
