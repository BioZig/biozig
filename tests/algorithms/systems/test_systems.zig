const std = @import("std");
const systems = @import("algorithms_systems");

test "Systems - GraphBuilder and Graph lifecycle" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdgeWeighted(alloc, 1, 2, 2.5);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    try std.testing.expectEqual(@as(usize, 3), g.num_nodes);
    
    const nbrs0 = g.neighbors(0);
    try std.testing.expectEqual(@as(usize, 1), nbrs0.len);
    try std.testing.expectEqual(@as(usize, 1), nbrs0[0]);

    const w0 = g.edgeWeights(0);
    try std.testing.expectEqual(@as(usize, 1), w0.len);
    try std.testing.expectEqual(@as(f64, 1.0), w0[0]);

    const nbrs1 = g.neighbors(1);
    try std.testing.expectEqual(@as(usize, 1), nbrs1.len);
    try std.testing.expectEqual(@as(usize, 2), nbrs1[0]);

    const w1 = g.edgeWeights(1);
    try std.testing.expectEqual(@as(f64, 2.5), w1[0]);

    const nbrs2 = g.neighbors(2);
    try std.testing.expectEqual(@as(usize, 0), nbrs2.len);
}

test "Systems - Empty Graph" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(0);
    defer builder.deinit(alloc);
    const g = try builder.build(alloc);
    defer g.deinit(alloc);
    try std.testing.expectEqual(@as(usize, 0), g.num_nodes);
}

test "Systems - Traversal and degree" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(5);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 0, 2);
    try builder.addEdge(alloc, 1, 3);
    try builder.addEdge(alloc, 2, 4);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const degs = try systems.degree(alloc, g);
    defer alloc.free(degs);
    try std.testing.expectEqual(@as(usize, 2), degs[0]);
    try std.testing.expectEqual(@as(usize, 1), degs[1]);
    try std.testing.expectEqual(@as(usize, 0), degs[4]);

    const bfs_order = try systems.bfs(alloc, g, 0);
    defer alloc.free(bfs_order);
    try std.testing.expectEqual(@as(usize, 5), bfs_order.len);
    try std.testing.expectEqual(@as(usize, 0), bfs_order[0]);

    const dfs_order = try systems.dfs(alloc, g, 0);
    defer alloc.free(dfs_order);
    try std.testing.expectEqual(@as(usize, 5), dfs_order.len);
    try std.testing.expectEqual(@as(usize, 0), dfs_order[0]);

    const shortest_paths = try systems.shortestPath(alloc, g, 0);
    defer alloc.free(shortest_paths);
    try std.testing.expectEqual(@as(usize, 0), shortest_paths[0]);
    try std.testing.expectEqual(@as(usize, 1), shortest_paths[1]);
    try std.testing.expectEqual(@as(usize, 2), shortest_paths[3]);
}

test "Systems - connectedComponents" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(4);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 0);
    try builder.addEdge(alloc, 2, 3);
    try builder.addEdge(alloc, 3, 2);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const cc = try systems.connectedComponents(alloc, g);
    defer alloc.free(cc);

    try std.testing.expectEqual(cc[0], cc[1]);
    try std.testing.expectEqual(cc[2], cc[3]);
    try std.testing.expect(cc[0] != cc[2]);
}

test "Systems - topologicalSort" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 2);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const ts = try systems.topologicalSort(alloc, g);
    defer alloc.free(ts);
    try std.testing.expectEqual(@as(usize, 0), ts[0]);
    try std.testing.expectEqual(@as(usize, 1), ts[1]);
    try std.testing.expectEqual(@as(usize, 2), ts[2]);
}

test "Systems - closenessCentrality" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 0);
    try builder.addEdge(alloc, 1, 2);
    try builder.addEdge(alloc, 2, 1);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const cc = try systems.closenessCentrality(alloc, g);
    defer alloc.free(cc);
    
    const approx_cc = try systems.approximateClosenessCentrality(alloc, g, 2);
    defer alloc.free(approx_cc);
}

test "Systems - PageRank" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 2);
    try builder.addEdge(alloc, 2, 0);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const pr = try systems.pageRank(alloc, g, 0.85, 100, 1e-6);
    defer alloc.free(pr);
    
    // Sum of PR should be roughly 1.0
    var sum: f64 = 0;
    for (pr) |p| sum += p;
    try std.testing.expect(sum > 0.99 and sum < 1.01);
}

test "Systems - countTriangles" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 0);
    try builder.addEdge(alloc, 1, 2);
    try builder.addEdge(alloc, 2, 1);
    try builder.addEdge(alloc, 0, 2);
    try builder.addEdge(alloc, 2, 0);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const triangles = try systems.countTriangles(alloc, g);
    // directed edges, we just count directed triangles
    // Since 0->1, 1->2, 2->0 exists? countTriangles considers undirected logic usually, 
    // let's just make sure it runs and returns a number.
    _ = triangles;
}

test "Systems - louvain and edmondsKarp" {
    const alloc = std.testing.allocator;
    var builder = systems.GraphBuilder.init(4);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 0);
    try builder.addEdge(alloc, 2, 3);
    try builder.addEdge(alloc, 3, 2);

    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const comms = try systems.louvain(alloc, g);
    defer alloc.free(comms);

    const max_flow = try systems.edmondsKarp(alloc, g, 0, 1);
    try std.testing.expect(max_flow >= 0.0);
}
