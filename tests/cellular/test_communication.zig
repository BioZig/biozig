const std = @import("std");
const testing = std.testing;
const cellular = @import("cellular");
const comm = cellular.communication;

test "Interaction - Init bounds" {
    const alloc = testing.allocator;
    var inter = try comm.Interaction.init(alloc, 0, 1, "LIG", "REC", 0.99);
    defer inter.deinit();
    try testing.expectEqual(@as(f64, 0.99), inter.score);
    try testing.expectEqual(@as(usize, 0), inter.sender_idx);
}

test "InteractionGraph - Empty Graph" {
    const alloc = testing.allocator;
    var graph = comm.InteractionGraph.init(alloc);
    defer graph.deinit();

    const res = graph.getInteractions(0, 1);
    try testing.expect(res == null);
}

test "InteractionGraph - Edge Creation" {
    const alloc = testing.allocator;
    var graph = comm.InteractionGraph.init(alloc);
    defer graph.deinit();

    const inter = try comm.Interaction.init(alloc, 10, 20, "L", "R", 1.0);
    try graph.addInteraction(inter);

    const res = graph.getInteractions(10, 20);
    try testing.expect(res != null);
    try testing.expectEqual(@as(usize, 1), res.?.len);
}
