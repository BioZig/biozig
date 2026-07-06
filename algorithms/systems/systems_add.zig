
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
