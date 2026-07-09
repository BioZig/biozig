const std = @import("std");
const args_mod = @import("args.zig");
const output = @import("output.zig");
const core = @import("core");
const MMapReader = core.io.mmap.MMapReader;
const algorithms = @import("algorithms");
const systems_alg = algorithms.systems;

fn readGraph(allocator: std.mem.Allocator, path: []const u8) !systems_alg.Graph {
    var reader = try MMapReader.init(allocator, path);
    defer reader.deinit();

    var builder = systems_alg.GraphBuilder.init(1000);
    defer builder.deinit(allocator);

    var max_node: usize = 0;
    var lines = std.mem.splitScalar(u8, reader.data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var it = std.mem.splitAny(u8, line, " \t,");
        const u_str = it.next() orelse continue;
        const v_str = it.next() orelse continue;
        const u = std.fmt.parseInt(usize, u_str, 10) catch continue;
        const v = std.fmt.parseInt(usize, v_str, 10) catch continue;
        var w: f64 = 1.0;
        if (it.next()) |w_str| {
            w = std.fmt.parseFloat(f64, w_str) catch 1.0;
        }
        try builder.addEdgeWeighted(allocator, u, v, w);
        if (u > max_node) max_node = u;
        if (v > max_node) max_node = v;
    }
    builder.num_nodes = max_node + 1;
    return builder.build(allocator);
}

