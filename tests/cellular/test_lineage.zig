const std = @import("std");
const testing = std.testing;
const cellular = @import("cellular");
const lineage = cellular.lineage;

test "LineageNode - Initialization and child addition" {
    const alloc = testing.allocator;
    var parent = try lineage.LineageNode.init(alloc, "P");
    defer parent.deinit();
    const child = try lineage.LineageNode.init(alloc, "C");

    try parent.addChild(child);
    try testing.expectEqual(@as(usize, 1), parent.children.items.len);
}

test "LineageTree - Root assignment" {
    const alloc = testing.allocator;
    var tree = lineage.LineageTree.init(alloc);
    defer tree.deinit();

    const root = try lineage.LineageNode.init(alloc, "ROOT");
    tree.root = root;

    try testing.expect(tree.root != null);
}

test "LineageTree - Ancestry validation" {
    const alloc = testing.allocator;
    var tree = lineage.LineageTree.init(alloc);
    defer tree.deinit();

    var parent = try lineage.LineageNode.init(alloc, "P");
    const child = try lineage.LineageNode.init(alloc, "C");
    try parent.addChild(child);
    tree.root = parent;

    const ancestry = try tree.getAncestry(child, alloc);
    defer alloc.free(ancestry);
    try testing.expectEqual(@as(usize, 1), ancestry.len);
}
