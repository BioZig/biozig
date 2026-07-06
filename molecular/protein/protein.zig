const std = @import("std");
const sequence = @import("../sequence/sequence.zig");
const codon_mod = @import("../codon/codon.zig");

pub const AminoAcid = codon_mod.AminoAcid;
pub const charToAminoAcid = codon_mod.charToAminoAcid;
pub const aminoAcidToChar = codon_mod.aminoAcidToChar;

/// Biochemically accepted average residue weights (in Daltons, Da) representing amino acid residues minus H2O.
/// Terminal water (18.01524 Da) is added at the chain level.
/// Source: IUPAC Commission on Isotopic Abundances and Atomic Weights.
pub const residue_weights = struct {
    pub const A: f64 = 71.0788;
    pub const C: f64 = 103.1388;
    pub const D: f64 = 115.0886;
    pub const E: f64 = 129.1155;
    pub const F: f64 = 147.1766;
    pub const G: f64 = 57.0519;
    pub const H: f64 = 137.1411;
    pub const I: f64 = 113.1594;
    pub const K: f64 = 128.1741;
    pub const L: f64 = 113.1594;
    pub const M: f64 = 131.1986;
    pub const N: f64 = 114.1039;
    pub const P: f64 = 97.1167;
    pub const Q: f64 = 128.1307;
    pub const R: f64 = 156.1875;
    pub const S: f64 = 87.0782;
    pub const T: f64 = 101.1051;
    pub const V: f64 = 99.1326;
    pub const W: f64 = 186.2132;
    pub const Y: f64 = 163.1760;
    pub const X: f64 = 110.0; // Average residue weight of canonical AAs
    pub const Gap: f64 = 0.0;
    pub const Stop: f64 = 0.0;
};

pub fn getResidueWeight(aa: AminoAcid) f64 {
    return switch (aa) {
        .A => residue_weights.A,
        .C => residue_weights.C,
        .D => residue_weights.D,
        .E => residue_weights.E,
        .F => residue_weights.F,
        .G => residue_weights.G,
        .H => residue_weights.H,
        .I => residue_weights.I,
        .K => residue_weights.K,
        .L => residue_weights.L,
        .M => residue_weights.M,
        .N => residue_weights.N,
        .P => residue_weights.P,
        .Q => residue_weights.Q,
        .R => residue_weights.R,
        .S => residue_weights.S,
        .T => residue_weights.T,
        .V => residue_weights.V,
        .W => residue_weights.W,
        .Y => residue_weights.Y,
        .X => residue_weights.X,
        .Gap => residue_weights.Gap,
        .Stop => residue_weights.Stop,
    };
}

