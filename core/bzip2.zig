const std = @import("std");

pub fn Bzip2Decompressor(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        bit_reader: BitReader(ReaderType),
        
        // BWT State
        block_size_100k: usize,
        bwt_primary_index: usize,
        inUse: [256]bool,
        
        pub fn init(allocator: std.mem.Allocator, reader: ReaderType) Self {
            return .{
                .allocator = allocator,
                .bit_reader = BitReader(ReaderType).init(reader),
                .block_size_100k = 0,
                .bwt_primary_index = 0,
                .inUse = [_]bool{false} ** 256,
            };
        }

        pub fn decompress(self: *Self, out_writer: anytype) !void {
            var magic: [3]u8 = undefined;
            _ = try self.bit_reader.readBytes(&magic);
            if (!std.mem.eql(u8, &magic, "BZh")) return error.InvalidBzip2Header;

            const block_sz_char = try self.bit_reader.readByte();
            if (block_sz_char < '1' or block_sz_char > '9') return error.InvalidBlockSize;
            self.block_size_100k = block_sz_char - '0';

            while (true) {
                const pi1 = try self.bit_reader.readBits(24);
                const pi2 = try self.bit_reader.readBits(24);
                std.debug.print("Block marker: {x} {x}\n", .{pi1, pi2});
                
                // End of stream marker: 0x177245385090
                if (pi1 == 0x177245 and pi2 == 0x385090) {
                    std.debug.print("EOS found.\n", .{});
                    const ch = try self.bit_reader.readBits(16); const cl = try self.bit_reader.readBits(16);
                    _ = ch; _ = cl;
                    break;
                }
                
                if (pi1 != 0x314159 or pi2 != 0x265359) return error.InvalidBlockHeader;
                
                std.debug.print("Decoding block...\n", .{});
                try self.decompressBlock(out_writer);
            }
        }

        fn decompressBlock(self: *Self, out_writer: anytype) !void {
            const block_crc_high = try self.bit_reader.readBits(16);
            const block_crc_low = try self.bit_reader.readBits(16);
            const block_crc = (block_crc_high << 16) | block_crc_low;
            _ = block_crc; // TODO: Implement CRC validation
            
            const randomized = try self.bit_reader.readBits(1);
            if (randomized == 1) return error.DeprecatedRandomizedBzip2NotSupported;
            
            const orig_ptr = try self.bit_reader.readBits(24);
            const max_block_bytes = self.block_size_100k * 100000;
            
            var inUse = [_]bool{false} ** 256;
            try self.readSymbolMap(&inUse);
            
            var huffman = HuffmanEngine(ReaderType){};
            var active_symbols: usize = 0;
            for (inUse) |active| {
                if (active) active_symbols += 1;
            }
            active_symbols += 2; // RUNA, RUNB (EOB is included implicitly if my math above holds)
            try huffman.decodeLengths(&self.bit_reader, active_symbols);
            huffman.buildTables(active_symbols);
            
            const bwt_buffer = try self.allocator.alloc(u8, max_block_bytes);
            defer self.allocator.free(bwt_buffer);
            
            self.inUse = inUse;
            const bwt_length = try self.decodeMtfAndRle(&huffman, bwt_buffer, active_symbols);
            try self.inverseBwt(bwt_buffer[0..bwt_length], orig_ptr, out_writer);
        }
        
        fn readSymbolMap(self: *Self, inUse: *[256]bool) !void {
            const huff_in_use_16 = try self.bit_reader.readBits(16);
            var i: usize = 0;
            while (i < 16) : (i += 1) {
                if ((huff_in_use_16 & (@as(u32, 1) << @intCast(15 - i))) != 0) {
                    const huff_in_use_8 = try self.bit_reader.readBits(16);
                    var j: usize = 0;
                    while (j < 16) : (j += 1) {
                        if ((huff_in_use_8 & (@as(u32, 1) << @intCast(15 - j))) != 0) {
                            inUse[i * 16 + j] = true;
                        }
                    }
                }
            }
        }

        fn decodeMtfAndRle(self: *Self, huffman: *HuffmanEngine(ReaderType), bwt_buffer: []u8, active_symbols: usize) !usize {
            var mtf: [256]u8 = undefined;
            var mtf_idx: usize = 0;
            for (0..256) |i| {
                if (self.inUse[i]) {
                    mtf[mtf_idx] = @intCast(i);
                    mtf_idx += 1;
                }
            }
            
            var bwt_ptr: usize = 0;
            var selector_idx: usize = 0;
            var group_pos: usize = 0;
            var current_tree = huffman.selectors[0];
            
            var run_length: usize = 0;
            var run_weight: usize = 1;
            
            while (true) {
                if (group_pos >= 50) {
                    group_pos = 0;
                    selector_idx += 1;
                    if (selector_idx >= huffman.num_selectors) return error.CorruptedSelectorIndex;
                    current_tree = huffman.selectors[selector_idx];
                }
                group_pos += 1;

                const next_sym = try huffman.getSymbol(&self.bit_reader, current_tree);
                
                if (next_sym == 0 or next_sym == 1) { // RUNA (0) or RUNB (1)
                    if (next_sym == 0) {
                        run_length += run_weight;
                    } else {
                        run_length += run_weight * 2;
                    }
                    run_weight *= 2;
                    continue;
                }
                
                // If we had an accumulated run, flush it before processing the new symbol.
                if (run_length > 0) {
                    if (bwt_ptr + run_length > bwt_buffer.len) return error.BwtBufferOverflow;
                    const b = mtf[0];
                    for (0..run_length) |_| {
                        bwt_buffer[bwt_ptr] = b;
                        bwt_ptr += 1;
                    }
                    run_length = 0;
                    run_weight = 1;
                }

                if (next_sym == active_symbols - 1) { // End of block symbol
                    break;
                }

                if (bwt_ptr >= bwt_buffer.len) return error.BwtBufferOverflow;
                
                // Un-MTF the symbol
                const symbol_val = next_sym - 1;
                const b = mtf[symbol_val];
                bwt_buffer[bwt_ptr] = b;
                
                bwt_ptr += 1;
                
                // Move to front
                var j: usize = symbol_val;
                while (j > 0) : (j -= 1) {
                    mtf[j] = mtf[j - 1];
                }
                mtf[0] = b;
            }
            return bwt_ptr;
        }

        fn inverseBwt(self: *Self, bwt_buffer: []u8, orig_ptr: u32, out_writer: anytype) !void {
            if (orig_ptr >= bwt_buffer.len) return error.CorruptedOrigPtr;

            const bwt_length = bwt_buffer.len;
            const t_array = try self.allocator.alloc(u32, bwt_length);
            defer self.allocator.free(t_array);

            // O(N) Counting Sort to compute transformation vector T
            var counts = [_]usize{0} ** 256;
            for (bwt_buffer) |c| {
                counts[c] += 1;
            }

            var start_pos = [_]usize{0} ** 256;
            var total: usize = 0;
            for (0..256) |i| {
                start_pos[i] = total;
                total += counts[i];
            }

            for (0..bwt_length) |i| {
                const c = bwt_buffer[i];
                t_array[start_pos[c]] = @intCast(i);
                start_pos[c] += 1;
            }

            // Stream Output & RLE1 Inversion
            var curr: usize = t_array[orig_ptr];
            var last_char: i32 = -1;
            var run_count: usize = 0;

            for (0..bwt_length) |_| {
                const c = bwt_buffer[curr];
                curr = t_array[curr];

                if (run_count == 4) {
                    const repeat_count = c;
                    for (0..repeat_count) |_| {
                        try out_writer.writeByte(@intCast(last_char));
                    }
                    run_count = 0;
                    last_char = -1;
                } else {
                    try out_writer.writeByte(c);
                    if (c == last_char) {
                        run_count += 1;
                    } else {
                        run_count = 1;
                        last_char = c;
                    }
                }
            }
        }
    };
}

