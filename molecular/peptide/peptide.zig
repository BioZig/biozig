const std = @import("std");
const protein_mod = @import("../protein/protein.zig");
const sequence = @import("../sequence/sequence.zig");

pub const AminoAcid = protein_mod.AminoAcid;

/// A Peptide abstraction.
pub const Peptide = struct {
    protein: protein_mod.Protein,

    pub fn init(str: []const u8, allocator: std.mem.Allocator) !Peptide {
        return .{
            .protein = try protein_mod.Protein.init(str, allocator),
        };
    }

    pub fn deinit(self: *Peptide) void {
        self.protein.deinit();
    }

    pub fn view(self: Peptide) PeptideView {
        return .{
            .p_view = self.protein.view(),
        };
    }

    pub fn get(self: Peptide, index: usize) AminoAcid {
        return self.protein.get(index);
    }
};

/// Zero-copy read-only view of a Peptide.
pub const PeptideView = struct {
    p_view: protein_mod.ProteinView,

    pub fn get(self: PeptideView, index: usize) AminoAcid {
        return self.p_view.get(index);
    }

    pub fn slice(self: PeptideView, start: usize, end: usize) PeptideView {
        return .{
            .p_view = self.p_view.slice(start, end),
        };
    }

    pub fn len(self: PeptideView) usize {
        return self.p_view.len;
    }

    pub fn molecularWeight(self: PeptideView) f64 {
        return self.p_view.molecularWeight();
    }

    pub fn composition(self: PeptideView) protein_mod.ProteinView.Analysis {
        return self.p_view.compositionAnalysis();
    }

    pub const Statistics = struct {
        len: usize,
        hydrophobic_count: usize,
        hydrophobic_fraction: f64,
        positive_count: usize,
        positive_fraction: f64,
        negative_count: usize,
        negative_fraction: f64,
        polar_count: usize,
        polar_fraction: f64,
        aliphatic_count: usize,
        aliphatic_fraction: f64,
        aromatic_count: usize,
        aromatic_fraction: f64,
    };

    pub fn statistics(self: PeptideView) Statistics {
        var stats = Statistics{
            .len = self.p_view.len,
            .hydrophobic_count = 0,
            .hydrophobic_fraction = 0.0,
            .positive_count = 0,
            .positive_fraction = 0.0,
            .negative_count = 0,
            .negative_fraction = 0.0,
            .polar_count = 0,
            .polar_fraction = 0.0,
            .aliphatic_count = 0,
            .aliphatic_fraction = 0.0,
            .aromatic_count = 0,
            .aromatic_fraction = 0.0,
        };

        if (self.p_view.len == 0) return stats;

        for (0..self.p_view.len) |i| {
            const aa = self.get(i);
            if (isHydrophobic(aa)) stats.hydrophobic_count += 1;
            if (isPositive(aa)) stats.positive_count += 1;
            if (isNegative(aa)) stats.negative_count += 1;
            if (isPolar(aa)) stats.polar_count += 1;
            if (isAliphatic(aa)) stats.aliphatic_count += 1;
            if (isAromatic(aa)) stats.aromatic_count += 1;
        }

        const len_f = @as(f64, @floatFromInt(self.p_view.len));
        stats.hydrophobic_fraction = @as(f64, @floatFromInt(stats.hydrophobic_count)) / len_f;
        stats.positive_fraction = @as(f64, @floatFromInt(stats.positive_count)) / len_f;
        stats.negative_fraction = @as(f64, @floatFromInt(stats.negative_count)) / len_f;
        stats.polar_fraction = @as(f64, @floatFromInt(stats.polar_count)) / len_f;
        stats.aliphatic_fraction = @as(f64, @floatFromInt(stats.aliphatic_count)) / len_f;
        stats.aromatic_fraction = @as(f64, @floatFromInt(stats.aromatic_count)) / len_f;

        return stats;
    }

    fn isHydrophobic(aa: AminoAcid) bool {
        return switch (aa) {
            .A, .F, .G, .I, .L, .M, .P, .V, .W, .Y => true,
            else => false,
        };
    }

    fn isPositive(aa: AminoAcid) bool {
        return switch (aa) {
            .K, .R, .H => true,
            else => false,
        };
    }

    fn isNegative(aa: AminoAcid) bool {
        return switch (aa) {
            .D, .E => true,
            else => false,
        };
    }

    fn isPolar(aa: AminoAcid) bool {
        return switch (aa) {
            .C, .N, .Q, .S, .T => true,
            else => false,
        };
    }

    fn isAliphatic(aa: AminoAcid) bool {
        return switch (aa) {
            .A, .I, .L, .P, .V => true,
            else => false,
        };
    }

    fn isAromatic(aa: AminoAcid) bool {
        return switch (aa) {
            .F, .H, .W, .Y => true,
            else => false,
        };
    }
};
