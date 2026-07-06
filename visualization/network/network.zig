const std = @import("std");

/// Represents a node in a biological network.
pub const Node = struct {
    id: []const u8,
    label: []const u8,
    group: []const u8,
    annotation: []const u8,

    pub fn init(id: []const u8, label: []const u8, group: []const u8, annotation: []const u8) Node {
        return .{
            .id = id,
            .label = label,
            .group = group,
            .annotation = annotation,
        };
    }
};

/// Represents an edge in a biological network.
pub const Edge = struct {
    source: []const u8,
    target: []const u8,
    weight: f64,
    is_directed: bool,
    annotation: []const u8,

    pub fn init(source: []const u8, target: []const u8, weight: f64, is_directed: bool, annotation: []const u8) Edge {
        return .{
            .source = source,
            .target = target,
            .weight = weight,
            .is_directed = is_directed,
            .annotation = annotation,
        };
    }
};

/// Layout coordinates and styling for a node.
pub const NodeLayout = struct {
    id: []const u8,
    label: []const u8,
    x: f64,
    y: f64,
    color: []const u8,
    size: f64,
};

/// Layout coordinates for an edge.
pub const EdgeLayout = struct {
    source_id: []const u8,
    target_id: []const u8,
    x1: f64,
    y1: f64,
    x2: f64,
    y2: f64,
    weight: f64,
    is_directed: bool,
};

/// A compiled visual network layout ready for rendering.
pub const NetworkLayout = struct {
    nodes: []const NodeLayout,
    edges: []const EdgeLayout,
    width: f64,
    height: f64,

    pub fn init(nodes: []const NodeLayout, edges: []const EdgeLayout, width: f64, height: f64) NetworkLayout {
        return .{
            .nodes = nodes,
            .edges = edges,
            .width = width,
            .height = height,
        };
    }

    /// Renders a deterministic SVG representation of the network graph.
    /// Directed edges use a custom arrow marker. Edge stroke widths reflect their weights.
    pub fn renderSvg(self: NetworkLayout, writer: anytype) !void {
        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<defs>
            \\  <marker id="arrow" viewBox="0 0 10 10" refX="16" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            \\    <path d="M 0 0 L 10 5 L 0 10 z" fill="#888888"/>
            \\  </marker>
            \\</defs>
            \\<rect width="100%" height="100%" fill="#ffffff"/>
        , .{ self.width, self.height, self.width, self.height });

        // 1. Draw edges
        for (self.edges) |edge| {
            const stroke_width = @max(0.5, @min(5.0, edge.weight));
            const marker_str = if (edge.is_directed) " marker-end=\"url(#arrow)\"" else "";
            try writer.print(
                \\<line x1="{d:.2}" y1="{d:.2}" x2="{d:.2}" y2="{d:.2}" stroke="#bbbbbb" stroke-width="{d:.2}"{s}/>
            , .{ edge.x1, edge.y1, edge.x2, edge.y2, stroke_width, marker_str });
        }

        // 2. Draw nodes
        for (self.nodes) |node| {
            try writer.print(
                \\<circle cx="{d:.2}" cy="{d:.2}" r="{d:.2}" fill="{s}" stroke="#ffffff" stroke-width="1.5"/>
                \\<text x="{d:.2}" y="{d:.2}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#333333" dominant-baseline="text-after-edge">{s}</text>
            , .{ node.x, node.y, node.size, node.color, node.x, node.y - node.size - 2.0, node.label });
        }

        try writer.writeAll("</svg>\n");
    }
};

/// Computes a circular layout where nodes are distributed evenly along a circle.
/// Completely deterministic.
pub fn circularLayout(
    nodes: []const Node,
    width: f64,
    height: f64,
    allocator: std.mem.Allocator,
) ![]const NodeLayout {
    const n = nodes.len;
    const layouts = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(layouts);

    const cx = width / 2.0;
    const cy = height / 2.0;
    const r = @min(width, height) / 2.0 * 0.75;

    for (nodes, 0..) |node, i| {
        const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        layouts[i] = .{
            .id = node.id,
            .label = node.label,
            .x = cx + r * @cos(angle),
            .y = cy + r * @sin(angle),
            .color = groupColor(node.group),
            .size = 8.0,
        };
    }
    return layouts;
}

