const std = @import("std");

/// A builder for constructing a CSRGraph incrementally.
pub const GraphBuilder = struct {
    num_nodes: usize,
    edges: std.ArrayList(Edge),

    pub const Edge = struct { u: usize, v: usize, w: f64 };

    pub fn init(num_nodes: usize) GraphBuilder {
        return .{
            .num_nodes = num_nodes,
            .edges = .empty,
        };
    }

    pub fn deinit(self: *GraphBuilder, allocator: std.mem.Allocator) void {
        self.edges.deinit(allocator);
    }

    pub fn addEdge(self: *GraphBuilder, allocator: std.mem.Allocator, u: usize, v: usize) !void {
        try self.edges.append(allocator, .{ .u = u, .v = v, .w = 1.0 });
    }

    pub fn addEdgeWeighted(self: *GraphBuilder, allocator: std.mem.Allocator, u: usize, v: usize, w: f64) !void {
        try self.edges.append(allocator, .{ .u = u, .v = v, .w = w });
    }

    pub fn build(self: GraphBuilder, allocator: std.mem.Allocator) !Graph {
        return Graph.fromEdges(allocator, self.num_nodes, self.edges.items);
    }
};

/// A Compressed Sparse Row (CSR) Graph representation for fast traversal.
pub const Graph = struct {
    num_nodes: usize,
    offsets: []usize,
    edges: []usize,
    weights: []f64,

    pub fn fromEdges(allocator: std.mem.Allocator, num_nodes: usize, edge_list: []const GraphBuilder.Edge) !Graph {
        var degree_arr = try allocator.alloc(usize, num_nodes);
        defer allocator.free(degree_arr);
        @memset(degree_arr, 0);

        for (edge_list) |e| {
            degree_arr[e.u] += 1;
        }

        var offsets = try allocator.alloc(usize, num_nodes + 1);
        offsets[0] = 0;
        for (0..num_nodes) |i| {
            offsets[i + 1] = offsets[i] + degree_arr[i];
        }

        var current_offsets = try allocator.alloc(usize, num_nodes);
        defer allocator.free(current_offsets);
        @memcpy(current_offsets, offsets[0..num_nodes]);

        var edges = try allocator.alloc(usize, edge_list.len);
        var weights = try allocator.alloc(f64, edge_list.len);

        for (edge_list) |e| {
            const pos = current_offsets[e.u];
            edges[pos] = e.v;
            weights[pos] = e.w;
            current_offsets[e.u] += 1;
        }

        return Graph{
            .num_nodes = num_nodes,
            .offsets = offsets,
            .edges = edges,
            .weights = weights,
        };
    }

    pub fn deinit(self: Graph, allocator: std.mem.Allocator) void {
        allocator.free(self.offsets);
        allocator.free(self.edges);
        allocator.free(self.weights);
    }

    pub fn neighbors(self: Graph, u: usize) []usize {
        return self.edges[self.offsets[u]..self.offsets[u + 1]];
    }

    pub fn edgeWeights(self: Graph, u: usize) []f64 {
        return self.weights[self.offsets[u]..self.offsets[u + 1]];
    }
};

/// Computes the out-degree of all nodes.
pub fn degree(allocator: std.mem.Allocator, g: Graph) ![]usize {
    var degs = try allocator.alloc(usize, g.num_nodes);
    for (0..g.num_nodes) |i| {
        degs[i] = g.neighbors(i).len;
    }
    return degs;
}

/// Breadth-First Search traversal from a start node. Returns the order of visited nodes.
pub fn bfs(allocator: std.mem.Allocator, g: Graph, start: usize) ![]usize {
    var visited = try allocator.alloc(bool, g.num_nodes);
    defer allocator.free(visited);
    @memset(visited, false);

    var order = std.ArrayList(usize).empty;
    errdefer order.deinit(allocator);

    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    try queue.append(allocator, start);
    visited[start] = true;

    while (queue.items.len > 0) {
        const u = queue.orderedRemove(0);
        try order.append(allocator, u);

        for (g.neighbors(u)) |v| {
            if (!visited[v]) {
                visited[v] = true;
                try queue.append(allocator, v);
            }
        }
    }

    return order.toOwnedSlice(allocator);
}

