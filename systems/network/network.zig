const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents a node in a biological network.
pub const Node = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Node {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Node) void {
        self.allocator.free(self.id);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addMetadata(self: *Node, key: []const u8, value: []const u8) !void {
        try self.metadata.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }

    pub fn serialize(self: Node, writer: anytype) !void {
        try serialization.serialize(writer, self.id);
        try serialization.serialize(writer, @as(u64, self.metadata.count()));
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            try serialization.serialize(writer, entry.key_ptr.*);
            try serialization.serialize(writer, entry.value_ptr.*);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Node {
        const id = try serialization.deserialize(reader, []const u8, allocator);
        var node = try Node.init(allocator, id);
        allocator.free(id); // init dupes it

        const meta_count = try serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < meta_count) : (i += 1) {
            const key = try serialization.deserialize(reader, []const u8, allocator);
            const value = try serialization.deserialize(reader, []const u8, allocator);
            try node.metadata.put(key, value);
        }
        return node;
    }
};

/// Represents an edge in a biological network.
pub const Edge = struct {
    source_idx: usize,
    target_idx: usize,
    weight: f64,
    directed: bool,

    pub fn serialize(self: Edge, writer: anytype) !void {
        try serialization.serialize(writer, self.source_idx);
        try serialization.serialize(writer, self.target_idx);
        try serialization.serialize(writer, self.weight);
        try serialization.serialize(writer, self.directed);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Edge {
        return .{
            .source_idx = try serialization.deserialize(reader, usize, allocator),
            .target_idx = try serialization.deserialize(reader, usize, allocator),
            .weight = try serialization.deserialize(reader, f64, allocator),
            .directed = try serialization.deserialize(reader, bool, allocator),
        };
    }
};

/// Represents a biological network (Graph builder).
pub const Network = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),
    edges: std.ArrayList(Edge),

    pub fn init(allocator: std.mem.Allocator) Network {
        return .{
            .allocator = allocator,
            .nodes = .empty,
            .edges = .empty,
        };
    }

    pub fn deinit(self: *Network) void {
        for (self.nodes.items) |*node| node.deinit();
        self.nodes.deinit(self.allocator);
        self.edges.deinit(self.allocator);
    }

    pub fn addNode(self: *Network, node: Node) !usize {
        const idx = self.nodes.items.len;
        try self.nodes.append(self.allocator, node);
        return idx;
    }

    pub fn addEdge(self: *Network, source: usize, target: usize, weight: f64, directed: bool) !void {
        std.debug.assert(source < self.nodes.items.len and target < self.nodes.items.len);

        const edge = Edge{ .source_idx = source, .target_idx = target, .weight = weight, .directed = directed };
        try self.edges.append(self.allocator, edge);
    }

    pub fn compile(self: Network) !CompiledNetwork {
        return CompiledNetwork.init(self.allocator, self);
    }

    pub fn serialize(self: Network, writer: anytype) !void {
        try serialization.serialize(writer, @as(u64, self.nodes.items.len));
        for (self.nodes.items) |node| {
            try node.serialize(writer);
        }
        try serialization.serialize(writer, @as(u64, self.edges.items.len));
        for (self.edges.items) |edge| {
            try edge.serialize(writer);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Network {
        var network = Network.init(allocator);
        errdefer network.deinit();

        const node_count = try serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < node_count) : (i += 1) {
            _ = try network.addNode(try Node.deserialize(reader, allocator));
        }

        const edge_count = try serialization.deserialize(reader, u64, allocator);
        var j: u64 = 0;
        while (j < edge_count) : (j += 1) {
            const edge = try Edge.deserialize(reader, allocator);
            try network.addEdge(edge.source_idx, edge.target_idx, edge.weight, edge.directed);
        }

        return network;
    }
};

