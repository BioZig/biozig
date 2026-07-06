const std = @import("std");
const analytics = @import("analytics");

test "graphml node2vec edge cases" {
    var graph = try analytics.graphml.node2vec.Graph.init(std.testing.allocator, 2);
    defer graph.deinit();

    const walks = try analytics.graphml.node2vec.Node2Vec.simulateWalks(std.testing.allocator, &graph, 1, 2, 1);
    defer {
        for (walks) |w| std.testing.allocator.free(w);
        std.testing.allocator.free(walks);
    }
}

test "exhaustive reference" {
    std.testing.refAllDecls(analytics.graphml);
}
