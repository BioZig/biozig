const std = @import("std");
const pop = @import("population");
const hap = pop.haplotype;

test "VariantRef - basic" {
    const alloc = std.testing.allocator;
    var vr = try hap.VariantRef.init(alloc, "rs1", "A");
    defer vr.deinit();
    try std.testing.expectEqualStrings("rs1", vr.variant_id);
    try std.testing.expectEqualStrings("A", vr.allele);
}

test "Haplotype - basic and addVariant" {
    const alloc = std.testing.allocator;
    var h = try hap.Haplotype.init(alloc, "hap1", "chr1", 100, 200);
    defer h.deinit();

    try std.testing.expectEqualStrings("hap1", h.id);
    try std.testing.expectEqualStrings("chr1", h.chromosome);
    try std.testing.expectEqual(@as(usize, 100), h.start_pos);
    try std.testing.expectEqual(@as(usize, 200), h.end_pos);

    try h.addVariant("v1", "A");
    try h.addVariant("v2", "T");
    try h.addVariant("v3", "C");

    try std.testing.expectEqual(@as(usize, 3), h.variants.items.len);
    try std.testing.expectEqualStrings("v2", h.variants.items[1].variant_id);
    try std.testing.expectEqualStrings("T", h.variants.items[1].allele);
}

test "HaplotypeBlock - basic" {
    const alloc = std.testing.allocator;
    var block = try hap.HaplotypeBlock.init(alloc, "chr1", 100, 500);
    defer block.deinit();

    var h1 = try hap.Haplotype.init(alloc, "h1", "chr1", 100, 200);
    try h1.addVariant("v1", "A");
    try block.addHaplotype(h1);

    const h2 = try hap.Haplotype.init(alloc, "h2", "chr1", 201, 300);
    try block.addHaplotype(h2);

    const got_h1 = block.getHaplotype("h1");
    try std.testing.expect(got_h1 != null);
    try std.testing.expectEqualStrings("h1", got_h1.?.id);
    try std.testing.expectEqual(@as(usize, 1), got_h1.?.variants.items.len);

    const got_h3 = block.getHaplotype("h3");
    try std.testing.expect(got_h3 == null);
}

test "Haplotype - edge cases" {
    const alloc = std.testing.allocator;
    var h = try hap.Haplotype.init(alloc, "", "", 0, 0);
    defer h.deinit();
    try std.testing.expectEqualStrings("", h.id);
    try std.testing.expectEqual(@as(usize, 0), h.start_pos);
}