/// Computes a grid layout where nodes are aligned in rows and columns.
/// Completely deterministic.
pub fn gridLayout(
    nodes: []const Node,
    width: f64,
    height: f64,
    allocator: std.mem.Allocator,
) ![]const NodeLayout {
    const n = nodes.len;
    const layouts = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(layouts);

    if (n == 0) return layouts;

    const cols = @as(usize, @intFromFloat(@ceil(@sqrt(@as(f64, @floatFromInt(n))))));
    const rows = (n + cols - 1) / cols;

    const dx = width / @as(f64, @floatFromInt(cols + 1));
    const dy = height / @as(f64, @floatFromInt(rows + 1));

    for (nodes, 0..) |node, i| {
        const col = i % cols;
        const row = i / cols;
        layouts[i] = .{
            .id = node.id,
            .label = node.label,
            .x = dx * @as(f64, @floatFromInt(col + 1)),
            .y = dy * @as(f64, @floatFromInt(row + 1)),
            .color = groupColor(node.group),
            .size = 8.0,
        };
    }
    return layouts;
}

/// Helper mapping network group identifiers to standard colors.
fn groupColor(group: []const u8) []const u8 {
    if (std.mem.eql(u8, group, "A") or std.mem.eql(u8, group, "1")) return "#1f77b4";
    if (std.mem.eql(u8, group, "B") or std.mem.eql(u8, group, "2")) return "#ff7f0e";
    if (std.mem.eql(u8, group, "C") or std.mem.eql(u8, group, "3")) return "#2ca02c";
    return "#9467bd"; // Default purple
}

/// Helper mapping node layout positions to construct EdgeLayouts.
pub fn computeEdgeLayouts(
    edges: []const Edge,
    node_layouts: []const NodeLayout,
    allocator: std.mem.Allocator,
) ![]const EdgeLayout {
    var list = std.ArrayList(EdgeLayout).empty;
    errdefer list.deinit(allocator);

    for (edges) |edge| {
        var n1: ?NodeLayout = null;
        var n2: ?NodeLayout = null;
        for (node_layouts) |nl| {
            if (std.mem.eql(u8, nl.id, edge.source)) n1 = nl;
            if (std.mem.eql(u8, nl.id, edge.target)) n2 = nl;
        }

        if (n1 != null and n2 != null) {
            try list.append(allocator, .{
                .source_id = edge.source,
                .target_id = edge.target,
                .x1 = n1.?.x,
                .y1 = n1.?.y,
                .x2 = n2.?.x,
                .y2 = n2.?.y,
                .weight = edge.weight,
                .is_directed = edge.is_directed,
            });
        }
    }

    return list.toOwnedSlice(allocator);
}

test "Network layouts and rendering" {
    const allocator = std.testing.allocator;

    const n1 = Node.init("N1", "Node 1", "A", "Receptor");
    const n2 = Node.init("N2", "Node 2", "B", "Kinase");
    const nodes = [_]Node{ n1, n2 };

    const e1 = Edge.init("N1", "N2", 2.5, true, "Phosphorylates");
    const edges = [_]Edge{e1};

    // Circular layout
    const node_layouts = try circularLayout(&nodes, 500.0, 500.0, allocator);
    defer allocator.free(node_layouts);

    const edge_layouts = try computeEdgeLayouts(&edges, node_layouts, allocator);
    defer allocator.free(edge_layouts);

    try std.testing.expectEqual(node_layouts.len, 2);
    try std.testing.expectEqual(edge_layouts.len, 1);

    const net = NetworkLayout.init(node_layouts, edge_layouts, 500.0, 500.0);

    var buf: [1024]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try net.renderSvg(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
