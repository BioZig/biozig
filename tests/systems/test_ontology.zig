const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const ontology = systems.ontology;

test "Ontology - Term creation" {
    const alloc = testing.allocator;
    var ont = ontology.Ontology.init(alloc);
    defer ont.deinit();
    _ = try ont.addTerm("GO:001", "Cell");
    try testing.expectEqual(@as(usize, 1), ont.terms.items.len);
}

test "Ontology - Relationships" {
    const alloc = testing.allocator;
    var ont = ontology.Ontology.init(alloc);
    defer ont.deinit();
    _ = try ont.addTerm("GO:001", "A");
    _ = try ont.addTerm("GO:002", "B");
    try ont.addRelationship("GO:001", "GO:002");
    try testing.expectEqual(@as(usize, 1), ont.children.count());
}

test "Ontology - Ancestry validation" {
    const alloc = testing.allocator;
    var ont = ontology.Ontology.init(alloc);
    defer ont.deinit();
    _ = try ont.addTerm("GO:001", "A");
    _ = try ont.addTerm("GO:002", "B");
    try ont.addRelationship("GO:001", "GO:002");

    const valid = try ont.isValidDAG();
    try testing.expect(valid);

    const anc = try ont.getAncestors("GO:002", alloc);
    defer alloc.free(anc);
    try testing.expectEqual(@as(usize, 1), anc.len);
}
