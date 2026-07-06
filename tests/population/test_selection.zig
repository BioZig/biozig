const std = @import("std");
const pop = @import("population");
const sel = pop.selection;

test "SelectionSignal - basic" {
    const alloc = std.testing.allocator;
    var sig = try sel.SelectionSignal.init(alloc, "chr1:1000", "iHS", 3.14);
    defer sig.deinit();

    try std.testing.expectEqualStrings("chr1:1000", sig.locus);
    try std.testing.expectEqualStrings("iHS", sig.statistic_name);
    try std.testing.expectEqual(@as(f64, 3.14), sig.statistic_value);

    try sig.addMetadata("p_value", "1e-5");
    try std.testing.expectEqualStrings("1e-5", sig.metadata.get("p_value").?);
}

test "SelectionCollection - build and query" {
    const alloc = std.testing.allocator;
    var col = sel.SelectionCollection.init(alloc);
    defer col.deinit();

    try col.addSignal(try sel.SelectionSignal.init(alloc, "L1", "iHS", 2.0));
    try col.addSignal(try sel.SelectionSignal.init(alloc, "L1", "FST", 0.8));
    try col.addSignal(try sel.SelectionSignal.init(alloc, "L2", "TajimaD", -1.5));

    const l1_hits = col.getByLocus("L1").?;
    try std.testing.expectEqual(@as(usize, 2), l1_hits.len);
    try std.testing.expectEqual(@as(usize, 0), l1_hits[0]);
    try std.testing.expectEqual(@as(usize, 1), l1_hits[1]);

    const l2_hits = col.getByLocus("L2").?;
    try std.testing.expectEqual(@as(usize, 1), l2_hits.len);
    try std.testing.expectEqual(@as(usize, 2), l2_hits[0]);

    try std.testing.expect(col.getByLocus("L3") == null);
}

test "SelectionCollection - NaN cases" {
    const alloc = std.testing.allocator;
    var col = sel.SelectionCollection.init(alloc);
    defer col.deinit();

    try col.addSignal(try sel.SelectionSignal.init(alloc, "L1", "iHS", std.math.nan(f64)));
    try std.testing.expect(std.math.isNan(col.signals.items[0].statistic_value));
}