const MAX_TREES = 6;
const MAX_SELECTORS = 32768;
const MAX_SYMBOLS = 258;

pub fn HuffmanEngine(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        const MAX_CODE_LEN = 25;
        num_trees: u16 = 0,
        num_selectors: u16 = 0,
        selectors: [MAX_SELECTORS]u8 = undefined,
        lengths: [MAX_TREES][MAX_SYMBOLS]u8 = undefined,
        limit: [MAX_TREES][MAX_CODE_LEN]i32 = undefined,
        base: [MAX_TREES][MAX_CODE_LEN]i32 = undefined,
        perm: [MAX_TREES][MAX_SYMBOLS]i32 = undefined,
        min_lens: [MAX_TREES]u8 = undefined,

        pub fn buildTables(self: *Self, num_symbols: usize) void {
            for (0..self.num_trees) |t| {
                var min_len: u8 = 255;
                var max_len: u8 = 0;
                for (0..num_symbols) |i| {
                    if (self.lengths[t][i] > max_len) max_len = self.lengths[t][i];
                    if (self.lengths[t][i] < min_len) min_len = self.lengths[t][i];
                }
                self.min_lens[t] = min_len;
                
                var count = [_]i32{0} ** MAX_CODE_LEN;
                for (0..num_symbols) |i| {
                    count[self.lengths[t][i]] += 1;
                }
                
                var vec: i32 = 0;
                var cumulative: i32 = 0;
                for (1..MAX_CODE_LEN) |i| {
                    vec += count[i];
                    self.limit[t][i] = vec - 1;
                    vec <<= 1;
                }
                
                vec = 0;
                for (1..MAX_CODE_LEN) |i| {
                    self.base[t][i] = vec - cumulative;
                    cumulative += count[i];
                    vec = (self.limit[t][i] + 1) << 1;
                }
                
                var pp: usize = 0;
                for (min_len..max_len + 1) |i| {
                    for (0..num_symbols) |j| {
                        if (self.lengths[t][j] == i) {
                            self.perm[t][pp] = @intCast(j);
                            pp += 1;
                        }
                    }
                }
            }
        }

        pub fn getSymbol(self: *Self, bit_reader: *BitReader(ReaderType), tree: u8) !u32 {
            var len = self.min_lens[tree];
            var vec = @as(i32, @intCast(bit_reader.readBits(len) catch |err| {
                std.debug.print("getSymbol crashed on initial readBits. len: {}\n", .{len});
                return err;
            }));
            
            while (true) {
                if (vec <= self.limit[tree][len]) {
                    break;
                }
                len += 1;
                const bit = bit_reader.readBits(1) catch |err| {
                    std.debug.print("getSymbol crashed. Tree: {}, Len: {}, Vec: {}, Limit at Len: {}\n", .{tree, len, vec, self.limit[tree][len]});
                    return err;
                };
                vec = (vec << 1) | @as(i32, @intCast(bit));
            }
            
            const index = @as(usize, @intCast(vec - self.base[tree][len]));
            return @intCast(self.perm[tree][index]);
        }

        pub fn decodeLengths(self: *Self, bit_reader: *BitReader(ReaderType), num_symbols: usize) !void {
            self.num_trees = @intCast(try bit_reader.readBits(3));
            if (self.num_trees < 2 or self.num_trees > MAX_TREES) return error.InvalidHuffmanTrees;

            self.num_selectors = @intCast(try bit_reader.readBits(15));
            if (self.num_selectors == 0 or self.num_selectors > MAX_SELECTORS) return error.InvalidHuffmanSelectors;

            var pos: [MAX_TREES]u8 = undefined;
            for (0..self.num_trees) |i| {
                pos[i] = @intCast(i);
            }

            for (0..self.num_selectors) |i| {
                var v: u8 = 0;
                while (true) {
                    const bit = try bit_reader.readBits(1);
                    if (bit == 0) break;
                    v += 1;
                    if (v >= self.num_trees) return error.InvalidHuffmanSelector;
                }
                
                const tmp = pos[v];
                var j: usize = v;
                while (j > 0) : (j -= 1) {
                    pos[j] = pos[j - 1];
                }
                pos[0] = tmp;
                self.selectors[i] = tmp;
            }

            for (0..self.num_trees) |t| {
                var current_len: u8 = @intCast(try bit_reader.readBits(5));
                for (0..num_symbols) |s| {
                    while (true) {
                        const bit = try bit_reader.readBits(1);
                        if (bit == 0) break;
                        
                        const direction = try bit_reader.readBits(1);
                        if (direction == 0) {
                            current_len += 1;
                        } else {
                            if (current_len == 1) return error.InvalidHuffmanLength;
                            current_len -= 1;
                        }
                    }
                    self.lengths[t][s] = current_len;
                }
            }
        }
    };
}

