const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const network = systems.network;

test "Node - Initialization" {
    const alloc = testing.allocator;
    var node = try network.Node.init(alloc, "N1");
    defer node.deinit();
    try testing.expectEqualStrings("N1", node.id);
}

test "Network - Adding edges" {
    const alloc = testing.allocator;
    var net = network.Network.init(alloc);
    defer net.deinit();
    
    const n1 = try network.Node.init(alloc, "N1");
    const n2 = try network.Node.init(alloc, "N2");
    const idx1 = try net.addNode(n1);
    const idx2 = try net.addNode(n2);
    
    try net.addEdge(idx1, idx2, 1.5, true);
    try testing.expectEqual(@as(usize, 2), net.nodes.items.len);
}

test "Network - Degree Calculation after compilation" {
    const alloc = testing.allocator;
    var net = network.Network.init(alloc);
    defer net.deinit();
    
    _ = try net.addNode(try network.Node.init(alloc, "N1"));
    _ = try net.addNode(try network.Node.init(alloc, "N2"));
    try net.addEdge(0, 1, 1.0, true);
    
    var comp = try net.compile();
    defer comp.deinit();
    
    try testing.expectEqual(@as(usize, 1), comp.getOutDegree(0));
    try testing.expectEqual(@as(usize, 1), comp.getInDegree(1));
}