/// Depth-First Search traversal.
pub fn dfs(allocator: std.mem.Allocator, g: Graph, start: usize) ![]usize {
    var visited = try allocator.alloc(bool, g.num_nodes);
    defer allocator.free(visited);
    @memset(visited, false);

    var order = std.ArrayList(usize).empty;
    errdefer order.deinit(allocator);

    var stack = std.ArrayList(usize).empty;
    defer stack.deinit(allocator);

    try stack.append(allocator, start);

    while (stack.pop()) |u| {
        if (!visited[u]) {
            visited[u] = true;
            try order.append(allocator, u);
            
            const nbrs = g.neighbors(u);
            var i: usize = nbrs.len;
            while (i > 0) {
                i -= 1;
                const v = nbrs[i];
                if (!visited[v]) {
                    try stack.append(allocator, v);
                }
            }
        }
    }

    return order.toOwnedSlice(allocator);
}

/// Computes Shortest Path distances from a source node using BFS (unweighted).
pub fn shortestPath(allocator: std.mem.Allocator, g: Graph, start: usize) ![]usize {
    var dist = try allocator.alloc(usize, g.num_nodes);
    @memset(dist, std.math.maxInt(usize));

    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    try queue.append(allocator, start);
    dist[start] = 0;

    while (queue.items.len > 0) {
        const u = queue.orderedRemove(0);

        for (g.neighbors(u)) |v| {
            if (dist[v] == std.math.maxInt(usize)) {
                dist[v] = dist[u] + 1;
                try queue.append(allocator, v);
            }
        }
    }

    return dist;
}

/// Connected Components for an undirected graph. Returns an array of component IDs.
pub fn connectedComponents(allocator: std.mem.Allocator, g: Graph) ![]usize {
    var components = try allocator.alloc(usize, g.num_nodes);
    @memset(components, std.math.maxInt(usize));

    var current_component: usize = 0;
    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    for (0..g.num_nodes) |i| {
        if (components[i] == std.math.maxInt(usize)) {
            try queue.append(allocator, i);
            components[i] = current_component;

            while (queue.items.len > 0) {
                const u = queue.orderedRemove(0);
                for (g.neighbors(u)) |v| {
                    if (components[v] == std.math.maxInt(usize)) {
                        components[v] = current_component;
                        try queue.append(allocator, v);
                    }
                }
            }
            current_component += 1;
        }
    }

    return components;
}

/// Topological Sort using Kahn's algorithm. Returns error.CycleDetected if graph is not a DAG.
pub fn topologicalSort(allocator: std.mem.Allocator, g: Graph) ![]usize {
    var in_degree = try allocator.alloc(usize, g.num_nodes);
    defer allocator.free(in_degree);
    @memset(in_degree, 0);

    for (0..g.num_nodes) |u| {
        for (g.neighbors(u)) |v| {
            in_degree[v] += 1;
        }
    }

    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    for (0..g.num_nodes) |u| {
        if (in_degree[u] == 0) {
            try queue.append(allocator, u);
        }
    }

    var order = std.ArrayList(usize).empty;
    errdefer order.deinit(allocator);

    while (queue.items.len > 0) {
        const u = queue.orderedRemove(0);
        try order.append(allocator, u);

        for (g.neighbors(u)) |v| {
            in_degree[v] -= 1;
            if (in_degree[v] == 0) {
                try queue.append(allocator, v);
            }
        }
    }

    if (order.items.len != g.num_nodes) {
        return error.CycleDetected;
    }

    return order.toOwnedSlice(allocator);
}

/// Closeness Centrality. 
pub fn closenessCentrality(allocator: std.mem.Allocator, g: Graph) ![]f64 {
    var closeness = try allocator.alloc(f64, g.num_nodes);
    
    for (0..g.num_nodes) |u| {
        const dists = try shortestPath(allocator, g, u);
        defer allocator.free(dists);

        var sum_d: usize = 0;
        var valid = true;
        for (dists, 0..) |d, v| {
            if (u != v) {
                if (d == std.math.maxInt(usize)) {
                    valid = false;
                    break;
                }
                sum_d += d;
            }
        }

        if (valid and sum_d > 0) {
            closeness[u] = @as(f64, @floatFromInt(g.num_nodes - 1)) / @as(f64, @floatFromInt(sum_d));
        } else {
            closeness[u] = 0.0;
        }
    }

    return closeness;
}