pub fn BitReader(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        stream: ReaderType,
        bit_buffer: u32,
        bits_in_buffer: u8,
        byte_buffer: [8192]u8 = undefined,
        buffer_pos: usize = 0,
        buffer_len: usize = 0,

        pub fn init(stream: ReaderType) Self {
            return .{
                .stream = stream,
                .bit_buffer = 0,
                .bits_in_buffer = 0,
                .buffer_pos = 0,
                .buffer_len = 0,
            };
        }

        pub fn readBits(self: *Self, count: u8) !u32 {
            std.debug.assert(count <= 24);
            while (self.bits_in_buffer < count) {
                if (self.buffer_pos >= self.buffer_len) {
                    var n: usize = 0;
                    const BaseType = switch (@typeInfo(ReaderType)) {
                        .pointer => |p| p.child,
                        else => ReaderType,
                    };
                    if (@hasDecl(BaseType, "readSliceShort")) {
                        n = try self.stream.readSliceShort(&self.byte_buffer);
                    } else if (@hasDecl(BaseType, "read")) {
                        n = try self.stream.read(&self.byte_buffer);
                    } else {
                        @compileError("Unsupported ReaderType");
                    }
                    if (n == 0) return error.EndOfStream;
                    self.buffer_pos = 0;
                    self.buffer_len = n;
                }
                self.bit_buffer = (self.bit_buffer << 8) | self.byte_buffer[self.buffer_pos];
                self.buffer_pos += 1;
                self.bits_in_buffer += 8;
            }
            self.bits_in_buffer -= count;
            const result = (self.bit_buffer >> @intCast(self.bits_in_buffer)) & ((@as(u32, 1) << @intCast(count)) - 1);
            return result;
        }

        pub fn readByte(self: *Self) !u8 {
            return @intCast(try self.readBits(8));
        }

        pub fn readBytes(self: *Self, buffer: []u8) !usize {
            for (buffer) |*b| {
                b.* = try self.readByte();
            }
            return buffer.len;
        }
    };
}

