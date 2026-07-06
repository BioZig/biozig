const std = @import("std");
const testing = std.testing;

const evolutionary = @import("evolutionary");
const visualization = @import("visualization");
const PhyloTree = visualization.phylogeny.PhyloTree;
const PhyloNode = visualization.phylogeny.PhyloNode;
const Nucleotide = evolutionary.Nucleotide;

test "parsimonyFitch" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const leaf1 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "B", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf3 = PhyloNode.init(3, "C", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    
    const children1 = [_]usize{ 0, 1 };
    const internal1 = PhyloNode.init(4, "", 1.0, &children1, &[_]visualization.phylogeny.MetadataEntry{});
    
    const root_children = [_]usize{ 3, 2 };
    const root = PhyloNode.init(5, "", 0.0, &root_children, &[_]visualization.phylogeny.MetadataEntry{});
    
    const nodes = [_]PhyloNode{ leaf1, leaf2, leaf3, internal1, root };
    const tree = PhyloTree.init(&nodes, 4, true);

    var leaf_states = std.AutoHashMap(usize, usize).init(allocator);
    try leaf_states.put(1, 0); // State 0
    try leaf_states.put(2, 1); // State 1
    try leaf_states.put(3, 0); // State 0

    const score = try evolutionary.parsimonyFitch(allocator, tree, leaf_states);
    try testing.expectEqual(@as(usize, 1), score);
}

test "felsensteinPruning" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const leaf1 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "B", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf3 = PhyloNode.init(3, "C", 2.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    
    const children1 = [_]usize{ 0, 1 };
    const internal1 = PhyloNode.init(4, "", 1.0, &children1, &[_]visualization.phylogeny.MetadataEntry{});
    
    const root_children = [_]usize{ 3, 2 };
    const root = PhyloNode.init(5, "", 0.0, &root_children, &[_]visualization.phylogeny.MetadataEntry{});
    
    const nodes = [_]PhyloNode{ leaf1, leaf2, leaf3, internal1, root };
    const tree = PhyloTree.init(&nodes, 4, true);

    var leaf_states = std.AutoHashMap(usize, Nucleotide).init(allocator);
    try leaf_states.put(1, Nucleotide.A);
    try leaf_states.put(2, Nucleotide.A);
    try leaf_states.put(3, Nucleotide.G);

    const L = try evolutionary.felsensteinPruning(allocator, tree, leaf_states, 1.0);
    try testing.expect(L > 0.0);
    try testing.expect(L < 1.0);
}

test "nearestNeighborInterchange" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const leaf1 = PhyloNode.init(1, "A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "B", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf3 = PhyloNode.init(3, "C", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf4 = PhyloNode.init(4, "D", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    
    const c1 = [_]usize{ 0, 1 };
    const internal1 = PhyloNode.init(5, "", 1.0, &c1, &[_]visualization.phylogeny.MetadataEntry{});
    
    const c2 = [_]usize{ 2, 3 };
    const internal2 = PhyloNode.init(6, "", 1.0, &c2, &[_]visualization.phylogeny.MetadataEntry{});
    
    const root_c = [_]usize{ 4, 5 };
    const root = PhyloNode.init(7, "", 0.0, &root_c, &[_]visualization.phylogeny.MetadataEntry{});
    
    const nodes = [_]PhyloNode{ leaf1, leaf2, leaf3, leaf4, internal1, internal2, root };
    const tree = PhyloTree.init(&nodes, 6, true);

    const neighbors = try evolutionary.nearestNeighborInterchange(allocator, tree);
    try testing.expect(neighbors.items.len >= 0);
}