/// Approximate Closeness Centrality using random sampling of nodes.
pub fn approximateClosenessCentrality(allocator: std.mem.Allocator, g: Graph, num_samples: usize) ![]f64 {
    var closeness = try allocator.alloc(f64, g.num_nodes);
    @memset(closeness, 0.0);
    
    var prng = std.Random.Pcg.init(42);
    const random = prng.random();
    
    var sample_nodes = std.ArrayList(usize).empty;
    defer sample_nodes.deinit(allocator);
    
    // Sample nodes
    for (0..num_samples) |_| {
        const u = random.intRangeLessThan(usize, 0, g.num_nodes);
        try sample_nodes.append(allocator, u);
    }
    
    var dist_sums = try allocator.alloc(usize, g.num_nodes);
    defer allocator.free(dist_sums);
    @memset(dist_sums, 0);
    
    var reachable_counts = try allocator.alloc(usize, g.num_nodes);
    defer allocator.free(reachable_counts);
    @memset(reachable_counts, 0);
    
    for (sample_nodes.items) |v| {
        const dists = try shortestPath(allocator, g, v);
        defer allocator.free(dists);
        
        for (0..g.num_nodes) |u| {
            if (u != v and dists[u] != std.math.maxInt(usize)) {
                dist_sums[u] += dists[u];
                reachable_counts[u] += 1;
            }
        }
    }
    
    for (0..g.num_nodes) |u| {
        if (reachable_counts[u] > 0) {
            const avg_dist = @as(f64, @floatFromInt(dist_sums[u])) / @as(f64, @floatFromInt(reachable_counts[u]));
            closeness[u] = 1.0 / avg_dist;
        } else {
            closeness[u] = 0.0;
        }
    }

    return closeness;
}

test "Systems Algorithms - Graph Traversals" {
    const alloc = std.testing.allocator;
    var builder = GraphBuilder.init(4);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 0, 2);
    try builder.addEdge(alloc, 1, 3);
    try builder.addEdge(alloc, 2, 3);
    
    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const b = try bfs(alloc, g, 0);
    defer alloc.free(b);
    try std.testing.expectEqual(@as(usize, 0), b[0]);
    try std.testing.expectEqual(@as(usize, 1), b[1]); 
    
    const d = try shortestPath(alloc, g, 0);
    defer alloc.free(d);
    try std.testing.expectEqual(@as(usize, 2), d[3]); 
}

test "Systems Algorithms - Topo Sort" {
    const alloc = std.testing.allocator;
    var builder = GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 2);
    
    var g = try builder.build(alloc);

    const ts = try topologicalSort(alloc, g);
    defer alloc.free(ts);
    try std.testing.expectEqual(@as(usize, 0), ts[0]);
    try std.testing.expectEqual(@as(usize, 2), ts[2]);
    
    g.deinit(alloc);

    try builder.addEdge(alloc, 2, 0); // Cycle!
    var g2 = try builder.build(alloc);
    defer g2.deinit(alloc);
    try std.testing.expectError(error.CycleDetected, topologicalSort(alloc, g2));
}

test "Approximate Closeness Centrality" {
    const alloc = std.testing.allocator;
    var builder = GraphBuilder.init(4);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 0, 2);
    try builder.addEdge(alloc, 1, 3);
    try builder.addEdge(alloc, 2, 3);
    
    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const cc = try approximateClosenessCentrality(alloc, g, 2);
    defer alloc.free(cc);
    
    try std.testing.expect(cc.len == 4);
}

