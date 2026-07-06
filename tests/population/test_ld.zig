const std = @import("std");
const pop = @import("population");
const ld = pop.ld;

test "LinkageDisequilibriumRecord - valid init and deinit" {
    const alloc = std.testing.allocator;
    var record = try ld.LinkageDisequilibriumRecord.init(alloc, "rs101", "rs102", 0.75, -0.5);
    defer record.deinit();

    try std.testing.expectEqualStrings("rs101", record.locus_a);
    try std.testing.expectEqualStrings("rs102", record.locus_b);
    try std.testing.expectEqual(@as(f64, 0.75), record.r_squared);
    try std.testing.expectEqual(@as(f64, -0.5), record.d_prime);
}

test "LinkageDisequilibriumRecord - metadata" {
    const alloc = std.testing.allocator;
    var record = try ld.LinkageDisequilibriumRecord.init(alloc, "A", "B", 0.0, 0.0);
    defer record.deinit();

    try record.addMetadata("key1", "value1");
    try record.addMetadata("source", "dbSNP");

    try std.testing.expectEqualStrings("value1", record.metadata.get("key1").?);
    try std.testing.expectEqualStrings("dbSNP", record.metadata.get("source").?);
}

test "LinkageDisequilibriumRecord - edge cases bounds" {
    const alloc = std.testing.allocator;
    var r1 = try ld.LinkageDisequilibriumRecord.init(alloc, "A", "B", 1.0, 1.0);
    defer r1.deinit();
    try std.testing.expectEqual(@as(f64, 1.0), r1.r_squared);
    
    var r2 = try ld.LinkageDisequilibriumRecord.init(alloc, "A", "B", 0.0, -1.0);
    defer r2.deinit();
    try std.testing.expectEqual(@as(f64, -1.0), r2.d_prime);
}

test "LDMatrix - init, deinit, and set/get" {
    const alloc = std.testing.allocator;
    const loci = [_][]const u8{ "rs1", "rs2", "rs3" };
    var matrix = try ld.LDMatrix.init(alloc, @constCast(&loci));
    defer matrix.deinit();

    try std.testing.expectEqual(@as(usize, 3), matrix.size);

    matrix.set(0, 1, 0.25, 0.5);
    matrix.set(1, 2, 0.8, -0.9);

    const val01 = matrix.get(0, 1);
    try std.testing.expectEqual(@as(f64, 0.25), val01.r_squared);
    try std.testing.expectEqual(@as(f64, 0.5), val01.d_prime);

    // Symmetric check
    const val10 = matrix.get(1, 0);
    try std.testing.expectEqual(@as(f64, 0.25), val10.r_squared);
    try std.testing.expectEqual(@as(f64, 0.5), val10.d_prime);

    const val12 = matrix.get(1, 2);
    try std.testing.expectEqual(@as(f64, 0.8), val12.r_squared);
    try std.testing.expectEqual(@as(f64, -0.9), val12.d_prime);
    
    const val21 = matrix.get(2, 1);
    try std.testing.expectEqual(@as(f64, 0.8), val21.r_squared);
    try std.testing.expectEqual(@as(f64, -0.9), val21.d_prime);
    
    // Diagonal should be 0 unless set
    const val00 = matrix.get(0, 0);
    try std.testing.expectEqual(@as(f64, 0.0), val00.r_squared);
}

test "LDMatrix - edge cases" {
    const alloc = std.testing.allocator;
    const loci = [_][]const u8{ "rs1" };
    var matrix = try ld.LDMatrix.init(alloc, @constCast(&loci));
    defer matrix.deinit();
    
    matrix.set(0, 0, 1.0, 1.0);
    try std.testing.expectEqual(@as(f64, 1.0), matrix.get(0,0).r_squared);
}
