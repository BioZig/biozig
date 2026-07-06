const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const molecular = @import("molecular");
const dna_module = molecular.dna;
const assembly = mol.assembly;

test "DeBruijnGraph: empty sequence" {
    const alloc = testing.allocator;
    var graph = assembly.DeBruijnGraph.init(alloc, 3);
    defer graph.deinit();

    try graph.addSequence("");
    try testing.expectEqual(@as(u32, 0), graph.edges.count());
}

test "DeBruijnGraph: sequence smaller than k" {
    const alloc = testing.allocator;
    var graph = assembly.DeBruijnGraph.init(alloc, 4);
    defer graph.deinit();

    try graph.addSequence("ACG");
    try testing.expectEqual(@as(u32, 0), graph.edges.count());
}

test "DeBruijnGraph: sequence equal to k" {
    const alloc = testing.allocator;
    var graph = assembly.DeBruijnGraph.init(alloc, 3);
    defer graph.deinit();

    try graph.addSequence("ACG");
    
    const ac_edges = graph.edges.get("AC").?;
    try testing.expectEqual(@as(usize, 1), ac_edges.items.len);
    try testing.expectEqualStrings("CG", ac_edges.items[0]);
}

test "DeBruijnGraph: multiple additions" {
    const alloc = testing.allocator;
    var graph = assembly.DeBruijnGraph.init(alloc, 3);
    defer graph.deinit();

    try graph.addSequence("AAT");
    try graph.addSequence("ATG");
    
    const aa_edges = graph.edges.get("AA").?;
    try testing.expectEqual(@as(usize, 1), aa_edges.items.len);
    try testing.expectEqualStrings("AT", aa_edges.items[0]);
    
    const at_edges = graph.edges.get("AT").?;
    try testing.expectEqual(@as(usize, 1), at_edges.items.len);
    try testing.expectEqualStrings("TG", at_edges.items[0]);
}

test "DeBruijnGraph: loop" {
    const alloc = testing.allocator;
    var graph = assembly.DeBruijnGraph.init(alloc, 2);
    defer graph.deinit();

    try graph.addSequence("AAAA");
    
    const a_edges = graph.edges.get("A").?;
    try testing.expectEqual(@as(usize, 3), a_edges.items.len);
    for (a_edges.items) |item| {
        try testing.expectEqualStrings("A", item);
    }
}