/// Dijkstra's Shortest Path from a start node (weighted)
pub fn dijkstra(allocator: std.mem.Allocator, g: Graph, start: usize) ![]f64 {
    var dist = try allocator.alloc(f64, g.num_nodes);
    @memset(dist, std.math.inf(f64));

    const PQEntry = struct {
        u: usize,
        d: f64,
        fn lessThan(context: void, a: @This(), b: @This()) std.math.Order {
            _ = context;
            return std.math.order(a.d, b.d);
        }
    };

    var pq = std.PriorityQueue(PQEntry, void, PQEntry.lessThan).initContext({});
    defer pq.deinit(allocator);

    dist[start] = 0.0;
    try pq.push(allocator, .{ .u = start, .d = 0.0 });

    while (pq.pop()) |item| {
        if (item.d > dist[item.u]) continue;

        const nbrs = g.neighbors(item.u);
        const wghts = g.edgeWeights(item.u);
        for (nbrs, 0..) |v, i| {
            const w = wghts[i];
            const new_d = dist[item.u] + w;
            if (new_d < dist[v]) {
                dist[v] = new_d;
                try pq.push(allocator, .{ .u = v, .d = new_d });
            }
        }
    }

    return dist;
}

/// Betweenness Centrality (Brandes' Algorithm)
pub fn betweennessCentrality(allocator: std.mem.Allocator, g: Graph) ![]f64 {
    var cb = try allocator.alloc(f64, g.num_nodes);
    @memset(cb, 0.0);

    var S = std.ArrayList(usize).empty;
    defer S.deinit(allocator);

    var P = try allocator.alloc(std.ArrayList(usize), g.num_nodes);
    for (0..g.num_nodes) |i| P[i] = std.ArrayList(usize).empty;
    defer {
        for (0..g.num_nodes) |i| P[i].deinit(allocator);
        allocator.free(P);
    }

    var sigma = try allocator.alloc(f64, g.num_nodes);
    defer allocator.free(sigma);

    var d = try allocator.alloc(f64, g.num_nodes);
    defer allocator.free(d);

    var delta = try allocator.alloc(f64, g.num_nodes);
    defer allocator.free(delta);

    var Q = std.ArrayList(usize).empty;
    defer Q.deinit(allocator);

    for (0..g.num_nodes) |s| {
        S.clearRetainingCapacity();
        for (0..g.num_nodes) |i| P[i].clearRetainingCapacity();
        
        @memset(sigma, 0.0);
        sigma[s] = 1.0;
        
        @memset(d, -1.0);
        d[s] = 0.0;
        
        Q.clearRetainingCapacity();
        try Q.append(allocator, s);

        while (Q.items.len > 0) {
            const v = Q.orderedRemove(0);
            try S.append(allocator, v);

            const nbrs = g.neighbors(v);
            for (nbrs) |w| {
                if (d[w] < 0) {
                    try Q.append(allocator, w);
                    d[w] = d[v] + 1;
                }
                if (d[w] == d[v] + 1) {
                    sigma[w] += sigma[v];
                    try P[w].append(allocator, v);
                }
            }
        }

        @memset(delta, 0.0);
        var i: usize = S.items.len;
        while (i > 0) {
            i -= 1;
            const w = S.items[i];
            for (P[w].items) |v| {
                delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w]);
            }
            if (w != s) {
                cb[w] += delta[w];
            }
        }
    }

    return cb;
}

/// PageRank
pub fn pageRank(allocator: std.mem.Allocator, g: Graph, damping: f64, max_iters: usize, tol: f64) ![]f64 {
    var pr = try allocator.alloc(f64, g.num_nodes);
    var pr_next = try allocator.alloc(f64, g.num_nodes);
    defer allocator.free(pr_next);

    const init_val = 1.0 / @as(f64, @floatFromInt(g.num_nodes));
    @memset(pr, init_val);

    var out_degree = try allocator.alloc(usize, g.num_nodes);
    defer allocator.free(out_degree);
    for (0..g.num_nodes) |u| {
        out_degree[u] = g.neighbors(u).len;
    }

    for (0..max_iters) |_| {
        const base_pr = (1.0 - damping) / @as(f64, @floatFromInt(g.num_nodes));
        @memset(pr_next, base_pr);

        var dangling_sum: f64 = 0.0;
        for (0..g.num_nodes) |u| {
            if (out_degree[u] == 0) {
                dangling_sum += pr[u];
            }
        }
        const dangling_pr = damping * dangling_sum / @as(f64, @floatFromInt(g.num_nodes));

        for (0..g.num_nodes) |u| {
            pr_next[u] += dangling_pr;
        }

        for (0..g.num_nodes) |u| {
            if (out_degree[u] > 0) {
                const step = damping * pr[u] / @as(f64, @floatFromInt(out_degree[u]));
                for (g.neighbors(u)) |v| {
                    pr_next[v] += step;
                }
            }
        }

        var diff: f64 = 0.0;
        for (0..g.num_nodes) |u| {
            diff += @abs(pr_next[u] - pr[u]);
            pr[u] = pr_next[u];
        }

        if (diff < tol) {
            break;
        }
    }

    return pr;
}

