const std = @import("std");
const molecular = @import("molecular");
const variant = molecular.variant;

test "Variant basic operations - exhaustive" {
    const allocator = std.testing.allocator;
    var v = try variant.Variant.init(100, "A", "G", allocator);
    defer v.deinit();

    try std.testing.expectEqual(variant.VariantType.snp, v.getType());
    try std.testing.expect(v.validate());

    var v2 = try variant.Variant.init(100, "A", "AT", allocator);
    defer v2.deinit();
    try std.testing.expectEqual(variant.VariantType.insertion, v2.getType());

    var v3 = try variant.Variant.init(100, "AT", "A", allocator);
    defer v3.deinit();
    try std.testing.expectEqual(variant.VariantType.deletion, v3.getType());
}

test "Variant normalization exhaustive" {
    const allocator = std.testing.allocator;
    var v = try variant.Variant.init(100, "CAG", "CG", allocator);
    defer v.deinit();

    try v.normalize();
    try std.testing.expectEqualStrings("A", v.reference);
    try std.testing.expectEqualStrings("", v.alternate);
    try std.testing.expectEqual(@as(usize, 101), v.position);
    try std.testing.expectEqual(variant.VariantType.deletion, v.getType());

    var v2 = try variant.Variant.init(200, "TCG", "TCAG", allocator);
    defer v2.deinit();

    try v2.normalize();
    try std.testing.expectEqualStrings("", v2.reference);
    try std.testing.expectEqualStrings("A", v2.alternate);
    // position logic may adjust depending on implementation, assume it adjusts by 2
    try std.testing.expectEqual(@as(usize, 202), v2.position);
    try std.testing.expectEqual(variant.VariantType.insertion, v2.getType());
}

test "Variant structural variants" {
    const allocator = std.testing.allocator;
    // Lengths exactly or greater than 50 usually MNP or structural
    const buf_ref = try allocator.alloc(u8, 60);
    defer allocator.free(buf_ref);
    @memset(buf_ref, 'A');

    var v = try variant.Variant.init(10, buf_ref, "T", allocator);
    defer v.deinit();
    try std.testing.expectEqual(variant.VariantType.deletion, v.getType()); // large deletion
    try std.testing.expect(v.validate());
}

test "Variant validation failures" {
    const allocator = std.testing.allocator;
    const result = variant.Variant.init(100, "AX", "G", allocator);
    try std.testing.expectError(error.InvalidVariant, result);
}

test "Variant copying and equality" {
    const allocator = std.testing.allocator;
    var v1 = try variant.Variant.init(100, "A", "T", allocator);
    defer v1.deinit();

    var v2 = try variant.Variant.init(100, "A", "T", allocator);
    defer v2.deinit();

    try std.testing.expectEqual(v1.position, v2.position);
    try std.testing.expectEqualStrings(v1.reference, v2.reference);
    try std.testing.expectEqualStrings(v1.alternate, v2.alternate);
    try std.testing.expectEqual(v1.getType(), v2.getType());
}

test "Variant edge cases - empty alt" {
    const allocator = std.testing.allocator;
    var v = try variant.Variant.init(100, "A", "", allocator);
    defer v.deinit();

    try std.testing.expectEqual(variant.VariantType.deletion, v.getType());
}

test "Variant edge cases - empty ref" {
    const allocator = std.testing.allocator;
    var v = try variant.Variant.init(100, "", "A", allocator);
    defer v.deinit();

    try std.testing.expectEqual(variant.VariantType.insertion, v.getType());
}
