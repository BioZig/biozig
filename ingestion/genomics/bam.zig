const std = @import("std");
const core = @import("core");
const compression = core.compression;
const sam = @import("sam.zig");

/// BAM Record parsing and streaming iterator over BGZF blocks.
pub fn BamIterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        allocator: std.mem.Allocator,
        decompressed_buf: std.ArrayList(u8),
        read_idx: usize = 0,
        temp_comp_buf: std.ArrayList(u8),
        temp_decomp_buf: [65536]u8 = undefined,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, reader: ReaderType) Self {
            return .{
                .reader = reader,
                .allocator = allocator,
                .decompressed_buf = std.ArrayList(u8).empty,
                .temp_comp_buf = std.ArrayList(u8).empty,
            };
        }

        pub fn deinit(self: *Self) void {
            self.decompressed_buf.deinit(self.allocator);
            self.temp_comp_buf.deinit(self.allocator);
        }

        /// Pulls the next BAM record from the decompressed stream, loading new BGZF blocks as needed.
        pub fn next(self: *Self) !?sam.SamRecord {
            while (true) {
                // Check if we have enough bytes in the decompressed buffer for a BAM record size header (4 bytes)
                if (self.read_idx + 4 > self.decompressed_buf.items.len) {
                    try self.loadNextBlock();
                    if (self.read_idx + 4 > self.decompressed_buf.items.len) {
                        return null; // EOF
                    }
                }

                // Read block size (size of the remainder of this record)
                const block_size = std.mem.readInt(i32, self.decompressed_buf.items[self.read_idx .. self.read_idx + 4][0..4], .little);
                if (block_size < 32) return error.MalformedBamRecordSize;

                const next_record_start = self.read_idx + 4 + @as(usize, @intCast(block_size));
                while (next_record_start > self.decompressed_buf.items.len) {
                    // Need to load more blocks to complete the record
                    const prev_len = self.decompressed_buf.items.len;
                    try self.loadNextBlock();
                    if (self.decompressed_buf.items.len == prev_len) {
                        return error.MalformedBamTruncatedRecord;
                    }
                }

                // Parse the record fields from the decompressed buffer
                var offset = self.read_idx + 4;
                const refID = std.mem.readInt(i32, self.decompressed_buf.items[offset .. offset + 4][0..4], .little);
                offset += 4;
                const pos = std.mem.readInt(i32, self.decompressed_buf.items[offset .. offset + 4][0..4], .little);
                offset += 4;
                const l_read_name = self.decompressed_buf.items[offset];
                offset += 1;
                const mapq = self.decompressed_buf.items[offset];
                offset += 1;
                const bin = std.mem.readInt(u16, self.decompressed_buf.items[offset .. offset + 2][0..2], .little);
                _ = bin;
                offset += 2;
                const n_cigar_op = std.mem.readInt(u16, self.decompressed_buf.items[offset .. offset + 2][0..2], .little);
                offset += 2;
                const flag = std.mem.readInt(u16, self.decompressed_buf.items[offset .. offset + 2][0..2], .little);
                offset += 2;
                const l_seq = std.mem.readInt(i32, self.decompressed_buf.items[offset .. offset + 4][0..4], .little);
                offset += 4;
                const next_refID = std.mem.readInt(i32, self.decompressed_buf.items[offset .. offset + 4][0..4], .little);
                offset += 4;
                const next_pos = std.mem.readInt(i32, self.decompressed_buf.items[offset .. offset + 4][0..4], .little);
                offset += 4;
                const tlen = std.mem.readInt(i32, self.decompressed_buf.items[offset .. offset + 4][0..4], .little);
                offset += 4;

                // Read QNAME (null terminated)
                const qname_slice = self.decompressed_buf.items[offset .. offset + l_read_name];
                offset += l_read_name;
                const qname_len = if (l_read_name > 0 and qname_slice[l_read_name - 1] == 0) l_read_name - 1 else l_read_name;
                const qname = try self.allocator.dupe(u8, qname_slice[0..qname_len]);
                errdefer self.allocator.free(qname);

                // CIGAR
                const cigar_ops = self.decompressed_buf.items[offset .. offset + @as(usize, n_cigar_op) * 4];
                offset += @as(usize, n_cigar_op) * 4;
                var cigar_str = std.ArrayList(u8).empty;
                errdefer cigar_str.deinit(self.allocator);
                var c_idx: usize = 0;
                while (c_idx < n_cigar_op) : (c_idx += 1) {
                    const op_val = std.mem.readInt(u32, cigar_ops[c_idx * 4 .. (c_idx + 1) * 4][0..4], .little);
                    const op_len = op_val >> 4;
                    const op_char: u8 = switch (op_val & 0xf) {
                        0 => 'M',
                        1 => 'I',
                        2 => 'D',
                        3 => 'N',
                        4 => 'S',
                        5 => 'H',
                        6 => 'P',
                        7 => '=',
                        8 => 'X',
                        else => 'M',
                    };
                    var fmt_buf: [32]u8 = undefined;
                    const c_s = try std.fmt.bufPrint(&fmt_buf, "{}{c}", .{ op_len, op_char });
                    try cigar_str.appendSlice(self.allocator, c_s);
                }

                // SEQ
                const seq_len_bytes = (@as(usize, @intCast(l_seq)) + 1) / 2;
                const seq_bytes = self.decompressed_buf.items[offset .. offset + seq_len_bytes];
                offset += seq_len_bytes;
                var seq_str = try self.allocator.alloc(u8, @as(usize, @intCast(l_seq)));
                errdefer self.allocator.free(seq_str);
                for (0..@as(usize, @intCast(l_seq))) |s_idx| {
                    const byte = seq_bytes[s_idx / 2];
                    const val = if (s_idx % 2 == 0) (byte >> 4) else (byte & 0xf);
                    seq_str[s_idx] = switch (val) {
                        1 => 'A',
                        2 => 'C',
                        4 => 'G',
                        8 => 'T',
                        15 => 'N',
                        else => 'N',
                    };
                }

                // QUAL
                const qual_bytes = self.decompressed_buf.items[offset .. offset + @as(usize, @intCast(l_seq))];
                offset += @as(usize, @intCast(l_seq));
                var qual_str = try self.allocator.alloc(u8, @as(usize, @intCast(l_seq)));
                errdefer self.allocator.free(qual_str);
                for (qual_bytes, 0..) |qb, q_idx| {
                    qual_str[q_idx] = if (qb == 0xff) '*' else (qb + 33);
                }

                const rname = try std.fmt.allocPrint(self.allocator, "ref_{}", .{refID});
                errdefer self.allocator.free(rname);
                const rnext = try std.fmt.allocPrint(self.allocator, "ref_{}", .{next_refID});
                errdefer self.allocator.free(rnext);

                self.read_idx = next_record_start;

                const rec = sam.SamRecord{
                    .qname = qname,
                    .flag = flag,
                    .rname = rname,
                    .pos = @as(usize, @intCast(pos + 1)), // BAM is 0-based, SAM is 1-based
                    .mapq = mapq,
                    .cigar = try cigar_str.toOwnedSlice(self.allocator),
                    .rnext = rnext,
                    .pnext = @as(usize, @intCast(next_pos + 1)),
                    .tlen = tlen,
                    .seq = seq_str,
                    .qual = qual_str,
                    .allocator = self.allocator,
                };
                try rec.validate();
                return rec;
            }
        }

        fn loadNextBlock(self: *Self) !void {
            // Read basic gzip header (12 bytes)
            var fixed_buf: [12]u8 = undefined;
            const bytes_read = try self.reader.readAll(&fixed_buf);
            if (bytes_read == 0) return; // EOF
            if (bytes_read < 12) return error.MalformedBgzfHeader;

            // Verify gzip magic and flags
            if (fixed_buf[0] != 0x1f or fixed_buf[1] != 0x8b) return error.InvalidBgzfMagic;
            if (fixed_buf[2] != 0x08) return error.InvalidBgzfCM;
            if ((fixed_buf[3] & 0x04) == 0) return error.InvalidBgzfFlags;

            const xlen = std.mem.readInt(u16, fixed_buf[10..12], .little);
            if (xlen < 6) return error.InvalidBgzfXlen;

            // Extra subfields
            var extra_buf = try self.allocator.alloc(u8, xlen);
            defer self.allocator.free(extra_buf);
            try self.reader.readNoEof(extra_buf);

            // Seek BC subfield for BSIZE
            var offset: usize = 0;
            var bsize: ?u16 = null;
            while (offset + 4 <= xlen) {
                const si1 = extra_buf[offset];
                const si2 = extra_buf[offset + 1];
                const slen = std.mem.readInt(u16, extra_buf[offset + 2 .. offset + 4][0..2], .little);
                if (si1 == 'B' and si2 == 'C' and slen == 2) {
                    bsize = std.mem.readInt(u16, extra_buf[offset + 4 .. offset + 6][0..2], .little);
                    break;
                }
                offset += 4 + @as(usize, slen);
            }

            const total_block_size = bsize orelse return error.BgzfBsizeMissing;

            // Compressed payload size = total_block_size - header - footer
            // Header is 12 + xlen. Footer is 8.
            // Wait, we just read the payload and footer into temp_comp_buf.
            // We want to reconstruct the ENTIRE gzip stream chunk for compression.decompress.
            // compression.decompress expects the full gzip chunk (Header + Payload + Footer)
            const payload_and_footer_size = (total_block_size + 1) - 12 - xlen;
            self.temp_comp_buf.clearRetainingCapacity();
            try self.temp_comp_buf.resize(self.allocator, 12 + xlen + payload_and_footer_size);
            
            // Reconstruct header
            @memcpy(self.temp_comp_buf.items[0..12], &fixed_buf);
            @memcpy(self.temp_comp_buf.items[12 .. 12 + xlen], extra_buf);
            
            // Read payload and footer
            try self.reader.readNoEof(self.temp_comp_buf.items[12 + xlen ..]);

            // Decompress this block
            const decomp = try compression.decompress(&self.temp_decomp_buf, self.temp_comp_buf.items, .gzip);
            try self.decompressed_buf.appendSlice(self.allocator, decomp);
        }
    };
}