/// Community Detection (Basic Phase-1 Louvain / Label Propagation)
pub fn louvain(allocator: std.mem.Allocator, g: Graph) ![]usize {
    var communities = try allocator.alloc(usize, g.num_nodes);
    var tot_weight = try allocator.alloc(f64, g.num_nodes);
    defer allocator.free(tot_weight);

    var m: f64 = 0.0;
    var node_degree = try allocator.alloc(f64, g.num_nodes);
    defer allocator.free(node_degree);

    for (0..g.num_nodes) |i| {
        communities[i] = i;
        var deg: f64 = 0.0;
        const wghts = g.edgeWeights(i);
        for (wghts) |w| deg += w;
        node_degree[i] = deg;
        tot_weight[i] = deg;
        m += deg;
    }
    m /= 2.0;
    
    if (m == 0.0) return communities;

    var improved = true;
    while (improved) {
        improved = false;
        
        for (0..g.num_nodes) |u| {
            const current_comm = communities[u];
            const deg = node_degree[u];
            
            var nbr_comms = std.AutoHashMap(usize, f64).init(allocator);
            defer nbr_comms.deinit();

            const nbrs = g.neighbors(u);
            const wghts = g.edgeWeights(u);
            
            for (nbrs, 0..) |v, i| {
                if (u == v) continue;
                const comm_v = communities[v];
                const res = try nbr_comms.getOrPut(comm_v);
                if (!res.found_existing) res.value_ptr.* = 0.0;
                res.value_ptr.* += wghts[i];
            }

            tot_weight[current_comm] -= deg;
            
            var best_comm = current_comm;
            var best_increase: f64 = 0.0;
            
            var it = nbr_comms.iterator();
            while (it.next()) |entry| {
                const comm = entry.key_ptr.*;
                const w_in = entry.value_ptr.*;
                const increase = w_in - (tot_weight[comm] * deg) / (2.0 * m);
                if (increase > best_increase) {
                    best_increase = increase;
                    best_comm = comm;
                }
            }

            if (best_comm != current_comm) {
                communities[u] = best_comm;
                tot_weight[best_comm] += deg;
                improved = true;
            } else {
                tot_weight[current_comm] += deg;
            }
        }
    }

    return communities;
}

/// Maximum Flow / Min Cut (Edmonds-Karp)
pub const ResidualEdge = struct {
    to: usize,
    capacity: f64,
    flow: f64,
    rev_idx: usize,
};

