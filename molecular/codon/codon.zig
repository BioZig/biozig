const std = @import("std");
const rna_mod = @import("../rna/rna.zig");

pub const AminoAcid = enum(u5) {
    A = 0, // Ala
    C, // Cys
    D, // Asp
    E, // Glu
    F, // Phe
    G, // Gly
    H, // His
    I, // Ile
    K, // Lys
    L, // Leu
    M, // Met
    N, // Asn
    P, // Pro
    Q, // Gln
    R, // Arg
    S, // Ser
    T, // Thr
    V, // Val
    W, // Trp
    Y, // Tyr
    X, // Unknown / Any
    Gap, // Alignment Gap
    Stop, // Translation Termination
};

pub fn charToAminoAcid(c: u8) !AminoAcid {
    return switch (c) {
        'A', 'a' => .A,
        'C', 'c' => .C,
        'D', 'd' => .D,
        'E', 'e' => .E,
        'F', 'f' => .F,
        'G', 'g' => .G,
        'H', 'h' => .H,
        'I', 'i' => .I,
        'K', 'k' => .K,
        'L', 'l' => .L,
        'M', 'm' => .M,
        'N', 'n' => .N,
        'P', 'p' => .P,
        'Q', 'q' => .Q,
        'R', 'r' => .R,
        'S', 's' => .S,
        'T', 't' => .T,
        'V', 'v' => .V,
        'W', 'w' => .W,
        'Y', 'y' => .Y,
        'X', 'x' => .X,
        '-' => .Gap,
        '*' => .Stop,
        else => error.InvalidAminoAcid,
    };
}

pub fn aminoAcidToChar(aa: AminoAcid) u8 {
    return switch (aa) {
        .A => 'A',
        .C => 'C',
        .D => 'D',
        .E => 'E',
        .F => 'F',
        .G => 'G',
        .H => 'H',
        .I => 'I',
        .K => 'K',
        .L => 'L',
        .M => 'M',
        .N => 'N',
        .P => 'P',
        .Q => 'Q',
        .R => 'R',
        .S => 'S',
        .T => 'T',
        .V => 'V',
        .W => 'W',
        .Y => 'Y',
        .X => 'X',
        .Gap => '-',
        .Stop => '*',
    };
}

/// A packed codon (triplet of nucleotides, 2-bits each, total 6-bits).
pub const Codon = struct {
    value: u6,

    pub fn init(n1: rna_mod.Nucleotide, n2: rna_mod.Nucleotide, n3: rna_mod.Nucleotide) Codon {
        return .{
            .value = @as(u6, @intFromEnum(n1)) |
                (@as(u6, @intFromEnum(n2)) << 2) |
                (@as(u6, @intFromEnum(n3)) << 4),
        };
    }

    pub fn fromString(str: []const u8) !Codon {
        if (str.len != 3) return error.InvalidCodonLength;
        const n1 = try rna_mod.charToNucleotide(str[0]);
        const n2 = try rna_mod.charToNucleotide(str[1]);
        const n3 = try rna_mod.charToNucleotide(str[2]);
        return init(n1, n2, n3);
    }

    pub fn toString(self: Codon, dest: *[3]u8) void {
        const n1: rna_mod.Nucleotide = @enumFromInt(self.value & 0b11);
        const n2: rna_mod.Nucleotide = @enumFromInt((self.value >> 2) & 0b11);
        const n3: rna_mod.Nucleotide = @enumFromInt((self.value >> 4) & 0b11);
        dest[0] = rna_mod.nucleotideToChar(n1);
        dest[1] = rna_mod.nucleotideToChar(n2);
        dest[2] = rna_mod.nucleotideToChar(n3);
    }

    pub fn toAminoAcid(self: Codon) AminoAcid {
        return codon_table[self.value];
    }
};

pub const codon_table: [64]AminoAcid = initTable();

