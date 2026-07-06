const std = @import("std");
const sequence = @import("../sequence/sequence.zig");

/// Nucleotide representation for 2-bit DNA.
pub const Nucleotide = enum(u2) {
    A = 0b00,
    C = 0b01,
    G = 0b10,
    T = 0b11,
};

/// IUPAC Ambiguity Codes for 4-bit DNA.
/// Using bitmasks where A=1, C=2, G=4, T=8.
pub const IUPAC = enum(u4) {
    A = 1,
    C = 2,
    G = 4,
    T = 8,
    R = 1 | 4,       // A or G
    Y = 2 | 8,       // C or T
    S = 2 | 4,       // G or C
    W = 1 | 8,       // A or T
    K = 4 | 8,       // G or T
    M = 1 | 2,       // A or C
    B = 2 | 4 | 8,   // C or G or T
    D = 1 | 4 | 8,   // A or G or T
    H = 1 | 2 | 8,   // A or C or T
    V = 1 | 2 | 4,   // A or C or G
    N = 1 | 2 | 4 | 8, // Any base
};

const NucLookup = struct {
    table: [256]u8,
    const invalid = 255;
    
    fn init() [256]u8 {
        var t = [_]u8{invalid} ** 256;
        t['A'] = @intFromEnum(Nucleotide.A); t['a'] = @intFromEnum(Nucleotide.A);
        t['C'] = @intFromEnum(Nucleotide.C); t['c'] = @intFromEnum(Nucleotide.C);
        t['G'] = @intFromEnum(Nucleotide.G); t['g'] = @intFromEnum(Nucleotide.G);
        t['T'] = @intFromEnum(Nucleotide.T); t['t'] = @intFromEnum(Nucleotide.T);
        return t;
    }
};
const nuc_table = NucLookup.init();

pub fn charToNucleotide(c: u8) !Nucleotide {
    const val = nuc_table[c];
    if (val == NucLookup.invalid) return error.InvalidNucleotide;
    return @as(Nucleotide, @enumFromInt(val));
}

const nuc_char_map = [_]u8{ '?', 'A', 'C', '?', 'G', '?', '?', '?', 'T' };

pub fn nucleotideToChar(n: Nucleotide) u8 {
    return nuc_char_map[@intFromEnum(n)];
}

const IupacLookup = struct {
    table: [256]u8,
    const invalid = 255;
    
    fn init() [256]u8 {
        var t = [_]u8{invalid} ** 256;
        t['A'] = @intFromEnum(IUPAC.A); t['a'] = @intFromEnum(IUPAC.A);
        t['C'] = @intFromEnum(IUPAC.C); t['c'] = @intFromEnum(IUPAC.C);
        t['G'] = @intFromEnum(IUPAC.G); t['g'] = @intFromEnum(IUPAC.G);
        t['T'] = @intFromEnum(IUPAC.T); t['t'] = @intFromEnum(IUPAC.T);
        t['U'] = @intFromEnum(IUPAC.T); t['u'] = @intFromEnum(IUPAC.T);
        t['R'] = @intFromEnum(IUPAC.R); t['r'] = @intFromEnum(IUPAC.R);
        t['Y'] = @intFromEnum(IUPAC.Y); t['y'] = @intFromEnum(IUPAC.Y);
        t['S'] = @intFromEnum(IUPAC.S); t['s'] = @intFromEnum(IUPAC.S);
        t['W'] = @intFromEnum(IUPAC.W); t['w'] = @intFromEnum(IUPAC.W);
        t['K'] = @intFromEnum(IUPAC.K); t['k'] = @intFromEnum(IUPAC.K);
        t['M'] = @intFromEnum(IUPAC.M); t['m'] = @intFromEnum(IUPAC.M);
        t['B'] = @intFromEnum(IUPAC.B); t['b'] = @intFromEnum(IUPAC.B);
        t['D'] = @intFromEnum(IUPAC.D); t['d'] = @intFromEnum(IUPAC.D);
        t['H'] = @intFromEnum(IUPAC.H); t['h'] = @intFromEnum(IUPAC.H);
        t['V'] = @intFromEnum(IUPAC.V); t['v'] = @intFromEnum(IUPAC.V);
        t['N'] = @intFromEnum(IUPAC.N); t['n'] = @intFromEnum(IUPAC.N);
        return t;
    }
};
const iupac_table = IupacLookup.init();

