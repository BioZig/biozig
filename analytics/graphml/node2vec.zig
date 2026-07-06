const std = @import("std");

pub const Graph = struct {
    allocator: std.mem.Allocator,
    adj: std.ArrayList(std.ArrayList(u32)),

    pub fn init(allocator: std.mem.Allocator, num_nodes: u32) !Graph {
        var adj = try std.ArrayList(std.ArrayList(u32)).initCapacity(allocator, num_nodes);
        var i: u32 = 0;
        while (i < num_nodes) : (i += 1) {
            adj.appendAssumeCapacity(.empty);
        }
        return Graph{
            .allocator = allocator,
            .adj = adj,
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.adj.items) |*neighbors| {
            neighbors.deinit(self.allocator);
        }
        self.adj.deinit(self.allocator);
    }

    pub fn addEdge(self: *Graph, u: u32, v: u32) !void {
        try self.adj.items[u].append(self.allocator, v);
        try self.adj.items[v].append(self.allocator, u);
    }
};

pub const Node2Vec = struct {
    pub fn simulateWalks(
        allocator: std.mem.Allocator,
        graph: *const Graph,
        num_walks: u32,
        walk_length: u32,
        threads: u16,
    ) ![][]u32 {
        const total_walks = graph.adj.items.len * num_walks;
        const walks = try allocator.alloc([]u32, total_walks);
        errdefer allocator.free(walks);

        var thread_pool = try std.ArrayList(std.Thread).initCapacity(allocator, threads);
        defer thread_pool.deinit(allocator);

        const num_nodes = @as(u32, @intCast(graph.adj.items.len));

        const Worker = struct {
            fn doWork(
                g: *const Graph,
                w: [][]u32,
                n_walks: u32,
                w_length: u32,
                start_node: u32,
                end_node: u32,
                alloc: std.mem.Allocator,
            ) void {
                var prng = std.Random.Pcg.init(12345 + @as(u64, start_node));
                const random = prng.random();

                var node_idx: u32 = start_node;
                while (node_idx < end_node) : (node_idx += 1) {
                    var iter: u32 = 0;
                    while (iter < n_walks) : (iter += 1) {
                        const walk_idx = node_idx * n_walks + iter;
                        w[walk_idx] = alloc.alloc(u32, w_length) catch unreachable;

                        w[walk_idx][0] = node_idx;
                        var curr = node_idx;

                        var step: u32 = 1;
                        while (step < w_length) : (step += 1) {
                            const neighbors = g.adj.items[curr].items;
                            if (neighbors.len == 0) {
                                while (step < w_length) : (step += 1) {
                                    w[walk_idx][step] = curr;
                                }
                                break;
                            }

                            const next_idx = random.uintLessThan(usize, neighbors.len);
                            const next = neighbors[next_idx];
                            w[walk_idx][step] = next;
                            curr = next;
                        }
                    }
                }
            }
        };

        var start_node: u32 = 0;
        const chunk_size = (num_nodes + threads - 1) / threads;

        var t: u16 = 0;
        while (t < threads) : (t += 1) {
            const end_node = @min(start_node + chunk_size, num_nodes);
            if (start_node >= end_node) break;

            const thread = try std.Thread.spawn(.{}, Worker.doWork, .{
                graph,
                walks,
                num_walks,
                walk_length,
                start_node,
                end_node,
                allocator,
            });
            thread_pool.appendAssumeCapacity(thread);

            start_node = end_node;
        }

        for (thread_pool.items) |thread| {
            thread.join();
        }

        return walks;
    }
};

test "node2vec parallel walks" {
    var graph = try Graph.init(std.testing.allocator, 5);
    defer graph.deinit();

    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 3);
    try graph.addEdge(3, 4);
    try graph.addEdge(4, 0);

    const walks = try Node2Vec.simulateWalks(
        std.testing.allocator,
        &graph,
        2,
        5,
        2,
    );

    try std.testing.expectEqual(@as(usize, 10), walks.len);
    for (walks) |walk| {
        try std.testing.expectEqual(@as(usize, 5), walk.len);
        std.testing.allocator.free(walk);
    }
    std.testing.allocator.free(walks);
}
