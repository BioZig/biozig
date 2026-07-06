const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TwoBitError = error{
    InvalidSignature,
    UnsupportedVersion,
    InvalidFormat,
    SequenceNotFound,
    OutOfBounds,
};

pub const NBlock = struct {
    start: u32,
    len: u32,
};

pub const MaskBlock = struct {
    start: u32,
    len: u32,
};

pub const SequenceIndex = struct {
    name: []const u8,
    offset: u32,
};

pub const TwoBitFile = struct {
    allocator: Allocator,
    data: []const u8,
    swap_endian: bool,
    sequence_count: u32,
    indices: []SequenceIndex,

    fn readInt(self: *const TwoBitFile, comptime T: type, offset: *usize) !T {
        if (offset.* + @sizeOf(T) > self.data.len) return TwoBitError.InvalidFormat;
        var bytes: [@sizeOf(T)]u8 = undefined;
        @memcpy(&bytes, self.data[offset.* .. offset.* + @sizeOf(T)]);
        offset.* += @sizeOf(T);
        
        const endian: std.builtin.Endian = if (self.swap_endian) .big else .little;
        return std.mem.readInt(T, &bytes, endian);
    }

    pub fn init(allocator: Allocator, data: []const u8) !TwoBitFile {
        var offset: usize = 0;
        
        if (data.len < 16) return TwoBitError.InvalidFormat;

        var bytes4: [4]u8 = undefined;
        @memcpy(&bytes4, data[offset .. offset + 4]);
        const magic = std.mem.readInt(u32, &bytes4, .little);
        offset += 4;

        var swap_endian = false;
        if (magic == 0x1A412743) {
            swap_endian = false;
        } else if (magic == 0x4327411A) {
            swap_endian = true;
        } else {
            return TwoBitError.InvalidSignature;
        }

        const endian: std.builtin.Endian = if (swap_endian) .big else .little;

        @memcpy(&bytes4, data[offset .. offset + 4]);
        const version = std.mem.readInt(u32, &bytes4, endian);
        offset += 4;

        if (version != 0) {
            return TwoBitError.UnsupportedVersion;
        }

        @memcpy(&bytes4, data[offset .. offset + 4]);
        const sequence_count = std.mem.readInt(u32, &bytes4, endian);
        offset += 4;

        offset += 4; // reserved

        var indices = try allocator.alloc(SequenceIndex, sequence_count);
        errdefer {
            for (indices) |idx| {
                allocator.free(idx.name);
            }
            allocator.free(indices);
        }

        for (0..sequence_count) |i| {
            if (offset >= data.len) return TwoBitError.InvalidFormat;
            const name_len = data[offset];
            offset += 1;

            if (offset + name_len > data.len) return TwoBitError.InvalidFormat;
            const name = try allocator.alloc(u8, name_len);
            @memcpy(name, data[offset .. offset + name_len]);
            errdefer allocator.free(name);
            offset += name_len;

            if (offset + 4 > data.len) return TwoBitError.InvalidFormat;
            @memcpy(&bytes4, data[offset .. offset + 4]);
            const seq_offset = std.mem.readInt(u32, &bytes4, endian);
            offset += 4;

            indices[i] = .{
                .name = name,
                .offset = seq_offset,
            };
        }

        return TwoBitFile{
            .allocator = allocator,
            .data = data,
            .swap_endian = swap_endian,
            .sequence_count = sequence_count,
            .indices = indices,
        };
    }

    pub fn deinit(self: *TwoBitFile) void {
        for (self.indices) |idx| {
            self.allocator.free(idx.name);
        }
        self.allocator.free(self.indices);
    }

    fn findSequence(self: *const TwoBitFile, name: []const u8) !SequenceIndex {
        for (self.indices) |idx| {
            if (std.mem.eql(u8, idx.name, name)) {
                return idx;
            }
        }
        return TwoBitError.SequenceNotFound;
    }

    /// Fetches the raw sequence in the [start, end) region (0-indexed).
    /// Uses T=00, C=01, A=10, G=11 mapping and accounts for N blocks.
    pub fn fetchSequence(self: *const TwoBitFile, seq_name: []const u8, start: u32, end: u32) ![]u8 {
        if (start > end) return TwoBitError.OutOfBounds;
        const seq_len = end - start;
        var seq_buf = try self.allocator.alloc(u8, seq_len);
        errdefer self.allocator.free(seq_buf);

        const seq_idx = try self.findSequence(seq_name);
        var offset: usize = seq_idx.offset;

        const dna_size = try self.readInt(u32, &offset);
        if (end > dna_size) return TwoBitError.OutOfBounds;

        const n_block_count = try self.readInt(u32, &offset);
        var n_starts = try self.allocator.alloc(u32, n_block_count);
        defer self.allocator.free(n_starts);
        for (0..n_block_count) |i| n_starts[i] = try self.readInt(u32, &offset);

        var n_lens = try self.allocator.alloc(u32, n_block_count);
        defer self.allocator.free(n_lens);
        for (0..n_block_count) |i| n_lens[i] = try self.readInt(u32, &offset);

        const mask_block_count = try self.readInt(u32, &offset);
        // We skip mask blocks for fetching raw sequence, just read past them
        offset += mask_block_count * 4 * 2;

        _ = try self.readInt(u32, &offset); // reserved

        const dna_offset = offset;

        // Decode nucleotides
        // The most significant 2 bits of each byte are the first nucleotide
        const char_map = [4]u8{ 'T', 'C', 'A', 'G' };

        for (start..end) |pos| {
            const byte_idx = pos / 4;
            const bit_offset = 6 - (pos % 4) * 2;
            
            if (dna_offset + byte_idx >= self.data.len) return TwoBitError.InvalidFormat;
            const b = self.data[dna_offset + byte_idx];
            
            const val = (b >> @intCast(bit_offset)) & 0b11;
            seq_buf[pos - start] = char_map[val];
        }

        // Apply N blocks
        for (0..n_block_count) |i| {
            const n_start = n_starts[i];
            const n_end = n_start + n_lens[i];
            
            // Check intersection with [start, end)
            if (n_end <= start or n_start >= end) continue;

            const overlap_start = @max(n_start, start);
            const overlap_end = @min(n_end, end);
            for (overlap_start..overlap_end) |pos| {
                seq_buf[pos - start] = 'N';
            }
        }

        return seq_buf;
    }
};

