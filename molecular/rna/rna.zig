const std = @import("std");
const sequence = @import("../sequence/sequence.zig");
const dna_mod = @import("../dna/dna.zig");

/// Nucleotide representation for 2-bit RNA.
pub const Nucleotide = enum(u2) {
    A = 0b00,
    C = 0b01,
    G = 0b10,
    U = 0b11,
};

/// IUPAC Ambiguity Codes for 4-bit RNA.
/// Using bitmasks where A=1, C=2, G=4, U=8.
pub const IUPAC = enum(u4) {
    A = 1,
    C = 2,
    G = 4,
    U = 8,
    R = 1 | 4, // A or G
    Y = 2 | 8, // C or U
    S = 2 | 4, // G or C
    W = 1 | 8, // A or U
    K = 4 | 8, // G or U
    M = 1 | 2, // A or C
    B = 2 | 4 | 8, // C or G or U
    D = 1 | 4 | 8, // A or G or U
    H = 1 | 2 | 8, // A or C or U
    V = 1 | 2 | 4, // A or C or G
    N = 1 | 2 | 4 | 8, // Any base
};

pub fn charToNucleotide(c: u8) !Nucleotide {
    return switch (c) {
        'A', 'a' => .A,
        'C', 'c' => .C,
        'G', 'g' => .G,
        'U', 'u' => .U,
        else => error.InvalidRNA_Nucleotide,
    };
}

pub fn nucleotideToChar(n: Nucleotide) u8 {
    return switch (n) {
        .A => 'A',
        .C => 'C',
        .G => 'G',
        .U => 'U',
    };
}

pub fn charToIUPAC(c: u8) !IUPAC {
    return switch (c) {
        'A', 'a' => .A,
        'C', 'c' => .C,
        'G', 'g' => .G,
        'U', 'u', 'T', 't' => .U,
        'R', 'r' => .R,
        'Y', 'y' => .Y,
        'S', 's' => .S,
        'W', 'w' => .W,
        'K', 'k' => .K,
        'M', 'm' => .M,
        'B', 'b' => .B,
        'D', 'd' => .D,
        'H', 'h' => .H,
        'V', 'v' => .V,
        'N', 'n' => .N,
        else => error.InvalidIUPACCode,
    };
}

pub fn iupacToChar(i: IUPAC) u8 {
    return switch (i) {
        .A => 'A',
        .C => 'C',
        .G => 'G',
        .U => 'U',
        .R => 'R',
        .Y => 'Y',
        .S => 'S',
        .W => 'W',
        .K => 'K',
        .M => 'M',
        .B => 'B',
        .D => 'D',
        .H => 'H',
        .V => 'V',
        .N => 'N',
    };
}

