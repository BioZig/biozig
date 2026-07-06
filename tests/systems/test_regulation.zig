const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const reg = systems.regulation;

test "RegulatoryGraph - Node addition" {
    const alloc = testing.allocator;
    var graph = reg.RegulatoryGraph.init(alloc);
    defer graph.deinit();
    
    _ = try graph.addNode("G1");
    try testing.expectEqual(@as(usize, 1), graph.nodes.items.len);
}

test "RegulatoryGraph - Directed activation" {
    const alloc = testing.allocator;
    var graph = reg.RegulatoryGraph.init(alloc);
    defer graph.deinit();
    
    _ = try graph.addNode("G1");
    _ = try graph.addNode("G2");
    try graph.addInteraction("G1", "G2", .Activation, 0.5);
    
    const t = graph.getTargets("G1");
    try testing.expect(t != null);
    try testing.expectEqual(@as(usize, 1), t.?.len);
}

test "RegulatoryGraph - Cyclic feedback loop" {
    const alloc = testing.allocator;
    var graph = reg.RegulatoryGraph.init(alloc);
    defer graph.deinit();
    
    _ = try graph.addNode("G1");
    _ = try graph.addNode("G2");
    try graph.addInteraction("G1", "G2", .Activation, 0.5);
    try graph.addInteraction("G2", "G1", .Repression, 0.9);
    
    const r = graph.getRegulators("G1");
    try testing.expect(r != null);
    try testing.expectEqual(@as(usize, 1), r.?.len);
}
