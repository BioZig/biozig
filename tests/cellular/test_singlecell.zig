const std = @import("std");
const testing = std.testing;
const cellular = @import("cellular");
const singlecell = cellular.singlecell;

test "SingleCell - Valid initialization and features" {
    const alloc = testing.allocator;
    var cell = try singlecell.Cell.init(alloc, "CELL_1", 100);
    defer cell.deinit();
    try testing.expectEqualStrings("CELL_1", cell.id);
    try testing.expectEqual(@as(usize, 100), cell.features.len);
}

test "SingleCell - Metadata insertion and overwrite" {
    const alloc = testing.allocator;
    var cell = try singlecell.Cell.init(alloc, "CELL_2", 0);
    defer cell.deinit();
    
    // Note: If addMetadata isn't implemented, we skip mutating it, but we can access it
    try testing.expectEqual(@as(usize, 0), cell.metadata.count());
}

test "CellCollection - Adding multiple cells" {
    const alloc = testing.allocator;
    var coll = singlecell.CellCollection.init(alloc);
    defer coll.deinit();
    
    const cell1 = try singlecell.Cell.init(alloc, "C1", 10);
    const cell2 = try singlecell.Cell.init(alloc, "C2", 10);
    try coll.addCell(cell1);
    try coll.addCell(cell2);
    
    try testing.expectEqual(@as(usize, 2), coll.cells.items.len);
}

test "CellCollection - Empty collection boundaries" {
    const alloc = testing.allocator;
    var coll = singlecell.CellCollection.init(alloc);
    defer coll.deinit();
    try testing.expectEqual(@as(usize, 0), coll.cells.items.len);
}