test "TwoBit basic operations" {
    const allocator = std.testing.allocator;

    // Create a mock 2bit file manually for testing.
    // Sequence 1: "chr1", DNA: "TCAGNNTCAG", length: 10
    // T = 00, C = 01, A = 10, G = 11.
    // "TCAG" = 00 01 10 11 = 0x1B
    // "NN" -> we can encode as anything, say "TC" = 00 01, masked by N block.
    // "TCAG" = 00 01 10 11 = 0x1B
    // Base pairs:
    // 0: T (00)
    // 1: C (01)
    // 2: A (10)
    // 3: G (11) -> Byte 0: 0x1B
    // 4: T (00, but will be N)
    // 5: C (01, but will be N)
    // 6: T (00)
    // 7: C (01) -> Byte 1: 00 01 00 01 = 0x11
    // 8: A (10)
    // 9: G (11)
    // 10, 11 (padding 00 00) -> Byte 2: 10 11 00 00 = 0xB0

    var buffer: [128]u8 = undefined;
    var offset: usize = 0;
    
    // Header
    std.mem.writeInt(u32, buffer[offset..][0..4], 0x1A412743, .little); offset += 4;
    std.mem.writeInt(u32, buffer[offset..][0..4], 0, .little); offset += 4;
    std.mem.writeInt(u32, buffer[offset..][0..4], 1, .little); offset += 4;
    std.mem.writeInt(u32, buffer[offset..][0..4], 0, .little); offset += 4;

    // Index
    buffer[offset] = 4; offset += 1;
    @memcpy(buffer[offset..offset+4], "chr1"); offset += 4;
    std.mem.writeInt(u32, buffer[offset..][0..4], 25, .little); offset += 4;

    // Sequence Record
    std.mem.writeInt(u32, buffer[offset..][0..4], 10, .little); offset += 4; // dnaSize
    std.mem.writeInt(u32, buffer[offset..][0..4], 1, .little); offset += 4; // nBlockCount
    std.mem.writeInt(u32, buffer[offset..][0..4], 4, .little); offset += 4; // nStarts
    std.mem.writeInt(u32, buffer[offset..][0..4], 2, .little); offset += 4; // nLens
    std.mem.writeInt(u32, buffer[offset..][0..4], 0, .little); offset += 4; // maskBlockCount
    std.mem.writeInt(u32, buffer[offset..][0..4], 0, .little); offset += 4; // reserved

    // DNA
    buffer[offset] = 0x1B; offset += 1;
    buffer[offset] = 0x11; offset += 1;
    buffer[offset] = 0xB0; offset += 1;

    var tb = try TwoBitFile.init(allocator, buffer[0..offset]);
    defer tb.deinit();

    try std.testing.expectEqual(@as(u32, 1), tb.sequence_count);
    try std.testing.expectEqualStrings("chr1", tb.indices[0].name);

    const seq1 = try tb.fetchSequence("chr1", 0, 10);
    defer allocator.free(seq1);
    try std.testing.expectEqualStrings("TCAGNNTCAG", seq1);
    
    const seq2 = try tb.fetchSequence("chr1", 2, 7);
    defer allocator.free(seq2);
    try std.testing.expectEqualStrings("AGNNT", seq2);
}