pub fn execute(args: args_mod.ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig systems - Systems biology and biological network analysis
            \\
            \\Usage:
            \\  biozig systems <command> [options]
            \\
            \\Commands:
            \\  degree         Node degrees
            \\  bfs            Breadth-First Search
            \\  dfs            Depth-First Search
            \\  shortest_path  Shortest path (unweighted)
            \\  dijkstra       Shortest path (weighted)
            \\  components     Connected Components
            \\  toposort       Topological Sorting
            \\  closeness      Closeness Centrality
            \\  approx_close   Approximate Closeness Centrality
            \\  betweenness    Betweenness Centrality
            \\  pagerank       PageRank algorithm
            \\  community      Louvain Community Detection
            \\  maxflow        Max Flow (Edmonds-Karp)
            \\  motif          Motif Discovery (Triangle counting)
            \\  layout         Fruchterman-Reingold Force-Directed Layout
            \\
            \\Options:
            \\  -h, --help   Show this help message and exit
            \\  -i, --input  Input edge list file (.csv, .tsv, .txt)
            \\
        , .{});
        return;
    }

    const cmd = args.run orelse {
        std.debug.print("Error: Systems domain requires a command.\n", .{});
        return;
    };

    const in_path = args.input orelse {
        std.debug.print("Error: Command requires an --input file (-i).\n", .{});
        return error.MissingInput;
    };

    var out_writer = output.OutputWriter.init(.text);

    // Ingest the graph
    const g = try readGraph(std.heap.page_allocator, in_path);
    defer g.deinit(std.heap.page_allocator);

    if (std.mem.eql(u8, cmd, "degree")) {
        const degs = try systems_alg.degree(std.heap.page_allocator, g);
        defer std.heap.page_allocator.free(degs);
        for (degs, 0..) |d, i| try out_writer.writeText("Node {d}: Degree {d}\n", .{ i, d });
    } else if (std.mem.eql(u8, cmd, "bfs")) {
        const order = try systems_alg.bfs(std.heap.page_allocator, g, 0);
        defer std.heap.page_allocator.free(order);
        std.debug.print("{any}\n", .{order});
    } else if (std.mem.eql(u8, cmd, "dfs")) {
        const order = try systems_alg.dfs(std.heap.page_allocator, g, 0);
        defer std.heap.page_allocator.free(order);
        std.debug.print("{any}\n", .{order});
    } else if (std.mem.eql(u8, cmd, "shortest_path")) {
        const path = try systems_alg.shortestPath(std.heap.page_allocator, g, 0);
        defer std.heap.page_allocator.free(path);
        std.debug.print("{any}\n", .{path});
    } else if (std.mem.eql(u8, cmd, "dijkstra")) {
        const dists = try systems_alg.dijkstra(std.heap.page_allocator, g, 0);
        defer std.heap.page_allocator.free(dists);
        std.debug.print("{any}\n", .{dists});
    } else if (std.mem.eql(u8, cmd, "components")) {
        const comps = try systems_alg.connectedComponents(std.heap.page_allocator, g);
        defer std.heap.page_allocator.free(comps);
        
        var comp_sizes = std.AutoHashMap(usize, usize).init(std.heap.page_allocator);
        defer comp_sizes.deinit();
        
        for (comps) |c| {
            const entry = try comp_sizes.getOrPut(c);
            if (!entry.found_existing) {
                entry.value_ptr.* = 0;
            }
            entry.value_ptr.* += 1;
        }
        
        var max_size: usize = 0;
        var num_comps: usize = 0;
        var it = comp_sizes.iterator();
        while (it.next()) |entry| {
            num_comps += 1;
            if (entry.value_ptr.* > max_size) {
                max_size = entry.value_ptr.*;
            }
        }
        
        std.debug.print("Graph has {} nodes and {} edges.\n", .{g.num_nodes, g.weights.len});
        std.debug.print("Found {} connected components.\n", .{num_comps});
        std.debug.print("Largest component size: {} nodes.\n", .{max_size});
    } else if (std.mem.eql(u8, cmd, "toposort")) {
        const order = try systems_alg.topologicalSort(std.heap.page_allocator, g);
        defer std.heap.page_allocator.free(order);
        std.debug.print("{any}\n", .{order});
    } else if (std.mem.eql(u8, cmd, "closeness")) {
        const centralities = try systems_alg.closenessCentrality(std.heap.page_allocator, g);
        defer std.heap.page_allocator.free(centralities);
        std.debug.print("{any}\n", .{centralities});
    } else if (std.mem.eql(u8, cmd, "approx_close")) {
        const centralities = try systems_alg.approximateClosenessCentrality(std.heap.page_allocator, g, 10);
        defer std.heap.page_allocator.free(centralities);
        std.debug.print("{any}\n", .{centralities});
    } else if (std.mem.eql(u8, cmd, "betweenness")) {
        const cb = try systems_alg.betweennessCentrality(std.heap.page_allocator, g);
        defer std.heap.page_allocator.free(cb);
        std.debug.print("{any}\n", .{cb});
    } else if (std.mem.eql(u8, cmd, "pagerank")) {
        const pr = try systems_alg.pageRank(std.heap.page_allocator, g, 0.85, 100, 1e-6);
        defer std.heap.page_allocator.free(pr);
        std.debug.print("{any}\n", .{pr});
    } else if (std.mem.eql(u8, cmd, "community")) {
        const comms = try systems_alg.louvain(std.heap.page_allocator, g);
        defer std.heap.page_allocator.free(comms);
        std.debug.print("{any}\n", .{comms});
    } else if (std.mem.eql(u8, cmd, "maxflow")) {
        const sink = if (g.num_nodes > 0) g.num_nodes - 1 else 0;
        const flow = try systems_alg.edmondsKarp(std.heap.page_allocator, g, 0, sink);
        try out_writer.writeText("Max flow: {d}\n", .{flow});
    } else if (std.mem.eql(u8, cmd, "motif")) {
        const count = try systems_alg.countTriangles(std.heap.page_allocator, g);
        try out_writer.writeText("Triangles: {d}\n", .{count});
    } else if (std.mem.eql(u8, cmd, "layout")) {
        const pos = try systems_alg.fruchtermanReingold(std.heap.page_allocator, g, 100, 1000.0, 1000.0);
        defer std.heap.page_allocator.free(pos);
        std.debug.print("{any}\n", .{pos});
    } else {
        std.debug.print("Error: Unknown systems command '{s}'\n", .{cmd});
    }
}
