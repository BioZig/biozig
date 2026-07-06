const std = @import("std");
const core = @import("core");

/// Basic representation of a variant to be used in algorithms.
pub const VariantParams = struct {
    chrom: []const u8,
    pos: usize, // 0-based
    ref: []const u8,
    alt: []const u8,
};

/// Compares two variants to determine if they are identical in representation.
pub fn isMatch(a: VariantParams, b: VariantParams) bool {
    return a.pos == b.pos and
           std.mem.eql(u8, a.chrom, b.chrom) and
           std.mem.eql(u8, a.ref, b.ref) and
           std.mem.eql(u8, a.alt, b.alt);
}

/// Checks if two variants overlap in genomic space.
pub fn isOverlap(a: VariantParams, b: VariantParams) bool {
    if (!std.mem.eql(u8, a.chrom, b.chrom)) return false;
    
    const a_end = a.pos + a.ref.len;
    const b_end = b.pos + b.ref.len;
    
    return a.pos < b_end and b.pos < a_end;
}

/// Sorts an array of variants in place by chromosome, then by position.
pub fn sortVariants(variants: []VariantParams) void {
    const LessThan = struct {
        fn lt(_: void, a: VariantParams, b: VariantParams) bool {
            const chrom_cmp = std.mem.order(u8, a.chrom, b.chrom);
            switch (chrom_cmp) {
                .lt => return true,
                .gt => return false,
                .eq => return a.pos < b.pos,
            }
        }
    };
    std.mem.sort(VariantParams, variants, {}, LessThan.lt);
}

/// Filters variants according to a user-provided boolean predicate function.
pub fn filterVariants(allocator: std.mem.Allocator, variants: []const VariantParams, comptime predicate: fn (VariantParams) bool) ![]VariantParams {
    var filtered = std.ArrayList(VariantParams).empty;
    errdefer filtered.deinit(allocator);

    for (variants) |v| {
        if (predicate(v)) {
            try filtered.append(allocator, v);
        }
    }

    return filtered.toOwnedSlice(allocator);
}

pub const VariantStatistics = struct {
    total_variants: usize,
    transitions: usize,
    transversions: usize,
    ts_tv_ratio: f64,
    insertions: usize,
    deletions: usize,
};

/// Computes descriptive statistics on a slice of variants.
pub fn computeStatistics(variants: []const VariantParams) VariantStatistics {
    var stats = VariantStatistics{
        .total_variants = variants.len,
        .transitions = 0,
        .transversions = 0,
        .ts_tv_ratio = 0.0,
        .insertions = 0,
        .deletions = 0,
    };

    for (variants) |v| {
        if (v.ref.len == 1 and v.alt.len == 1) {
            // SNP
            const r = v.ref[0];
            const a = v.alt[0];
            if ((r == 'A' and a == 'G') or (r == 'G' and a == 'A') or
                (r == 'C' and a == 'T') or (r == 'T' and a == 'C')) {
                stats.transitions += 1;
            } else {
                stats.transversions += 1;
            }
        } else if (v.ref.len < v.alt.len) {
            stats.insertions += 1;
        } else if (v.ref.len > v.alt.len) {
            stats.deletions += 1;
        }
    }

    if (stats.transversions > 0) {
        stats.ts_tv_ratio = @as(f64, @floatFromInt(stats.transitions)) / @as(f64, @floatFromInt(stats.transversions));
    } else if (stats.transitions > 0) {
        stats.ts_tv_ratio = std.math.inf(f64);
    }

    return stats;
}

test "Variant Algorithms - Match and Overlap" {
    const v1 = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "T" };
    const v2 = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "T" };
    const v3 = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "G" };
    const v_del = VariantParams{ .chrom = "chr1", .pos = 99, .ref = "GAC", .alt = "G" };

    try std.testing.expect(isMatch(v1, v2));
    try std.testing.expect(!isMatch(v1, v3));

    try std.testing.expect(isOverlap(v1, v3)); // Same pos, len 1
    try std.testing.expect(isOverlap(v_del, v1)); // pos 99 len 3 covers 99, 100, 101. Overlaps with 100.
}

test "Variant Algorithms - Statistics" {
    const variants = [_]VariantParams{
        .{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "G" }, // Transition
        .{ .chrom = "chr1", .pos = 200, .ref = "C", .alt = "T" }, // Transition
        .{ .chrom = "chr1", .pos = 300, .ref = "A", .alt = "T" }, // Transversion
        .{ .chrom = "chr1", .pos = 400, .ref = "A", .alt = "AT" }, // Insertion
        .{ .chrom = "chr1", .pos = 500, .ref = "AT", .alt = "A" }, // Deletion
    };

    const stats = computeStatistics(&variants);
    try std.testing.expectEqual(@as(usize, 5), stats.total_variants);
    try std.testing.expectEqual(@as(usize, 2), stats.transitions);
    try std.testing.expectEqual(@as(usize, 1), stats.transversions);
    try std.testing.expectEqual(@as(f64, 2.0), stats.ts_tv_ratio);
    try std.testing.expectEqual(@as(usize, 1), stats.insertions);
    try std.testing.expectEqual(@as(usize, 1), stats.deletions);
}
