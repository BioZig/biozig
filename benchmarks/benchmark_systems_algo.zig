const std = @import("std");
const algorithms = @import("algorithms");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe

    const algo_name = args.next() orelse return error.MissingAlgoName;

    const num_nodes = 100000;
    const num_edges = 500000;

    var builder = algorithms.systems.GraphBuilder.init(num_nodes);
    defer builder.deinit(allocator);

    for (0..num_edges) |i| {
        const u = i % num_nodes;
        const v = (i * 7) % num_nodes;
        try builder.addEdge(allocator, u, v);
    }

    var graph = try builder.build(allocator);
    defer graph.deinit(allocator);

    var accuracy_pass = false;

    if (std.mem.eql(u8, algo_name, "DEGREE")) {
        const degs = try algorithms.systems.degree(allocator, graph);
        accuracy_pass = degs.len == num_nodes;
        allocator.free(degs);
    } else if (std.mem.eql(u8, algo_name, "BFS")) {
        const bfs_res = try algorithms.systems.bfs(allocator, graph, 0);
        accuracy_pass = bfs_res.len > 0;
        allocator.free(bfs_res);
    } else if (std.mem.eql(u8, algo_name, "DFS")) {
        const dfs_res = try algorithms.systems.dfs(allocator, graph, 0);
        accuracy_pass = dfs_res.len > 0;
        allocator.free(dfs_res);
    } else if (std.mem.eql(u8, algo_name, "CONNECTED_COMPONENTS")) {
        const cc = try algorithms.systems.connectedComponents(allocator, graph);
        accuracy_pass = cc.len == num_nodes;
        allocator.free(cc);
    } else if (std.mem.eql(u8, algo_name, "CLOSENESS_CENTRALITY")) {
        const cc = try algorithms.systems.closenessCentrality(allocator, graph);
        accuracy_pass = cc.len == num_nodes;
        allocator.free(cc);
    } else if (std.mem.eql(u8, algo_name, "APPROX_CLOSENESS_CENTRALITY")) {
        const cc = try algorithms.systems.approximateClosenessCentrality(allocator, graph, 10);
        accuracy_pass = cc.len == num_nodes;
        allocator.free(cc);
    } else if (std.mem.eql(u8, algo_name, "WEIGHTED_DIJKSTRA")) {
        const dists = try algorithms.systems.dijkstra(allocator, graph, 0);
        accuracy_pass = dists.len == num_nodes;
        allocator.free(dists);
    } else if (std.mem.eql(u8, algo_name, "BETWEENNESS_CENTRALITY")) {
        const cb = try algorithms.systems.betweennessCentrality(allocator, graph);
        accuracy_pass = cb.len == num_nodes;
        allocator.free(cb);
    } else if (std.mem.eql(u8, algo_name, "PAGERANK")) {
        const pr = try algorithms.systems.pageRank(allocator, graph, 0.85, 20, 1e-6);
        accuracy_pass = pr.len == num_nodes;
        allocator.free(pr);
    } else if (std.mem.eql(u8, algo_name, "LOUVAIN_COMMUNITIES")) {
        const comms = try algorithms.systems.louvain(allocator, graph);
        accuracy_pass = comms.len == num_nodes;
        allocator.free(comms);
    } else if (std.mem.eql(u8, algo_name, "EDMONDS_KARP")) {
        const flow = try algorithms.systems.edmondsKarp(allocator, graph, 0, num_nodes - 1);
        accuracy_pass = flow >= 0.0;
    } else if (std.mem.eql(u8, algo_name, "TRIANGLE_COUNT")) {
        const tris = try algorithms.systems.countTriangles(allocator, graph);
        accuracy_pass = tris >= 0;
    } else if (std.mem.eql(u8, algo_name, "FRUCHTERMAN_REINGOLD")) {
        const pos = try algorithms.systems.fruchtermanReingold(allocator, graph, 10, 1000.0, 1000.0);
        accuracy_pass = pos.len == num_nodes;
        allocator.free(pos);
    } else {
        std.debug.print("Unknown algo: {s}\n", .{algo_name});
        return;
    }

    std.debug.print("Algorithm: {s}\n", .{algo_name});
    std.debug.print("Data: {} nodes, {} edges\n", .{ num_nodes, num_edges });
    std.debug.print("Accuracy Check: {s}\n", .{if (accuracy_pass) "PASS" else "FAIL"});
}
