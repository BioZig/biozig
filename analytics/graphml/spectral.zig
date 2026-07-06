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

pub const Spectral = struct {
    /// computes unnormalized Laplacian L = D - A
    pub fn computeLaplacian(allocator: std.mem.Allocator, graph: *const Graph) ![]f64 {
        const n = graph.adj.items.len;
        const L = try allocator.alloc(f64, n * n);
        @memset(L, 0.0);

        var i: usize = 0;
        while (i < n) : (i += 1) {
            const degree = graph.adj.items[i].items.len;
            L[i * n + i] = @as(f64, @floatFromInt(degree));
            for (graph.adj.items[i].items) |neighbor| {
                L[i * n + neighbor] = -1.0;
            }
        }
        return L;
    }
};

test "spectral laplacian" {
    var graph = try Graph.init(std.testing.allocator, 3);
    defer graph.deinit();

    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);

    const L = try Spectral.computeLaplacian(std.testing.allocator, &graph);
    defer std.testing.allocator.free(L);

    // Node 0: degree 1, connected to 1
    try std.testing.expectEqual(@as(f64, 1.0), L[0 * 3 + 0]);
    try std.testing.expectEqual(@as(f64, -1.0), L[0 * 3 + 1]);
    try std.testing.expectEqual(@as(f64, 0.0), L[0 * 3 + 2]);

    // Node 1: degree 2, connected to 0, 2
    try std.testing.expectEqual(@as(f64, -1.0), L[1 * 3 + 0]);
    try std.testing.expectEqual(@as(f64, 2.0), L[1 * 3 + 1]);
    try std.testing.expectEqual(@as(f64, -1.0), L[1 * 3 + 2]);

    // Node 2: degree 1, connected to 1
    try std.testing.expectEqual(@as(f64, 0.0), L[2 * 3 + 0]);
    try std.testing.expectEqual(@as(f64, -1.0), L[2 * 3 + 1]);
    try std.testing.expectEqual(@as(f64, 1.0), L[2 * 3 + 2]);
}