fn initTable() [64]AminoAcid {
    var table = [_]AminoAcid{.X} ** 64;

    const Helper = struct {
        pub fn set(t: *[64]AminoAcid, codon_str: []const u8, aa: AminoAcid) void {
            const b1 = charToVal(codon_str[0]);
            const b2 = charToVal(codon_str[1]);
            const b3 = charToVal(codon_str[2]);
            const idx = b1 | (b2 << 2) | (b3 << 4);
            t[idx] = aa;
        }
        fn charToVal(c: u8) u6 {
            return switch (c) {
                'A', 'a' => 0,
                'C', 'c' => 1,
                'G', 'g' => 2,
                'U', 'u', 'T', 't' => 3,
                else => unreachable,
            };
        }
    };

    // Standard Genetic Code
    Helper.set(&table, "UUU", .F);
    Helper.set(&table, "UUC", .F);
    Helper.set(&table, "UUA", .L);
    Helper.set(&table, "UUG", .L);

    Helper.set(&table, "UCU", .S);
    Helper.set(&table, "UCC", .S);
    Helper.set(&table, "UCA", .S);
    Helper.set(&table, "UCG", .S);

    Helper.set(&table, "UAU", .Y);
    Helper.set(&table, "UAC", .Y);
    Helper.set(&table, "UAA", .Stop);
    Helper.set(&table, "UAG", .Stop);

    Helper.set(&table, "UGU", .C);
    Helper.set(&table, "UGC", .C);
    Helper.set(&table, "UGA", .Stop);
    Helper.set(&table, "UGG", .W);

    Helper.set(&table, "CUU", .L);
    Helper.set(&table, "CUC", .L);
    Helper.set(&table, "CUA", .L);
    Helper.set(&table, "CUG", .L);

    Helper.set(&table, "CCU", .P);
    Helper.set(&table, "CCC", .P);
    Helper.set(&table, "CCA", .P);
    Helper.set(&table, "CCG", .P);

    Helper.set(&table, "CAU", .H);
    Helper.set(&table, "CAC", .H);
    Helper.set(&table, "CAA", .Q);
    Helper.set(&table, "CAG", .Q);

    Helper.set(&table, "CGU", .R);
    Helper.set(&table, "CGC", .R);
    Helper.set(&table, "CGA", .R);
    Helper.set(&table, "CGG", .R);

    Helper.set(&table, "AUU", .I);
    Helper.set(&table, "AUC", .I);
    Helper.set(&table, "AUA", .I);
    Helper.set(&table, "AUG", .M);

    Helper.set(&table, "ACU", .T);
    Helper.set(&table, "ACC", .T);
    Helper.set(&table, "ACA", .T);
    Helper.set(&table, "ACG", .T);

    Helper.set(&table, "AAU", .N);
    Helper.set(&table, "AAC", .N);
    Helper.set(&table, "AAA", .K);
    Helper.set(&table, "AAG", .K);

    Helper.set(&table, "AGU", .S);
    Helper.set(&table, "AGC", .S);
    Helper.set(&table, "AGA", .R);
    Helper.set(&table, "AGG", .R);

    Helper.set(&table, "GUU", .V);
    Helper.set(&table, "GUC", .V);
    Helper.set(&table, "GUA", .V);
    Helper.set(&table, "GUG", .V);

    Helper.set(&table, "GCU", .A);
    Helper.set(&table, "GCC", .A);
    Helper.set(&table, "GCA", .A);
    Helper.set(&table, "GCG", .A);

    Helper.set(&table, "GAU", .D);
    Helper.set(&table, "GAC", .D);
    Helper.set(&table, "GAA", .E);
    Helper.set(&table, "GAG", .E);

    Helper.set(&table, "GGU", .G);
    Helper.set(&table, "GGC", .G);
    Helper.set(&table, "GGA", .G);
    Helper.set(&table, "GGG", .G);

    return table;
}

/// Returns the synonymous codons for a given amino acid.
pub fn synonymousCodons(aa: AminoAcid) @import("core").containers.FixedArray(Codon, 6) {
    var list = @import("core").containers.FixedArray(Codon, 6).init();
    for (0..64) |i| {
        if (codon_table[i] == aa) {
            list.push(Codon{ .value = @as(u6, @truncate(i)) }) catch unreachable;
        }
    }
    return list;
}
