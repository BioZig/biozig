const std = @import("std");
const variant = @import("variant_alg");

const VariantParams = variant.VariantParams;

test "Variant - isMatch exact" {
    const v1 = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "T" };
    const v2 = VariantParams{ .chrom = "chr2", .pos = 100, .ref = "A", .alt = "T" };
    const v3 = VariantParams{ .chrom = "chr1", .pos = 101, .ref = "A", .alt = "T" };
    const v4 = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "C", .alt = "T" };
    const v5 = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "G" };
    
    try std.testing.expect(variant.isMatch(v1, v1));
    try std.testing.expect(!variant.isMatch(v1, v2));
    try std.testing.expect(!variant.isMatch(v1, v3));
    try std.testing.expect(!variant.isMatch(v1, v4));
    try std.testing.expect(!variant.isMatch(v1, v5));
}

test "Variant - isOverlap border cases" {
    const a = VariantParams{ .chrom = "chr1", .pos = 100, .ref = "AT", .alt = "A" }; // spans 100, 101
    const b = VariantParams{ .chrom = "chr1", .pos = 101, .ref = "G", .alt = "C" }; // starts at 101
    const c = VariantParams{ .chrom = "chr1", .pos = 102, .ref = "C", .alt = "A" }; // starts at 102
    const d = VariantParams{ .chrom = "chr2", .pos = 100, .ref = "AT", .alt = "A" }; // different chrom

    try std.testing.expect(variant.isOverlap(a, b));
    try std.testing.expect(!variant.isOverlap(a, c)); // 100..102 vs 102
    try std.testing.expect(!variant.isOverlap(a, d));
}

test "Variant - sortVariants logic" {
    var variants = [_]VariantParams{
        .{ .chrom = "chr2", .pos = 100, .ref = "A", .alt = "G" },
        .{ .chrom = "chr1", .pos = 200, .ref = "C", .alt = "T" },
        .{ .chrom = "chr1", .pos = 100, .ref = "G", .alt = "A" },
        .{ .chrom = "chr3", .pos = 50,  .ref = "T", .alt = "C" },
        .{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "C" }, // tie on chrom and pos
    };

    variant.sortVariants(&variants);

    try std.testing.expectEqualStrings("chr1", variants[0].chrom);
    try std.testing.expectEqual(@as(usize, 100), variants[0].pos);
    
    try std.testing.expectEqualStrings("chr1", variants[1].chrom);
    try std.testing.expectEqual(@as(usize, 100), variants[1].pos);
    
    try std.testing.expectEqualStrings("chr1", variants[2].chrom);
    try std.testing.expectEqual(@as(usize, 200), variants[2].pos);
    
    try std.testing.expectEqualStrings("chr2", variants[3].chrom);
    try std.testing.expectEqualStrings("chr3", variants[4].chrom);
}

const FilterTest = struct {
    fn isChr1(v: VariantParams) bool {
        return std.mem.eql(u8, v.chrom, "chr1");
    }
};

test "Variant - filterVariants" {
    const alloc = std.testing.allocator;
    const variants = [_]VariantParams{
        .{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "G" },
        .{ .chrom = "chr2", .pos = 200, .ref = "C", .alt = "T" },
    };

    const filtered = try variant.filterVariants(alloc, &variants, FilterTest.isChr1);
    defer alloc.free(filtered);

    try std.testing.expectEqual(@as(usize, 1), filtered.len);
    try std.testing.expectEqualStrings("chr1", filtered[0].chrom);
}

test "Variant - filterVariants empty" {
    const alloc = std.testing.allocator;
    const empty_variants = [_]VariantParams{};
    const filtered = try variant.filterVariants(alloc, &empty_variants, FilterTest.isChr1);
    defer alloc.free(filtered);
    try std.testing.expectEqual(@as(usize, 0), filtered.len);
}

test "Variant - computeStatistics empty and infinity" {
    const empty_variants = [_]VariantParams{};
    const s1 = variant.computeStatistics(&empty_variants);
    try std.testing.expectEqual(@as(usize, 0), s1.total_variants);
    try std.testing.expectEqual(@as(usize, 0), s1.transitions);
    try std.testing.expectEqual(@as(usize, 0), s1.transversions);
    try std.testing.expectEqual(@as(f64, 0.0), s1.ts_tv_ratio);
    
    // Only transitions -> ts_tv_ratio should be INF
    const ts_only = [_]VariantParams{
        .{ .chrom = "chr1", .pos = 100, .ref = "A", .alt = "G" },
    };
    const s2 = variant.computeStatistics(&ts_only);
    try std.testing.expect(std.math.isInf(s2.ts_tv_ratio));
}
