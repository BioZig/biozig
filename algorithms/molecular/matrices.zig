const std = @import("std");
const codon = @import("molecular").codon;
const matrices_data = @import("matrices_data.zig");

pub const BuiltinMatrix = matrices_data.BuiltinMatrix;

pub const SubstitutionMatrix = struct {
    matrix: [24][24]i16,
    char_map: [256]u8,

    pub fn init(matrix_type: BuiltinMatrix) SubstitutionMatrix {
        var self = SubstitutionMatrix{
            .matrix = [_][24]i16{[_]i16{0} ** 24} ** 24,
            .char_map = [_]u8{23} ** 256,
        };

        for (0..256) |i| {
            if (codon.charToAminoAcid(@as(u8, @intCast(i)))) |aa| {
                self.char_map[i] = @intFromEnum(aa);
            } else |_| {}
        }

        self.matrix = switch (matrix_type) {
            .BLOSUM45 => matrices_data.BLOSUM45_DATA,
            .BLOSUM62 => matrices_data.BLOSUM62_DATA,
            .BLOSUM80 => matrices_data.BLOSUM80_DATA,
            .PAM30 => matrices_data.PAM30_DATA,
            .PAM70 => matrices_data.PAM70_DATA,
            .PAM250 => matrices_data.PAM250_DATA,
        };
        
        return self;
    }

    pub inline fn get(self: *const SubstitutionMatrix, a: u8, b: u8) i16 {
        const idx_a = self.char_map[a];
        const idx_b = self.char_map[b];
        if (idx_a >= 24 or idx_b >= 24) return -1;
        return self.matrix[idx_a][idx_b];
    }
};
