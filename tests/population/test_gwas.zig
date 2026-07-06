const std = @import("std");
const pop = @import("population");
const gwas = pop.gwas;

test "AssociationRecord - basic" {
    const alloc = std.testing.allocator;
    var record = try gwas.AssociationRecord.init(alloc, "rs101", "height", 1e-5, 0.5, 0.4, 0.6);
    defer record.deinit();
    
    try std.testing.expectEqualStrings("rs101", record.variant_id);
    try std.testing.expectEqualStrings("height", record.trait_id);
    try std.testing.expectEqual(@as(f64, 1e-5), record.p_value);
    try std.testing.expectEqual(@as(f64, 0.5), record.effect_size);
    try std.testing.expectEqual(@as(f64, 0.4), record.ci_lower);
    try std.testing.expectEqual(@as(f64, 0.6), record.ci_upper);
}

test "AssociationRecord - NaN and extreme values" {
    const alloc = std.testing.allocator;
    var record = try gwas.AssociationRecord.init(alloc, "rsNaN", "traitNaN", std.math.nan(f64), std.math.inf(f64), -std.math.inf(f64), std.math.inf(f64));
    defer record.deinit();
    
    try std.testing.expect(std.math.isNan(record.p_value));
    try std.testing.expect(std.math.isPositiveInf(record.effect_size));
    try std.testing.expect(std.math.isNegativeInf(record.ci_lower));
}

test "AssociationCollection - basic operations" {
    const alloc = std.testing.allocator;
    var col = gwas.AssociationCollection.init(alloc);
    defer col.deinit();
    
    try col.addRecord(try gwas.AssociationRecord.init(alloc, "v1", "t1", 0.1, 1.0, 0.0, 2.0));
    try col.addRecord(try gwas.AssociationRecord.init(alloc, "v1", "t2", 0.01, -1.0, -2.0, 0.0));
    try col.addRecord(try gwas.AssociationRecord.init(alloc, "v2", "t1", 0.05, 0.5, 0.1, 0.9));
    
    const v1_hits = col.getByVariant("v1").?;
    try std.testing.expectEqual(@as(usize, 2), v1_hits.len);
    try std.testing.expectEqual(@as(usize, 0), v1_hits[0]);
    try std.testing.expectEqual(@as(usize, 1), v1_hits[1]);
    
    const t1_hits = col.getByTrait("t1").?;
    try std.testing.expectEqual(@as(usize, 2), t1_hits.len);
    try std.testing.expectEqual(@as(usize, 0), t1_hits[0]);
    try std.testing.expectEqual(@as(usize, 2), t1_hits[1]);
    
    try std.testing.expect(col.getByVariant("v3") == null);
    try std.testing.expect(col.getByTrait("t3") == null);
}

test "AssociationCollection - edge cases" {
    const alloc = std.testing.allocator;
    var col = gwas.AssociationCollection.init(alloc);
    defer col.deinit();
    
    // empty collection returns null
    try std.testing.expect(col.getByVariant("v1") == null);
}
