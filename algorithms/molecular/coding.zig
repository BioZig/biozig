const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;
const Nucleotide = dna_module.Nucleotide;

const STOP_CODON = '*';

pub fn encodeCodon(c1: Nucleotide, c2: Nucleotide, c3: Nucleotide) u6 {
    return (@as(u6, @intFromEnum(c1)) << 4) | (@as(u6, @intFromEnum(c2)) << 2) | @as(u6, @intFromEnum(c3));
}

fn buildGeneticCode() [64]u8 {
    var gen_table: [64]u8 = [_]u8{'X'} ** 64;
    const map = [_]struct { seq: []const u8, aa: u8 }{
        .{ .seq = "ATA", .aa = 'I' }, .{ .seq = "ATC", .aa = 'I' }, .{ .seq = "ATT", .aa = 'I' }, .{ .seq = "ATG", .aa = 'M' },
        .{ .seq = "ACA", .aa = 'T' }, .{ .seq = "ACC", .aa = 'T' }, .{ .seq = "ACG", .aa = 'T' }, .{ .seq = "ACT", .aa = 'T' },
        .{ .seq = "AAC", .aa = 'N' }, .{ .seq = "AAT", .aa = 'N' }, .{ .seq = "AAA", .aa = 'K' }, .{ .seq = "AAG", .aa = 'K' },
        .{ .seq = "AGC", .aa = 'S' }, .{ .seq = "AGT", .aa = 'S' }, .{ .seq = "AGA", .aa = 'R' }, .{ .seq = "AGG", .aa = 'R' },
        .{ .seq = "CTA", .aa = 'L' }, .{ .seq = "CTC", .aa = 'L' }, .{ .seq = "CTG", .aa = 'L' }, .{ .seq = "CTT", .aa = 'L' },
        .{ .seq = "CCA", .aa = 'P' }, .{ .seq = "CCC", .aa = 'P' }, .{ .seq = "CCG", .aa = 'P' }, .{ .seq = "CCT", .aa = 'P' },
        .{ .seq = "CAC", .aa = 'H' }, .{ .seq = "CAT", .aa = 'H' }, .{ .seq = "CAA", .aa = 'Q' }, .{ .seq = "CAG", .aa = 'Q' },
        .{ .seq = "CGA", .aa = 'R' }, .{ .seq = "CGC", .aa = 'R' }, .{ .seq = "CGG", .aa = 'R' }, .{ .seq = "CGT", .aa = 'R' },
        .{ .seq = "GTA", .aa = 'V' }, .{ .seq = "GTC", .aa = 'V' }, .{ .seq = "GTG", .aa = 'V' }, .{ .seq = "GTT", .aa = 'V' },
        .{ .seq = "GCA", .aa = 'A' }, .{ .seq = "GCC", .aa = 'A' }, .{ .seq = "GCG", .aa = 'A' }, .{ .seq = "GCT", .aa = 'A' },
        .{ .seq = "GAC", .aa = 'D' }, .{ .seq = "GAT", .aa = 'D' }, .{ .seq = "GAA", .aa = 'E' }, .{ .seq = "GAG", .aa = 'E' },
        .{ .seq = "GGA", .aa = 'G' }, .{ .seq = "GGC", .aa = 'G' }, .{ .seq = "GGG", .aa = 'G' }, .{ .seq = "GGT", .aa = 'G' },
        .{ .seq = "TCA", .aa = 'S' }, .{ .seq = "TCC", .aa = 'S' }, .{ .seq = "TCG", .aa = 'S' }, .{ .seq = "TCT", .aa = 'S' },
        .{ .seq = "TTC", .aa = 'F' }, .{ .seq = "TTT", .aa = 'F' }, .{ .seq = "TTA", .aa = 'L' }, .{ .seq = "TTG", .aa = 'L' },
        .{ .seq = "TAC", .aa = 'Y' }, .{ .seq = "TAT", .aa = 'Y' }, .{ .seq = "TAA", .aa = '*' }, .{ .seq = "TAG", .aa = '*' },
        .{ .seq = "TGC", .aa = 'C' }, .{ .seq = "TGT", .aa = 'C' }, .{ .seq = "TGA", .aa = '*' }, .{ .seq = "TGG", .aa = 'W' },
    };
    for (map) |entry| {
        const c1 = dna_module.charToNucleotide(entry.seq[0]) catch unreachable;
        const c2 = dna_module.charToNucleotide(entry.seq[1]) catch unreachable;
        const c3 = dna_module.charToNucleotide(entry.seq[2]) catch unreachable;
        const code = encodeCodon(c1, c2, c3);
        gen_table[code] = entry.aa;
    }
    return gen_table;
}

const table = buildGeneticCode();

pub fn translateDNA(allocator: std.mem.Allocator, dna: DNA2View) ![]const u8 {
    var protein = std.ArrayList(u8).empty;
    errdefer protein.deinit(allocator);

    var i: usize = 0;
    while (i + 3 <= dna.len) : (i += 3) {
        const c1 = dna.get(i);
        const c2 = dna.get(i + 1);
        const c3 = dna.get(i + 2);
        const code = encodeCodon(c1, c2, c3);
        const aa = table[code];
        try protein.append(allocator, aa);
        if (aa == STOP_CODON) break;
    }

    return protein.toOwnedSlice(allocator);
}

pub const ORF = struct {
    start: usize,
    end: usize,
    length: usize,
    sequence: DNA2View,
};

pub fn detectORFs(allocator: std.mem.Allocator, dna: DNA2View, min_length: usize) ![]const ORF {
    var orfs = std.ArrayList(ORF).empty;
    errdefer orfs.deinit(allocator);

    const atg_code = encodeCodon(.A, .T, .G);

    for (0..3) |frame| {
        var start_pos: ?usize = null;
        var i: usize = frame;
        while (i + 3 <= dna.len) : (i += 3) {
            const code = encodeCodon(dna.get(i), dna.get(i + 1), dna.get(i + 2));
            if (code == atg_code and start_pos == null) {
                start_pos = i;
            } else if (table[code] == STOP_CODON) {
                if (start_pos) |start| {
                    const length = (i + 3) - start;
                    if (length >= min_length) {
                        try orfs.append(allocator, .{
                            .start = start,
                            .end = i + 3,
                            .length = length,
                            .sequence = dna.slice(start, i + 3),
                        });
                    }
                    start_pos = null;
                }
            }
        }
    }

    return orfs.toOwnedSlice(allocator);
}

test "Sequence Coding - Translation" {
    const alloc = std.testing.allocator;
    var seq = try dna_module.DNA2.init("ATGGCCATGGCGCCCAGAACCGAGATCGCAAGTTGA", alloc);
    defer seq.deinit();

    const protein = try translateDNA(alloc, seq.view());
    defer alloc.free(protein);

    try std.testing.expectEqualStrings("MAMAPRTEIAS*", protein);
}

test "Sequence Coding - ORF Detection" {
    const alloc = std.testing.allocator;
    var seq = try dna_module.DNA2.init("ATGGCCATGGCGCCCAGAACCGAGATCGCAAGTTGA", alloc);
    defer seq.deinit();

    const orfs = try detectORFs(alloc, seq.view(), 30);
    defer alloc.free(orfs);

    try std.testing.expectEqual(@as(usize, 1), orfs.len);
    try std.testing.expectEqual(@as(usize, 36), orfs[0].length);
}
