const std = @import("std");
const testing = std.testing;
const cellular = @import("cellular");
const cellcycle = cellular.cellcycle;

test "CellCycle - G1 Phase Assignment" {
    const phase = cellcycle.Utils.assignPhase(100.0, 0.0, 0.0);
    try testing.expect(phase == .G1);
}

test "CellCycle - State Initialization" {
    const alloc = testing.allocator;
    var state = cellcycle.State.init(alloc, .S);
    defer state.deinit();
    try testing.expect(state.phase == .S);
}

test "CellCycle - State Metadata Overwrite" {
    const alloc = testing.allocator;
    var state = cellcycle.State.init(alloc, .G2);
    defer state.deinit();

    try state.addMetadata("Score", "99.9");
    try testing.expectEqualStrings("99.9", state.metadata.get("Score").?);
}
