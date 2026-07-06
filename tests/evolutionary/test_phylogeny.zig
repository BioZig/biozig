const std = @import("std");
const testing = std.testing;

const evolutionary = @import("evolutionary");
const visualization = @import("visualization");
const PhyloTree = visualization.phylogeny.PhyloTree;
const PhyloNode = visualization.phylogeny.PhyloNode;

test "computeTreeStatistics - basic tree" {
    const leaf1 = PhyloNode.init(1, "A", 1.5, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "B", 1.5, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf3 = PhyloNode.init(3, "C", 2.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});

    const children1 = [_]usize{ 0, 1 };
    const internal1 = PhyloNode.init(4, "", 0.5, &children1, &[_]visualization.phylogeny.MetadataEntry{});

    const root_children = [_]usize{ 3, 2 };
    const root = PhyloNode.init(5, "", 0.0, &root_children, &[_]visualization.phylogeny.MetadataEntry{});

    const nodes = [_]PhyloNode{ leaf1, leaf2, leaf3, internal1, root };
    const tree = PhyloTree.init(&nodes, 4, true);

    const stats = evolutionary.computeTreeStatistics(tree);
    try testing.expectEqual(@as(usize, 3), stats.num_leaves);
    try testing.expectEqual(@as(usize, 2), stats.num_internal_nodes);
    try testing.expectEqual(5.5, stats.total_branch_length);
    try testing.expectEqual(2.0, stats.max_depth);
}

test "computeTreeStatistics - single node tree" {
    const root = PhyloNode.init(0, "Root", 0.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const nodes = [_]PhyloNode{root};
    const tree = PhyloTree.init(&nodes, 0, true);

    const stats = evolutionary.computeTreeStatistics(tree);
    try testing.expectEqual(@as(usize, 1), stats.num_leaves);
    try testing.expectEqual(@as(usize, 0), stats.num_internal_nodes);
    try testing.expectEqual(0.0, stats.total_branch_length);
    try testing.expectEqual(0.0, stats.max_depth);
}

test "areTreesIdentical - identical trees" {
    const leaf1 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const nodes1 = [_]PhyloNode{leaf1};
    const tree1 = PhyloTree.init(&nodes1, 0, true);

    const leaf2 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const nodes2 = [_]PhyloNode{leaf2};
    const tree2 = PhyloTree.init(&nodes2, 0, true);

    try testing.expect(evolutionary.areTreesIdentical(tree1, tree2));
}

test "areTreesIdentical - different trees" {
    const leaf1 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const nodes1 = [_]PhyloNode{leaf1};
    const tree1 = PhyloTree.init(&nodes1, 0, true);

    const leaf2 = PhyloNode.init(1, "B", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const nodes2 = [_]PhyloNode{leaf2};
    const tree2 = PhyloTree.init(&nodes2, 0, true);

    try testing.expect(!evolutionary.areTreesIdentical(tree1, tree2));
}

test "robinsonFouldsDistance" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const leaf1 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "B", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const children = [_]usize{ 0, 1 };
    const root1 = PhyloNode.init(3, "", 0.0, &children, &[_]visualization.phylogeny.MetadataEntry{});
    const nodes1 = [_]PhyloNode{ leaf1, leaf2, root1 };
    const tree1 = PhyloTree.init(&nodes1, 2, true);

    const tree2 = PhyloTree.init(&nodes1, 2, true);

    const dist = try evolutionary.robinsonFouldsDistance(allocator, tree1, tree2);
    try testing.expectEqual(@as(usize, 0), dist);
}