pub fn charToIUPAC(c: u8) !IUPAC {
    const val = iupac_table[c];
    if (val == IupacLookup.invalid) return error.InvalidIUPACCode;
    return @as(IUPAC, @enumFromInt(val));
}

const iupac_char_map = [_]u8{
    '?', 'A', 'C', 'M', 'G', 'R', 'S', 'V', 'T', 'W', 'Y', 'H', 'K', 'D', 'B', 'N'
};

pub fn iupacToChar(i: IUPAC) u8 {
    return iupac_char_map[@intFromEnum(i)];
}

/// 2-bit packed DNA representation.
pub const DNA2 = struct {
    bytes: []u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(str: []const u8, allocator: std.mem.Allocator) !DNA2 {
        const num_bytes = (str.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var self = DNA2{
            .bytes = bytes,
            .len = str.len,
            .allocator = allocator,
        };
        const p = self.packer();
        for (str, 0..) |char, i| {
            const n = try charToNucleotide(char);
            p.set(i, @intFromEnum(n));
        }
        return self;
    }

    pub fn deinit(self: *DNA2) void {
        self.allocator.free(self.bytes);
    }

    pub fn view(self: DNA2) DNA2View {
        return .{
            .bytes = self.bytes,
            .start = 0,
            .len = self.len,
        };
    }

    pub fn get(self: DNA2, index: usize) Nucleotide {
        return self.view().get(index);
    }

    pub fn slice(self: DNA2, start: usize, end: usize) DNA2View {
        return self.view().slice(start, end);
    }

    pub fn packer(self: DNA2) @import("core").bitpacking.PackedIntArray(2) {
        return @import("core").bitpacking.PackedIntArray(2).init(self.bytes, self.len);
    }
};

/// Read-only zero-copy view of a DNA2 sequence.
pub const DNA2View = struct {
    bytes: []const u8,
    start: usize,
    len: usize,

    pub fn get(self: DNA2View, index: usize) Nucleotide {
        std.debug.assert(index < self.len);
        const bit_offset = (self.start + index) * 2;
        const byte_index = bit_offset / 8;
        const bit_shift = @as(u3, @truncate(bit_offset % 8));
        const mask = @as(u32, 0b11);
        var val: u32 = self.bytes[byte_index];
        if (@as(usize, bit_shift) + 2 > 8) {
            val |= @as(u32, self.bytes[byte_index + 1]) << 8;
        }
        const enum_val = @as(u2, @truncate((val >> bit_shift) & mask));
        return @enumFromInt(enum_val);
    }

    pub fn slice(self: DNA2View, start: usize, end: usize) DNA2View {
        std.debug.assert(start <= end and end <= self.len);
        return .{
            .bytes = self.bytes,
            .start = self.start + start,
            .len = end - start,
        };
    }

    pub fn iterator(self: DNA2View) sequence.Iterator(DNA2View) {
        return .{ .seq = self };
    }

    pub fn reverse(self: DNA2View, allocator: std.mem.Allocator) !DNA2 {
        const num_bytes = (self.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA2{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(self.get(self.len - 1 - i)));
        }
        return res;
    }

    pub fn complement(self: DNA2View, allocator: std.mem.Allocator) !DNA2 {
        const num_bytes = (self.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA2{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            const val = @intFromEnum(self.get(i));
            packer.set(i, ~val);
        }
        return res;
    }

    pub fn reverseComplement(self: DNA2View, allocator: std.mem.Allocator) !DNA2 {
        const num_bytes = (self.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA2{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            const val = @intFromEnum(self.get(self.len - 1 - i));
            packer.set(i, ~val);
        }
        return res;
    }

    pub fn equals(self: DNA2View, other: DNA2View) bool {
        return sequence.equal(self, other);
    }

    pub fn hash(self: DNA2View) u64 {
        return sequence.hash(self);
    }

    pub fn gcContent(self: DNA2View) f64 {
        if (self.len == 0) return 0.0;
        var gc_count: usize = 0;

        if (self.start % 4 == 0) {
            const bytes_len = self.len / 4;
            const seq_bytes = self.bytes[self.start / 4 .. (self.start / 4) + bytes_len];

            var i: usize = 0;
            // Process in 64-bit (8-byte) chunks
            while (i + 8 <= seq_bytes.len) : (i += 8) {
                const word = std.mem.readInt(u64, seq_bytes[i .. i + 8][0..8], .little);
                const gc_bits = (word ^ (word >> 1)) & 0x5555555555555555;
                gc_count += @popCount(gc_bits);
            }

            // Process remaining bytes
            for (seq_bytes[i..]) |byte_val| {
                const gc_bits = (byte_val ^ (byte_val >> 1)) & 0x55;
                gc_count += @popCount(@as(u8, @truncate(gc_bits)));
            }

            // Remainder
            for (bytes_len * 4 .. self.len) |idx| {
                const n = self.get(idx);
                if (n == .G or n == .C) {
                    gc_count += 1;
                }
            }
        } else {
            // Scalar fallback
            for (0..self.len) |idx| {
                const n = self.get(idx);
                if (n == .G or n == .C) {
                    gc_count += 1;
                }
            }
        }
        return @as(f64, @floatFromInt(gc_count)) / @as(f64, @floatFromInt(self.len));
    }

    pub const Counts = struct {
        a: usize = 0,
        c: usize = 0,
        g: usize = 0,
        t: usize = 0,
    };

    pub fn counts(self: DNA2View) Counts {
        var res = Counts{};
        for (0..self.len) |i| {
            switch (self.get(i)) {
                .A => res.a += 1,
                .C => res.c += 1,
                .G => res.g += 1,
                .T => res.t += 1,
            }
        }
        return res;
    }

    pub fn kmers(self: DNA2View, k: usize) sequence.KmerIterator(DNA2View) {
        return .{ .view = self, .k = k };
    }

    pub fn serialize(self: DNA2View, writer: anytype) !void {
        const serializeBinary = @import("core").serialization.serialize;
        try serializeBinary(writer, @as(u64, self.len));
        var byte_val: u8 = 0;
        for (0..self.len) |i| {
            const bit_idx = i % 4;
            const n = self.get(i);
            byte_val |= @as(u8, @intFromEnum(n)) << @as(u3, @truncate(bit_idx * 2));
            if (bit_idx == 3 or i == self.len - 1) {
                try writer.writeByte(byte_val);
                byte_val = 0;
            }
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !DNA2 {
        const deserializeBinary = @import("core").serialization.deserialize;
        const len = try deserializeBinary(reader, u64, allocator);
        const num_bytes = (len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA2{ .bytes = bytes, .len = len, .allocator = allocator };
        const p = res.packer();

        var byte_val: u8 = 0;
        for (0..len) |i| {
            const bit_idx = i % 4;
            if (bit_idx == 0) {
                var b: [1]u8 = undefined;
                try reader.readSliceAll(&b);
                byte_val = b[0];
            }
            const n_val = @as(u2, @truncate(byte_val >> @as(u3, @truncate(bit_idx * 2))));
            p.set(i, n_val);
        }
        return res;
    }
};

/// 4-bit packed IUPAC DNA representation.
pub const DNA4 = struct {
    bytes: []u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(str: []const u8, allocator: std.mem.Allocator) !DNA4 {
        const num_bytes = (str.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var self = DNA4{
            .bytes = bytes,
            .len = str.len,
            .allocator = allocator,
        };
        const p = self.packer();
        for (str, 0..) |char, i| {
            const val = try charToIUPAC(char);
            p.set(i, @intFromEnum(val));
        }
        return self;
    }

    pub fn deinit(self: *DNA4) void {
        self.allocator.free(self.bytes);
    }

    pub fn view(self: DNA4) DNA4View {
        return .{
            .bytes = self.bytes,
            .start = 0,
            .len = self.len,
        };
    }

    pub fn get(self: DNA4, index: usize) IUPAC {
        return self.view().get(index);
    }

    pub fn slice(self: DNA4, start: usize, end: usize) DNA4View {
        return self.view().slice(start, end);
    }

    pub fn packer(self: DNA4) @import("core").bitpacking.PackedIntArray(4) {
        return @import("core").bitpacking.PackedIntArray(4).init(self.bytes, self.len);
    }
};

/// Read-only zero-copy view of a DNA4 sequence.
pub const DNA4View = struct {
    bytes: []const u8,
    start: usize,
    len: usize,

    pub fn get(self: DNA4View, index: usize) IUPAC {
        std.debug.assert(index < self.len);
        const bit_offset = (self.start + index) * 4;
        const byte_index = bit_offset / 8;
        const bit_shift = @as(u3, @truncate(bit_offset % 8));
        const mask = @as(u32, 0b1111);
        var val: u32 = self.bytes[byte_index];
        if (@as(usize, bit_shift) + 4 > 8) {
            val |= @as(u32, self.bytes[byte_index + 1]) << 8;
        }
        const enum_val = @as(u4, @truncate((val >> bit_shift) & mask));
        return @enumFromInt(enum_val);
    }

    pub fn slice(self: DNA4View, start: usize, end: usize) DNA4View {
        std.debug.assert(start <= end and end <= self.len);
        return .{
            .bytes = self.bytes,
            .start = self.start + start,
            .len = end - start,
        };
    }

    pub fn iterator(self: DNA4View) sequence.Iterator(DNA4View) {
        return .{ .seq = self };
    }

    pub fn reverse(self: DNA4View, allocator: std.mem.Allocator) !DNA4 {
        const num_bytes = (self.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA4{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(self.get(self.len - 1 - i)));
        }
        return res;
    }

    pub fn complement(self: DNA4View, allocator: std.mem.Allocator) !DNA4 {
        const num_bytes = (self.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA4{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(complementIUPAC(self.get(i))));
        }
        return res;
    }

    pub fn reverseComplement(self: DNA4View, allocator: std.mem.Allocator) !DNA4 {
        const num_bytes = (self.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA4{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(complementIUPAC(self.get(self.len - 1 - i))));
        }
        return res;
    }

    pub fn complementIUPAC(i: IUPAC) IUPAC {
        const val = @intFromEnum(i);
        var res: u4 = 0;
        if (val & 0b0001 != 0) res |= 0b1000;
        if (val & 0b0010 != 0) res |= 0b0100;
        if (val & 0b0100 != 0) res |= 0b0010;
        if (val & 0b1000 != 0) res |= 0b0001;
        return @enumFromInt(res);
    }

    pub fn equals(self: DNA4View, other: DNA4View) bool {
        return sequence.equal(self, other);
    }

    pub fn hash(self: DNA4View) u64 {
        return sequence.hash(self);
    }

    pub fn gcContent(self: DNA4View) f64 {
        if (self.len == 0) return 0.0;
        var gc_weight: f64 = 0.0;
        for (0..self.len) |i| {
            gc_weight += getGCWeight(self.get(i));
        }
        return gc_weight / @as(f64, @floatFromInt(self.len));
    }

    fn getGCWeight(i: IUPAC) f64 {
        return switch (i) {
            .A, .T => 0.0,
            .C, .G, .S => 1.0,
            .R, .Y, .K, .M, .N => 0.5,
            .W => 0.0,
            .B, .V => 2.0 / 3.0,
            .D, .H => 1.0 / 3.0,
        };
    }

    pub const Counts = struct {
        a: usize = 0,
        c: usize = 0,
        g: usize = 0,
        t: usize = 0,
        other: usize = 0,
    };

    pub fn counts(self: DNA4View) Counts {
        var res = Counts{};
        for (0..self.len) |i| {
            switch (self.get(i)) {
                .A => res.a += 1,
                .C => res.c += 1,
                .G => res.g += 1,
                .T => res.t += 1,
                else => res.other += 1,
            }
        }
        return res;
    }

    pub fn kmers(self: DNA4View, k: usize) sequence.KmerIterator(DNA4View) {
        return .{ .view = self, .k = k };
    }

    pub fn serialize(self: DNA4View, writer: anytype) !void {
        const serializeBinary = @import("core").serialization.serialize;
        try serializeBinary(writer, @as(u64, self.len));
        var byte_val: u8 = 0;
        for (0..self.len) |i| {
            const bit_idx = i % 2;
            const n = self.get(i);
            byte_val |= @as(u8, @intFromEnum(n)) << @as(u3, @truncate(bit_idx * 4));
            if (bit_idx == 1 or i == self.len - 1) {
                try writer.writeByte(byte_val);
                byte_val = 0;
            }
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !DNA4 {
        const deserializeBinary = @import("core").serialization.deserialize;
        const len = try deserializeBinary(reader, u64, allocator);
        const num_bytes = (len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = DNA4{ .bytes = bytes, .len = len, .allocator = allocator };
        const p = res.packer();

        var byte_val: u8 = 0;
        for (0..len) |i| {
            const bit_idx = i % 2;
            if (bit_idx == 0) {
                var b: [1]u8 = undefined;
                try reader.readSliceAll(&b);
                byte_val = b[0];
            }
            const n_val = @as(u4, @truncate(byte_val >> @as(u3, @truncate(bit_idx * 4))));
            p.set(i, n_val);
        }
        return res;
    }
};
