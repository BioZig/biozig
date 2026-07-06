const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const kg = systems.knowledgegraph;

test "KnowledgeGraph - Entity addition" {
    const alloc = testing.allocator;
    var graph = kg.KnowledgeGraph.init(alloc);
    defer graph.deinit();
    _ = try graph.addEntity("D1", "DrugA", .Drug);
    try testing.expectEqual(@as(usize, 1), graph.entities.items.len);
}

test "KnowledgeGraph - InteractsWith Relationship" {
    const alloc = testing.allocator;
    var graph = kg.KnowledgeGraph.init(alloc);
    defer graph.deinit();
    _ = try graph.addEntity("D1", "DrugA", .Drug);
    _ = try graph.addEntity("D2", "DrugB", .Drug);
    try graph.addRelationship("D1", "D2", .InteractsWith, 1.0);
    
    const rels = graph.getRelationships("D1");
    try testing.expect(rels != null);
    try testing.expectEqual(@as(usize, 1), rels.?.len);
}

test "KnowledgeGraph - Regulates Relationship" {
    const alloc = testing.allocator;
    var graph = kg.KnowledgeGraph.init(alloc);
    defer graph.deinit();
    _ = try graph.addEntity("D1", "DrugA", .Drug);
    _ = try graph.addEntity("G1", "GeneA", .Gene);
    try graph.addRelationship("D1", "G1", .Regulates, 1.0);
    
    const rels = graph.getRelationships("D1");
    try testing.expectEqual(@as(usize, 1), rels.?.len);
}