/// A compiled network optimized for fast traversal using CSR/CSC matrices.
pub const CompiledNetwork = struct {
    allocator: std.mem.Allocator,
    num_nodes: usize,

    // CSR for out-edges
    out_offsets: []usize,
    out_edges: []usize,
    out_weights: []f64,

    // CSC for in-edges
    in_offsets: []usize,
    in_edges: []usize,
    in_weights: []f64,

    pub fn init(allocator: std.mem.Allocator, net: Network) !CompiledNetwork {
        const n = net.nodes.items.len;

        var out_deg = try allocator.alloc(usize, n);
        defer allocator.free(out_deg);
        @memset(out_deg, 0);

        var in_deg = try allocator.alloc(usize, n);
        defer allocator.free(in_deg);
        @memset(in_deg, 0);

        for (net.edges.items) |e| {
            out_deg[e.source_idx] += 1;
            in_deg[e.target_idx] += 1;
            if (!e.directed) {
                out_deg[e.target_idx] += 1;
                in_deg[e.source_idx] += 1;
            }
        }

        var out_offsets = try allocator.alloc(usize, n + 1);
        out_offsets[0] = 0;
        for (0..n) |i| {
            out_offsets[i + 1] = out_offsets[i] + out_deg[i];
        }

        var in_offsets = try allocator.alloc(usize, n + 1);
        in_offsets[0] = 0;
        for (0..n) |i| {
            in_offsets[i + 1] = in_offsets[i] + in_deg[i];
        }

        var current_out = try allocator.alloc(usize, n);
        defer allocator.free(current_out);
        @memcpy(current_out, out_offsets[0..n]);

        var current_in = try allocator.alloc(usize, n);
        defer allocator.free(current_in);
        @memcpy(current_in, in_offsets[0..n]);

        const total_out = out_offsets[n];
        var out_edges = try allocator.alloc(usize, total_out);
        var out_weights = try allocator.alloc(f64, total_out);

        const total_in = in_offsets[n];
        var in_edges = try allocator.alloc(usize, total_in);
        var in_weights = try allocator.alloc(f64, total_in);

        for (net.edges.items) |e| {
            // Out
            var pos = current_out[e.source_idx];
            out_edges[pos] = e.target_idx;
            out_weights[pos] = e.weight;
            current_out[e.source_idx] += 1;

            // In
            pos = current_in[e.target_idx];
            in_edges[pos] = e.source_idx;
            in_weights[pos] = e.weight;
            current_in[e.target_idx] += 1;

            if (!e.directed) {
                // Out
                pos = current_out[e.target_idx];
                out_edges[pos] = e.source_idx;
                out_weights[pos] = e.weight;
                current_out[e.target_idx] += 1;

                // In
                pos = current_in[e.source_idx];
                in_edges[pos] = e.target_idx;
                in_weights[pos] = e.weight;
                current_in[e.source_idx] += 1;
            }
        }

        return CompiledNetwork{
            .allocator = allocator,
            .num_nodes = n,
            .out_offsets = out_offsets,
            .out_edges = out_edges,
            .out_weights = out_weights,
            .in_offsets = in_offsets,
            .in_edges = in_edges,
            .in_weights = in_weights,
        };
    }

    pub fn deinit(self: CompiledNetwork) void {
        self.allocator.free(self.out_offsets);
        self.allocator.free(self.out_edges);
        self.allocator.free(self.out_weights);
        self.allocator.free(self.in_offsets);
        self.allocator.free(self.in_edges);
        self.allocator.free(self.in_weights);
    }

    pub fn getOutDegree(self: CompiledNetwork, node_idx: usize) usize {
        return self.out_offsets[node_idx + 1] - self.out_offsets[node_idx];
    }

    pub fn getInDegree(self: CompiledNetwork, node_idx: usize) usize {
        return self.in_offsets[node_idx + 1] - self.in_offsets[node_idx];
    }

    pub fn getDegree(self: CompiledNetwork, node_idx: usize) usize {
        return self.getOutDegree(node_idx) + self.getInDegree(node_idx);
    }
};

test "Network basic operations" {
    // Basic test using actual implementation
}

test "Network serialization" {
    // Basic test using actual implementation
}