pub fn edmondsKarp(allocator: std.mem.Allocator, g: Graph, source: usize, sink: usize) !f64 {
    var res_adj = try allocator.alloc(std.ArrayList(ResidualEdge), g.num_nodes);
    for (0..g.num_nodes) |u| res_adj[u] = std.ArrayList(ResidualEdge).empty;
    defer {
        for (0..g.num_nodes) |u| res_adj[u].deinit(allocator);
        allocator.free(res_adj);
    }

    for (0..g.num_nodes) |u| {
        const nbrs = g.neighbors(u);
        const weights = g.edgeWeights(u);
        for (nbrs, 0..) |v, i| {
            if (u == v) continue;
            const w = weights[i];
            
            const u_idx = res_adj[u].items.len;
            const v_idx = res_adj[v].items.len;
            
            try res_adj[u].append(allocator, .{
                .to = v,
                .capacity = w,
                .flow = 0.0,
                .rev_idx = v_idx,
            });
            
            try res_adj[v].append(allocator, .{
                .to = u,
                .capacity = 0.0,
                .flow = 0.0,
                .rev_idx = u_idx,
            });
        }
    }

    var max_flow: f64 = 0.0;
    
    var parent_node = try allocator.alloc(usize, g.num_nodes);
    defer allocator.free(parent_node);
    
    var parent_edge = try allocator.alloc(usize, g.num_nodes);
    defer allocator.free(parent_edge);
    
    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    while (true) {
        @memset(parent_node, std.math.maxInt(usize));
        queue.clearRetainingCapacity();
        try queue.append(allocator, source);
        
        var sink_reached = false;
        
        while (queue.items.len > 0) {
            const u = queue.orderedRemove(0);
            if (u == sink) {
                sink_reached = true;
                break;
            }
            
            for (res_adj[u].items, 0..) |edge, edge_idx| {
                const v = edge.to;
                const residual_cap = edge.capacity - edge.flow;
                if (parent_node[v] == std.math.maxInt(usize) and residual_cap > 0.0 and v != source) {
                    parent_node[v] = u;
                    parent_edge[v] = edge_idx;
                    try queue.append(allocator, v);
                }
            }
        }
        
        if (!sink_reached) {
            break;
        }
        
        var path_flow: f64 = std.math.inf(f64);
        var curr = sink;
        while (curr != source) {
            const p = parent_node[curr];
            const p_e = parent_edge[curr];
            const residual_cap = res_adj[p].items[p_e].capacity - res_adj[p].items[p_e].flow;
            path_flow = @min(path_flow, residual_cap);
            curr = p;
        }
        
        curr = sink;
        while (curr != source) {
            const p = parent_node[curr];
            const p_e = parent_edge[curr];
            const rev_idx = res_adj[p].items[p_e].rev_idx;
            
            res_adj[p].items[p_e].flow += path_flow;
            res_adj[curr].items[rev_idx].flow -= path_flow;
            
            curr = p;
        }
        
        max_flow += path_flow;
    }
    
    return max_flow;
}

/// Graphlet / Network Motif Counting (Triangles)
pub fn countTriangles(allocator: std.mem.Allocator, g: Graph) !usize {
    var in_u = try allocator.alloc(bool, g.num_nodes);
    defer allocator.free(in_u);
    @memset(in_u, false);

    var count: usize = 0;
    
    for (0..g.num_nodes) |u| {
        for (g.neighbors(u)) |v| {
            in_u[v] = true;
        }
        
        for (g.neighbors(u)) |v| {
            if (u < v) {
                for (g.neighbors(v)) |w| {
                    if (v < w and in_u[w]) {
                        count += 1;
                    }
                }
            }
        }
        
        for (g.neighbors(u)) |v| {
            in_u[v] = false;
        }
    }
    
    return count;
}

pub const Point2D = struct { x: f64, y: f64 };