/// Helper constructor for BamIterator
pub fn bamIterator(allocator: std.mem.Allocator, reader: anytype) BamIterator(@TypeOf(reader)) {
    return BamIterator(@TypeOf(reader)).init(allocator, reader);
}

/// Serializes a SAM Record to BAM format
pub fn serialize(writer: anytype, rec: sam.SamRecord) !void {
    try rec.validate();
    
    // We will write the binary record structure
    var qname_buf: [256]u8 = undefined;
    const qname_len = @min(rec.qname.len, 254);
    @memcpy(qname_buf[0..qname_len], rec.qname[0..qname_len]);
    qname_buf[qname_len] = 0; // null terminator
    const l_read_name = @as(u8, @intCast(qname_len + 1));

    // Calculate total block size
    // 32 + l_read_name + n_cigar * 4 + seq_bytes + qual_bytes
    const l_seq = @as(i32, @intCast(rec.seq.len));
    const seq_bytes_len = (@as(usize, @intCast(l_seq)) + 1) / 2;
    const n_cigar: u16 = 0; // for simplicity or we can compute basic cigar operations

    const block_size = 32 + @as(i32, l_read_name) + @as(i32, n_cigar) * 4 + @as(i32, @intCast(seq_bytes_len)) + l_seq;
    try writer.writeInt(i32, block_size, .little);
    try writer.writeInt(i32, 0, .little); // refID
    try writer.writeInt(i32, @as(i32, @intCast(rec.pos - 1)), .little); // 0-based pos
    try writer.writeByte(l_read_name);
    try writer.writeByte(rec.mapq);
    try writer.writeInt(u16, 0, .little); // bin
    try writer.writeInt(u16, n_cigar, .little); // n_cigar_op
    try writer.writeInt(u16, rec.flag, .little); // flag
    try writer.writeInt(i32, l_seq, .little);
    try writer.writeInt(i32, 0, .little); // next_refID
    try writer.writeInt(i32, @as(i32, @intCast(rec.pnext - 1)), .little);
    try writer.writeInt(i32, @as(i32, @intCast(rec.tlen)), .little);

    try writer.writeAll(qname_buf[0..l_read_name]);

    // write SEQ
    var seq_bytes = try writer.context.allocator.alloc(u8, seq_bytes_len);
    defer writer.context.allocator.free(seq_bytes);
    @memset(seq_bytes, 0);
    for (rec.seq, 0..) |c, idx| {
        const val = switch (c) {
            'A', 'a' => @as(u8, 1),
            'C', 'c' => @as(u8, 2),
            'G', 'g' => @as(u8, 4),
            'T', 't' => @as(u8, 8),
            else => @as(u8, 15),
        };
        if (idx % 2 == 0) {
            seq_bytes[idx / 2] |= val << 4;
        } else {
            seq_bytes[idx / 2] |= val;
        }
    }
    try writer.writeAll(seq_bytes);

    // write QUAL
    var qual_bytes = try writer.context.allocator.alloc(u8, @as(usize, @intCast(l_seq)));
    defer writer.context.allocator.free(qual_bytes);
    for (rec.qual, 0..) |q, idx| {
        qual_bytes[idx] = if (q == '*') 0xff else (q - 33);
    }
    try writer.writeAll(qual_bytes);
}
