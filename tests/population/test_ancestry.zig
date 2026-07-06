const std = @import("std");
const pop = @import("population");
const anc = pop.ancestry;

test "Population - init and metadata" {
    const alloc = std.testing.allocator;
    var pop_obj = try anc.Population.init(alloc, "CEU", "Utah Residents");
    defer pop_obj.deinit();
    
    try std.testing.expectEqualStrings("CEU", pop_obj.id);
    try std.testing.expectEqualStrings("Utah Residents", pop_obj.name);
    
    try pop_obj.addMetadata("region", "Europe");
    try pop_obj.addMetadata("source", "1000 Genomes");
    
    try std.testing.expectEqualStrings("Europe", pop_obj.metadata.get("region").?);
}

test "PopulationRelationship - basic" {
    const alloc = std.testing.allocator;
    var rel = try anc.PopulationRelationship.init(alloc, "A", "B", 1500.5, 0.25);
    defer rel.deinit();
    
    try std.testing.expectEqualStrings("A", rel.parent_id);
    try std.testing.expectEqualStrings("B", rel.derived_id);
    try std.testing.expectEqual(@as(f64, 1500.5), rel.split_time.?);
    try std.testing.expectEqual(@as(f64, 0.25), rel.admixture_proportion.?);
}

test "AncestryGraph - build and query" {
    const alloc = std.testing.allocator;
    var graph = anc.AncestryGraph.init(alloc);
    defer graph.deinit();
    
    try graph.addPopulation(try anc.Population.init(alloc, "P1", "Pop1"));
    try graph.addPopulation(try anc.Population.init(alloc, "P2", "Pop2"));
    try graph.addPopulation(try anc.Population.init(alloc, "P3", "Pop3"));
    
    try graph.addRelationship(try anc.PopulationRelationship.init(alloc, "P1", "P2", null, null));
    try graph.addRelationship(try anc.PopulationRelationship.init(alloc, "P1", "P3", null, null));
    try graph.addRelationship(try anc.PopulationRelationship.init(alloc, "P2", "P3", null, 0.5));
    
    const p1_children = graph.getDescendants("P1").?;
    try std.testing.expectEqual(@as(usize, 2), p1_children.len);
    
    const p3_parents = graph.getAncestry("P3").?;
    try std.testing.expectEqual(@as(usize, 2), p3_parents.len); // P1 and P2
    
    try std.testing.expect(graph.getDescendants("P3") == null);
    try std.testing.expect(graph.getAncestry("P1") == null);
}

test "AncestryGraph - edge cases" {
    const alloc = std.testing.allocator;
    var graph = anc.AncestryGraph.init(alloc);
    defer graph.deinit();
    
    try std.testing.expect(graph.getDescendants("Unknown") == null);
}