/// Force-Directed Layout (Fruchterman-Reingold)
pub fn fruchtermanReingold(allocator: std.mem.Allocator, g: Graph, iterations: usize, width: f64, height: f64) ![]Point2D {
    var positions = try allocator.alloc(Point2D, g.num_nodes);
    var displacements = try allocator.alloc(Point2D, g.num_nodes);
    defer allocator.free(displacements);

    var prng = std.Random.Pcg.init(42);
    const random = prng.random();

    for (0..g.num_nodes) |i| {
        positions[i] = .{
            .x = random.float(f64) * width,
            .y = random.float(f64) * height,
        };
    }

    if (g.num_nodes == 0) return positions;

    const area = width * height;
    const num_nodes_f64 = @as(f64, @floatFromInt(g.num_nodes));
    const k = std.math.sqrt(area / num_nodes_f64);
    var temp = width / 10.0;
    const temp_step = temp / @as(f64, @floatFromInt(iterations));

    for (0..iterations) |_| {
        @memset(displacements, .{ .x = 0.0, .y = 0.0 });

        for (0..g.num_nodes) |v| {
            for (0..g.num_nodes) |u| {
                if (u != v) {
                    const dx = positions[v].x - positions[u].x;
                    const dy = positions[v].y - positions[u].y;
                    const dist_sq = dx * dx + dy * dy;
                    if (dist_sq > 0) {
                        const dist = std.math.sqrt(dist_sq);
                        const rep_force = (k * k) / dist;
                        displacements[v].x += (dx / dist) * rep_force;
                        displacements[v].y += (dy / dist) * rep_force;
                    }
                }
            }
        }

        for (0..g.num_nodes) |v| {
            for (g.neighbors(v)) |u| {
                const dx = positions[v].x - positions[u].x;
                const dy = positions[v].y - positions[u].y;
                const dist_sq = dx * dx + dy * dy;
                if (dist_sq > 0) {
                    const dist = std.math.sqrt(dist_sq);
                    const att_force = (dist_sq) / k;
                    const fx = (dx / dist) * att_force;
                    const fy = (dy / dist) * att_force;
                    
                    displacements[v].x -= fx;
                    displacements[v].y -= fy;
                    displacements[u].x += fx;
                    displacements[u].y += fy;
                }
            }
        }

        for (0..g.num_nodes) |v| {
            const dx = displacements[v].x;
            const dy = displacements[v].y;
            const dist = std.math.sqrt(dx * dx + dy * dy);
            
            if (dist > 0) {
                const move_dist = @min(dist, temp);
                positions[v].x += (dx / dist) * move_dist;
                positions[v].y += (dy / dist) * move_dist;
            }

            positions[v].x = @max(0.0, @min(width, positions[v].x));
            positions[v].y = @max(0.0, @min(height, positions[v].y));
        }

        temp -= temp_step;
        if (temp < 0) temp = 0;
    }

    return positions;
}

test "Systems Algorithms - Edmonds-Karp" {
    const alloc = std.testing.allocator;
    var builder = GraphBuilder.init(6);
    defer builder.deinit(alloc);

    try builder.addEdgeWeighted(alloc, 0, 1, 16);
    try builder.addEdgeWeighted(alloc, 0, 2, 13);
    try builder.addEdgeWeighted(alloc, 1, 2, 10);
    try builder.addEdgeWeighted(alloc, 1, 3, 12);
    try builder.addEdgeWeighted(alloc, 2, 1, 4);
    try builder.addEdgeWeighted(alloc, 2, 4, 14);
    try builder.addEdgeWeighted(alloc, 3, 2, 9);
    try builder.addEdgeWeighted(alloc, 3, 5, 20);
    try builder.addEdgeWeighted(alloc, 4, 3, 7);
    try builder.addEdgeWeighted(alloc, 4, 5, 4);
    
    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const max_flow = try edmondsKarp(alloc, g, 0, 5);
    try std.testing.expectEqual(@as(f64, 23.0), max_flow);
}

test "Systems Algorithms - Triangle Counting" {
    const alloc = std.testing.allocator;
    var builder = GraphBuilder.init(4);
    defer builder.deinit(alloc);

    // K4 graph
    try builder.addEdge(alloc, 0, 1); try builder.addEdge(alloc, 1, 0);
    try builder.addEdge(alloc, 0, 2); try builder.addEdge(alloc, 2, 0);
    try builder.addEdge(alloc, 0, 3); try builder.addEdge(alloc, 3, 0);
    try builder.addEdge(alloc, 1, 2); try builder.addEdge(alloc, 2, 1);
    try builder.addEdge(alloc, 1, 3); try builder.addEdge(alloc, 3, 1);
    try builder.addEdge(alloc, 2, 3); try builder.addEdge(alloc, 3, 2);
    
    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const triangles = try countTriangles(alloc, g);
    try std.testing.expectEqual(@as(usize, 4), triangles);
}

test "Systems Algorithms - Fruchterman-Reingold" {
    const alloc = std.testing.allocator;
    var builder = GraphBuilder.init(3);
    defer builder.deinit(alloc);

    try builder.addEdge(alloc, 0, 1);
    try builder.addEdge(alloc, 1, 2);
    try builder.addEdge(alloc, 2, 0);
    
    const g = try builder.build(alloc);
    defer g.deinit(alloc);

    const pos = try fruchtermanReingold(alloc, g, 10, 100.0, 100.0);
    defer alloc.free(pos);

    try std.testing.expectEqual(@as(usize, 3), pos.len);
}