/// 2-bit packed RNA representation.
pub const RNA2 = struct {
    bytes: []u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(str: []const u8, allocator: std.mem.Allocator) !RNA2 {
        const num_bytes = (str.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var self = RNA2{
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

    pub fn deinit(self: *RNA2) void {
        self.allocator.free(self.bytes);
    }

    pub fn view(self: RNA2) RNA2View {
        return .{
            .bytes = self.bytes,
            .start = 0,
            .len = self.len,
        };
    }

    pub fn get(self: RNA2, index: usize) Nucleotide {
        return self.view().get(index);
    }

    pub fn slice(self: RNA2, start: usize, end: usize) RNA2View {
        return self.view().slice(start, end);
    }

    pub fn packer(self: RNA2) @import("core").bitpacking.PackedIntArray(2) {
        return @import("core").bitpacking.PackedIntArray(2).init(self.bytes, self.len);
    }
};

/// Read-only zero-copy view of an RNA2 sequence.
pub const RNA2View = struct {
    bytes: []const u8,
    start: usize,
    len: usize,

    pub fn get(self: RNA2View, index: usize) Nucleotide {
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

    pub fn slice(self: RNA2View, start: usize, end: usize) RNA2View {
        std.debug.assert(start <= end and end <= self.len);
        return .{
            .bytes = self.bytes,
            .start = self.start + start,
            .len = end - start,
        };
    }

    pub fn iterator(self: RNA2View) sequence.Iterator(RNA2View) {
        return .{ .seq = self };
    }

    pub fn reverse(self: RNA2View, allocator: std.mem.Allocator) !RNA2 {
        const num_bytes = (self.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA2{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(self.get(self.len - 1 - i)));
        }
        return res;
    }

    pub fn complement(self: RNA2View, allocator: std.mem.Allocator) !RNA2 {
        const num_bytes = (self.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA2{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            const val = @intFromEnum(self.get(i));
            packer.set(i, ~val);
        }
        return res;
    }

    pub fn reverseComplement(self: RNA2View, allocator: std.mem.Allocator) !RNA2 {
        const num_bytes = (self.len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA2{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            const val = @intFromEnum(self.get(self.len - 1 - i));
            packer.set(i, ~val);
        }
        return res;
    }

    pub fn equals(self: RNA2View, other: RNA2View) bool {
        return sequence.equal(self, other);
    }

    pub fn hash(self: RNA2View) u64 {
        return sequence.hash(self);
    }

    pub fn gcContent(self: RNA2View) f64 {
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
            for (bytes_len * 4..self.len) |idx| {
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
        u: usize = 0,
    };

    pub fn counts(self: RNA2View) Counts {
        var res = Counts{};
        for (0..self.len) |i| {
            switch (self.get(i)) {
                .A => res.a += 1,
                .C => res.c += 1,
                .G => res.g += 1,
                .U => res.u += 1,
            }
        }
        return res;
    }

    pub fn kmers(self: RNA2View, k: usize) sequence.KmerIterator(RNA2View) {
        return .{ .view = self, .k = k };
    }

    pub fn serialize(self: RNA2View, writer: anytype) !void {
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

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !RNA2 {
        const deserializeBinary = @import("core").serialization.deserialize;
        const len = try deserializeBinary(reader, u64, allocator);
        const num_bytes = (len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA2{ .bytes = bytes, .len = len, .allocator = allocator };
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

/// 4-bit packed IUPAC RNA representation.
pub const RNA4 = struct {
    bytes: []u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(str: []const u8, allocator: std.mem.Allocator) !RNA4 {
        const num_bytes = (str.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var self = RNA4{
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

    pub fn deinit(self: *RNA4) void {
        self.allocator.free(self.bytes);
    }

    pub fn view(self: RNA4) RNA4View {
        return .{
            .bytes = self.bytes,
            .start = 0,
            .len = self.len,
        };
    }

    pub fn get(self: RNA4, index: usize) IUPAC {
        return self.view().get(index);
    }

    pub fn slice(self: RNA4, start: usize, end: usize) RNA4View {
        return self.view().slice(start, end);
    }

    pub fn packer(self: RNA4) @import("core").bitpacking.PackedIntArray(4) {
        return @import("core").bitpacking.PackedIntArray(4).init(self.bytes, self.len);
    }
};

/// Read-only zero-copy view of an RNA4 sequence.
pub const RNA4View = struct {
    bytes: []const u8,
    start: usize,
    len: usize,

    pub fn get(self: RNA4View, index: usize) IUPAC {
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

    pub fn slice(self: RNA4View, start: usize, end: usize) RNA4View {
        std.debug.assert(start <= end and end <= self.len);
        return .{
            .bytes = self.bytes,
            .start = self.start + start,
            .len = end - start,
        };
    }

    pub fn iterator(self: RNA4View) sequence.Iterator(RNA4View) {
        return .{ .seq = self };
    }

    pub fn reverse(self: RNA4View, allocator: std.mem.Allocator) !RNA4 {
        const num_bytes = (self.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA4{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(self.get(self.len - 1 - i)));
        }
        return res;
    }

    pub fn complement(self: RNA4View, allocator: std.mem.Allocator) !RNA4 {
        const num_bytes = (self.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA4{ .bytes = bytes, .len = self.len, .allocator = allocator };
        const packer = res.packer();
        for (0..self.len) |i| {
            packer.set(i, @intFromEnum(complementIUPAC(self.get(i))));
        }
        return res;
    }

    pub fn reverseComplement(self: RNA4View, allocator: std.mem.Allocator) !RNA4 {
        const num_bytes = (self.len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA4{ .bytes = bytes, .len = self.len, .allocator = allocator };
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

    pub fn equals(self: RNA4View, other: RNA4View) bool {
        return sequence.equal(self, other);
    }

    pub fn hash(self: RNA4View) u64 {
        return sequence.hash(self);
    }

    pub fn gcContent(self: RNA4View) f64 {
        if (self.len == 0) return 0.0;
        var gc_weight: f64 = 0.0;
        for (0..self.len) |i| {
            gc_weight += getGCWeight(self.get(i));
        }
        return gc_weight / @as(f64, @floatFromInt(self.len));
    }

    fn getGCWeight(i: IUPAC) f64 {
        return switch (i) {
            .A, .U => 0.0,
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
        u: usize = 0,
        other: usize = 0,
    };

    pub fn counts(self: RNA4View) Counts {
        var res = Counts{};
        for (0..self.len) |i| {
            switch (self.get(i)) {
                .A => res.a += 1,
                .C => res.c += 1,
                .G => res.g += 1,
                .U => res.u += 1,
                else => res.other += 1,
            }
        }
        return res;
    }

    pub fn kmers(self: RNA4View, k: usize) sequence.KmerIterator(RNA4View) {
        return .{ .view = self, .k = k };
    }

    pub fn serialize(self: RNA4View, writer: anytype) !void {
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

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !RNA4 {
        const deserializeBinary = @import("core").serialization.deserialize;
        const len = try deserializeBinary(reader, u64, allocator);
        const num_bytes = (len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = RNA4{ .bytes = bytes, .len = len, .allocator = allocator };
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

/// Transcribes 2-bit DNA to 2-bit RNA.
/// This is highly optimized as a bit-equivalent memory copy.
pub fn transcribe2(dna: dna_mod.DNA2View, allocator: std.mem.Allocator) !RNA2 {
    const num_bytes = (dna.len * 2 + 7) / 8;
    const bytes = try allocator.alloc(u8, num_bytes);
    errdefer allocator.free(bytes);

    // Copy packed bits
    var i: usize = 0;
    while (i < num_bytes) : (i += 1) {
        // Find corresponding byte in dna backing slice
        const dna_bit_offset = (dna.start + i * 4) * 2;
        const dna_byte_index = dna_bit_offset / 8;
        const dna_bit_shift = @as(u3, @truncate(dna_bit_offset % 8));

        var val: u32 = dna.bytes[dna_byte_index];
        if (dna_bit_shift > 0 and dna_byte_index + 1 < dna.bytes.len) {
            val |= @as(u32, dna.bytes[dna_byte_index + 1]) << 8;
        }
        bytes[i] = @as(u8, @truncate(val >> dna_bit_shift));
    }

    return RNA2{
        .bytes = bytes,
        .len = dna.len,
        .allocator = allocator,
    };
}

/// Back-transcribes 2-bit RNA to 2-bit DNA.
pub fn backTranscribe2(rna: RNA2View, allocator: std.mem.Allocator) !dna_mod.DNA2 {
    const num_bytes = (rna.len * 2 + 7) / 8;
    const bytes = try allocator.alloc(u8, num_bytes);
    errdefer allocator.free(bytes);

    var i: usize = 0;
    while (i < num_bytes) : (i += 1) {
        const rna_bit_offset = (rna.start + i * 4) * 2;
        const rna_byte_index = rna_bit_offset / 8;
        const rna_bit_shift = @as(u3, @truncate(rna_bit_offset % 8));

        var val: u32 = rna.bytes[rna_byte_index];
        if (rna_bit_shift > 0 and rna_byte_index + 1 < rna.bytes.len) {
            val |= @as(u32, rna.bytes[rna_byte_index + 1]) << 8;
        }
        bytes[i] = @as(u8, @truncate(val >> rna_bit_shift));
    }

    return dna_mod.DNA2{
        .bytes = bytes,
        .len = rna.len,
        .allocator = allocator,
    };
}

/// Transcribes 4-bit DNA to 4-bit RNA.
pub fn transcribe4(dna: dna_mod.DNA4View, allocator: std.mem.Allocator) !RNA4 {
    const num_bytes = (dna.len * 4 + 7) / 8;
    const bytes = try allocator.alloc(u8, num_bytes);
    errdefer allocator.free(bytes);

    var i: usize = 0;
    while (i < num_bytes) : (i += 1) {
        const dna_bit_offset = (dna.start + i * 2) * 4;
        const dna_byte_index = dna_bit_offset / 8;
        const dna_bit_shift = @as(u3, @truncate(dna_bit_offset % 8));

        var val: u32 = dna.bytes[dna_byte_index];
        if (dna_bit_shift > 0 and dna_byte_index + 1 < dna.bytes.len) {
            val |= @as(u32, dna.bytes[dna_byte_index + 1]) << 8;
        }
        bytes[i] = @as(u8, @truncate(val >> dna_bit_shift));
    }

    return RNA4{
        .bytes = bytes,
        .len = dna.len,
        .allocator = allocator,
    };
}

/// Back-transcribes 4-bit RNA to 4-bit DNA.
pub fn backTranscribe4(rna: RNA4View, allocator: std.mem.Allocator) !dna_mod.DNA4 {
    const num_bytes = (rna.len * 4 + 7) / 8;
    const bytes = try allocator.alloc(u8, num_bytes);
    errdefer allocator.free(bytes);

    var i: usize = 0;
    while (i < num_bytes) : (i += 1) {
        const rna_bit_offset = (rna.start + i * 2) * 4;
        const rna_byte_index = rna_bit_offset / 8;
        const rna_bit_shift = @as(u3, @truncate(rna_bit_offset % 8));

        var val: u32 = rna.bytes[rna_byte_index];
        if (rna_bit_shift > 0 and rna_byte_index + 1 < rna.bytes.len) {
            val |= @as(u32, rna.bytes[rna_byte_index + 1]) << 8;
        }
        bytes[i] = @as(u8, @truncate(val >> rna_bit_shift));
    }

    return dna_mod.DNA4{
        .bytes = bytes,
        .len = rna.len,
        .allocator = allocator,
    };
}
