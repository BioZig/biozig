const std = @import("std");

/// Key-value metadata pair for phylogenetic nodes.
pub const MetadataEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// Represents a node in a phylogenetic tree.
pub const PhyloNode = struct {
    id: usize,
    label: []const u8,
    branch_length: f64,
    children: []const usize,
    metadata: []const MetadataEntry,

    pub fn init(
        id: usize,
        label: []const u8,
        branch_length: f64,
        children: []const usize,
        metadata: []const MetadataEntry,
    ) PhyloNode {
        return .{
            .id = id,
            .label = label,
            .branch_length = branch_length,
            .children = children,
            .metadata = metadata,
        };
    }

    pub fn isLeaf(self: PhyloNode) bool {
        return self.children.len == 0;
    }
};

/// Represents a phylogenetic tree structure using dense node storage.
pub const PhyloTree = struct {
    nodes: []const PhyloNode,
    root: usize,
    is_rooted: bool,

    pub fn init(nodes: []const PhyloNode, root: usize, is_rooted: bool) PhyloTree {
        return .{
            .nodes = nodes,
            .root = root,
            .is_rooted = is_rooted,
        };
    }

    /// Recursively counts the number of leaf nodes under a given node.
    pub fn countLeaves(self: PhyloTree, node_idx: usize) usize {
        const node = self.nodes[node_idx];
        if (node.isLeaf()) return 1;
        var count: usize = 0;
        for (node.children) |child_idx| {
            count += self.countLeaves(child_idx);
        }
        return count;
    }

    /// Recursively finds the maximum depth (cumulative branch length) from a node to any leaf.
    pub fn maxDepth(self: PhyloTree, node_idx: usize) f64 {
        const node = self.nodes[node_idx];
        if (node.isLeaf()) return node.branch_length;
        var max_child_depth: f64 = 0.0;
        for (node.children) |child_idx| {
            max_child_depth = @max(max_child_depth, self.maxDepth(child_idx));
        }
        return node.branch_length + max_child_depth;
    }

    const DrawLine = struct {
        x1: f64,
        y1: f64,
        x2: f64,
        y2: f64,
    };

    const DrawLabel = struct {
        x: f64,
        y: f64,
        text: []const u8,
    };

    /// Renders a deterministic horizontal cladogram of the phylogenetic tree to SVG.
    pub fn renderSvg(self: PhyloTree, writer: anytype, allocator: std.mem.Allocator) !void {
        const width: f64 = 600.0;
        const height: f64 = 400.0;
        const margin_left: f64 = 50.0;
        const margin_right: f64 = 120.0; // Extra room for leaf labels
        const margin_top: f64 = 40.0;
        const margin_bottom: f64 = 40.0;

        const num_leaves = self.countLeaves(self.root);
        const tree_w = width - margin_left - margin_right;
        const tree_h = height - margin_top - margin_bottom;
        const leaf_spacing = if (num_leaves > 1) tree_h / @as(f64, @floatFromInt(num_leaves - 1)) else tree_h;

        const max_tree_depth = self.maxDepth(self.root);
        const depth_scale = if (max_tree_depth == 0.0) 1.0 else tree_w / max_tree_depth;

        var lines = std.ArrayList(DrawLine).empty;
        defer lines.deinit(allocator);
        var labels = std.ArrayList(DrawLabel).empty;
        defer labels.deinit(allocator);

        var leaf_counter: usize = 0;

        _ = try self.layoutNode(
            self.root,
            margin_left,
            &leaf_counter,
            leaf_spacing,
            margin_top,
            depth_scale,
            &lines,
            &labels,
            allocator,
        );

        // Render SVG elements
        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
        , .{ width, height, width, height });

        // Draw branches
        for (lines.items) |line| {
            try writer.print(
                \\<line x1="{d:.2}" y1="{d:.2}" x2="{d:.2}" y2="{d:.2}" stroke="#333333" stroke-width="1.5" stroke-linecap="round"/>
            , .{ line.x1, line.y1, line.x2, line.y2 });
        }

        // Draw leaf labels
        for (labels.items) |lbl| {
            try writer.print(
                \\<text x="{d:.2}" y="{d:.2}" font-family="monospace" font-size="10" fill="#333333" dominant-baseline="middle">{s}</text>
            , .{ lbl.x, lbl.y, lbl.text });
        }

        try writer.writeAll("</svg>\n");
    }

    fn layoutNode(
        self: PhyloTree,
        node_idx: usize,
        parent_x: f64,
        leaf_counter: *usize,
        leaf_spacing: f64,
        margin_top: f64,
        depth_scale: f64,
        lines: *std.ArrayList(DrawLine),
        labels: *std.ArrayList(DrawLabel),
        allocator: std.mem.Allocator,
    ) !f64 {
        const node = self.nodes[node_idx];
        const x = parent_x + node.branch_length * depth_scale;

        if (node.isLeaf()) {
            const y = @as(f64, @floatFromInt(leaf_counter.*)) * leaf_spacing + margin_top;
            leaf_counter.* += 1;

            // Draw branch line from parent to leaf
            try lines.append(allocator, .{ .x1 = parent_x, .y1 = y, .x2 = x, .y2 = y });

            // Add label
            try labels.append(allocator, .{ .x = x + 5.0, .y = y, .text = node.label });
            return y;
        } else {
            var child_ys = std.ArrayList(f64).empty;
            defer child_ys.deinit(allocator);

            for (node.children) |child_idx| {
                const cy = try layoutNode(
                    self,
                    child_idx,
                    x,
                    leaf_counter,
                    leaf_spacing,
                    margin_top,
                    depth_scale,
                    lines,
                    labels,
                    allocator,
                );
                try child_ys.append(allocator, cy);
            }

            // Internal node Y is the average of its children
            var sum_y: f64 = 0.0;
            for (child_ys.items) |cy| {
                sum_y += cy;
            }
            const y = sum_y / @as(f64, @floatFromInt(child_ys.items.len));

            // Draw horizontal branch line from parent to this internal node
            try lines.append(allocator, .{ .x1 = parent_x, .y1 = y, .x2 = x, .y2 = y });

            // Draw vertical line connecting children at this node's X position
            var min_y = child_ys.items[0];
            var max_y = min_y;
            for (child_ys.items) |cy| {
                min_y = @min(min_y, cy);
                max_y = @max(max_y, cy);
            }
            try lines.append(allocator, .{ .x1 = x, .y1 = min_y, .x2 = x, .y2 = max_y });

            return y;
        }
    }
};

test "Phylogenetic tree visualization" {
    const allocator = std.testing.allocator;

    const leaf1 = PhyloNode.init(1, "E.coli", 0.1, &[_]usize{}, &[_]MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "S.enterica", 0.15, &[_]usize{}, &[_]MetadataEntry{});
    const children = [_]usize{ 0, 1 };

    const root = PhyloNode.init(0, "Root", 0.0, &children, &[_]MetadataEntry{});
    const nodes = [_]PhyloNode{ leaf1, leaf2, root };
    const tree = PhyloTree.init(&nodes, 2, true);

    try std.testing.expectEqual(tree.countLeaves(tree.root), 2);
    try std.testing.expectApproxEqAbs(tree.maxDepth(tree.root), 0.15, 1e-5);

    var buf: [2048]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try tree.renderSvg(&fbs, allocator);
    try std.testing.expect(fbs.buffered().len > 0);
}