// Custom DummyReader to replace std.io.fixedBufferStream for testing
const DummyReader = struct {
    data: []const u8,
    pos: usize,
    
    pub fn init(data: []const u8) DummyReader {
        return .{ .data = data, .pos = 0 };
    }
    
    pub fn readByte(self: *DummyReader) !u8 {
        if (self.pos >= self.data.len) return error.EndOfStream;
        const b = self.data[self.pos];
        self.pos += 1;
        return b;
    }
};

test "BitReader - Read Exact Bits" {
    const data = [_]u8{ 0xAB, 0xCD, 0xEF };
    var reader = DummyReader.init(&data);
    var decompressor = Bzip2Decompressor(*DummyReader).init(std.testing.allocator, &reader);

    const b1 = try decompressor.bit_reader.readBits(4);
    try std.testing.expectEqual(@as(u32, 10), b1);

    const b2 = try decompressor.bit_reader.readBits(8);
    try std.testing.expectEqual(@as(u32, 188), b2);
    
    const b3 = try decompressor.bit_reader.readBits(4);
    try std.testing.expectEqual(@as(u32, 13), b3);
}

test "HuffmanEngine - Invalid Trees Boundary" {
    const data = [_]u8{ 0x00, 0x00 };
    var reader = DummyReader.init(&data);
    var decompressor = Bzip2Decompressor(*DummyReader).init(std.testing.allocator, &reader);

    var engine = HuffmanEngine(*DummyReader){};
    const err = engine.decodeLengths(&decompressor.bit_reader, 50);
    try std.testing.expectError(error.InvalidHuffmanTrees, err);
}