/// 5-bit packed Protein representation.
pub const Protein = struct {
    bytes: []u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(str: []const u8, allocator: std.mem.Allocator) !Protein {
        const num_bytes = (str.len * 5 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var self = Protein{
            .bytes = bytes,
            .len = str.len,
            .allocator = allocator,
        };
        const p = self.packer();
        for (str, 0..) |char, i| {
            const val = try charToAminoAcid(char);
            p.set(i, @intFromEnum(val));
        }
        return self;
    }

    pub fn deinit(self: *Protein) void {
        self.allocator.free(self.bytes);
    }

    pub fn view(self: Protein) ProteinView {
        return .{
            .bytes = self.bytes,
            .start = 0,
            .len = self.len,
        };
    }

    pub fn get(self: Protein, index: usize) AminoAcid {
        return self.view().get(index);
    }

    pub fn slice(self: Protein, start: usize, end: usize) ProteinView {
        return self.view().slice(start, end);
    }

    pub fn packer(self: Protein) @import("core").bitpacking.PackedIntArray(5) {
        return @import("core").bitpacking.PackedIntArray(5).init(self.bytes, self.len);
    }
};

/// Read-only zero-copy view of a Protein sequence.
pub const ProteinView = struct {
    bytes: []const u8,
    start: usize,
    len: usize,

    pub fn get(self: ProteinView, index: usize) AminoAcid {
        std.debug.assert(index < self.len);
        const bit_offset = (self.start + index) * 5;
        const byte_index = bit_offset / 8;
        const bit_shift = @as(u3, @truncate(bit_offset % 8));
        const mask = @as(u32, 0b11111);
        var val: u32 = self.bytes[byte_index];
        if (@as(usize, bit_shift) + 5 > 8) {
            val |= @as(u32, self.bytes[byte_index + 1]) << 8;
            if (@as(usize, bit_shift) + 5 > 16) {
                val |= @as(u32, self.bytes[byte_index + 2]) << 16;
            }
        }
        const enum_val = @as(u5, @truncate((val >> bit_shift) & mask));
        return @enumFromInt(enum_val);
    }

    pub fn slice(self: ProteinView, start: usize, end: usize) ProteinView {
        std.debug.assert(start <= end and end <= self.len);
        return .{
            .bytes = self.bytes,
            .start = self.start + start,
            .len = end - start,
        };
    }

    pub fn iterator(self: ProteinView) sequence.Iterator(ProteinView) {
        return .{ .seq = self };
    }

    pub fn equals(self: ProteinView, other: ProteinView) bool {
        return sequence.equal(self, other);
    }

    pub fn hash(self: ProteinView) u64 {
        return sequence.hash(self);
    }

    pub fn sequenceLength(self: ProteinView) usize {
        return self.len;
    }

    /// Calculates molecular weight of the protein chain in Daltons (Da).
    /// Adds 18.01524 Da for terminal H2O group.
    pub fn molecularWeight(self: ProteinView) f64 {
        if (self.len == 0) return 0.0;
        var total: f64 = 0.0;
        for (0..self.len) |i| {
            total += getResidueWeight(self.get(i));
        }
        return total + 18.01524;
    }

    pub const Counts = [24]usize;

    pub fn counts(self: ProteinView) Counts {
        var res = [_]usize{0} ** 24;
        for (0..self.len) |i| {
            const idx = @intFromEnum(self.get(i));
            res[idx] += 1;
        }
        return res;
    }

    pub const Analysis = struct {
        frequencies: [24]f64,
    };

    pub fn compositionAnalysis(self: ProteinView) Analysis {
        var res = Analysis{ .frequencies = [_]f64{0.0} ** 24 };
        if (self.len == 0) return res;
        const raw_counts = self.counts();
        const total_len_f = @as(f64, @floatFromInt(self.len));
        for (0..24) |i| {
            res.frequencies[i] = @as(f64, @floatFromInt(raw_counts[i])) / total_len_f;
        }
        return res;
    }

    pub fn residueFrequency(self: ProteinView, aa: AminoAcid) f64 {
        if (self.len == 0) return 0.0;
        const raw_counts = self.counts();
        return @as(f64, @floatFromInt(raw_counts[@intFromEnum(aa)])) / @as(f64, @floatFromInt(self.len));
    }

    pub fn serialize(self: ProteinView, writer: anytype) !void {
        const serializeBinary = @import("core").serialization.serialize;
        try serializeBinary(writer, @as(u64, self.len));
        var byte_val: u8 = 0;
        for (0..self.len) |i| {
            const bit_offset = i * 5;
            const bit_idx = bit_offset % 8;
            const n = self.get(i);

            // Set bits in byte_val. Since a 5-bit value can cross byte boundaries, we pack carefully:
            // Write element to temporary u16 shifted by bit_idx, then merge
            const temp = @as(u16, @intFromEnum(n)) << @as(u4, @truncate(bit_idx));
            byte_val |= @as(u8, @truncate(temp & 0xFF));

            // If the next element will cross or if this is the last element, flush
            const next_bit_idx = (i + 1) * 5 % 8;
            if (next_bit_idx < bit_idx or i == self.len - 1) {
                try writer.writeByte(byte_val);
                byte_val = 0;
                // If it spanned across a byte, we capture the remaining bits for the next byte
                if (bit_idx + 5 > 8) {
                    byte_val = @as(u8, @truncate((temp >> 8) & 0xFF));
                }
            }
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Protein {
        const deserializeBinary = @import("core").serialization.deserialize;
        const len = try deserializeBinary(reader, u64, allocator);
        const num_bytes = (len * 5 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = Protein{ .bytes = bytes, .len = len, .allocator = allocator };
        const p = res.packer();

        var byte_val: u8 = 0;
        var next_byte_val: u8 = 0;
        for (0..len) |i| {
            const bit_offset = i * 5;
            const bit_idx = bit_offset % 8;
            if (bit_idx == 0) {
                var b: [1]u8 = undefined;
                try reader.readSliceAll(&b);
                byte_val = b[0];
            } else if (bit_idx + 5 > 8 and bit_offset + 5 <= len * 5) {
                var b: [1]u8 = undefined;
                try reader.readSliceAll(&b);
                next_byte_val = b[0];
            }

            var val = @as(u16, byte_val);
            if (bit_idx + 5 > 8) {
                val |= @as(u16, next_byte_val) << 8;
                byte_val = next_byte_val;
            }

            const n_val = @as(u5, @truncate((val >> @as(u4, @truncate(bit_idx))) & 0x1F));
            p.set(i, n_val);
        }
        return res;
    }
};
