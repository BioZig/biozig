const std = @import("std");
const visualization = @import("visualization");
const phylogeny = visualization.phylogeny;

/// Parses a Newick format string/stream to a phylogeny.PhyloTree.
pub const NewickParser = struct {
    allocator: std.mem.Allocator,
    interner: std.StringHashMap(usize),
    next_id: usize,
    nodes: std.ArrayList(phylogeny.PhyloNode),

    pub fn init(allocator: std.mem.Allocator) NewickParser {
        return .{
            .allocator = allocator,
            .interner = std.StringHashMap(usize).init(allocator),
            .next_id = 1,
            .nodes = std.ArrayList(phylogeny.PhyloNode).empty,
        };
    }

    pub fn deinit(self: *NewickParser) void {
        var it = self.interner.keyIterator();
        while (it.next()) |k| self.allocator.free(k.*);
        self.interner.deinit();
        for (self.nodes.items) |node| {
            self.allocator.free(node.label);
            self.allocator.free(node.children);
            for (node.metadata) |m| {
                self.allocator.free(m.key);
                self.allocator.free(m.value);
            }
            self.allocator.free(node.metadata);
        }
        self.nodes.deinit(self.allocator);
    }

    fn getId(self: *NewickParser, label: []const u8) !usize {
        if (self.interner.get(label)) |val| return val;
        const new_id = self.next_id;
        self.next_id += 1;
        try self.interner.put(try self.allocator.dupe(u8, label), new_id);
        return new_id;
    }

    pub fn parse(self: *NewickParser, input_raw: []const u8) !phylogeny.PhyloTree {
        var char_buf = std.ArrayList(u8).empty;
        defer char_buf.deinit(self.allocator);
        for (input_raw) |c| {
            if (!std.ascii.isWhitespace(c)) try char_buf.append(self.allocator, c);
        }
        const input = char_buf.items;
        if (input.len == 0) return error.EmptyNewick;
        if (input[input.len - 1] != ';') return error.MalformedNewickMissingSemicolon;

        var frames = std.ArrayList(std.ArrayList(usize)).empty;
        defer {
            for (frames.items) |*f| f.deinit(self.allocator);
            frames.deinit(self.allocator);
        }
        try frames.append(self.allocator, std.ArrayList(usize).empty);

        var idx: usize = 0;
        var last_node_idx: ?usize = null;

        while (idx < input.len - 1) {
            if (input[idx] == '(') {
                try frames.append(self.allocator, std.ArrayList(usize).empty);
                idx += 1;
            } else if (input[idx] == ',') {
                idx += 1;
            } else if (input[idx] == ')') {
                idx += 1;
                if (frames.items.len == 0) return error.MalformedNewickUnbalancedParentheses;
                var children = frames.pop().?;
                last_node_idx = try self.parseNodeData(input, &idx, try children.toOwnedSlice(self.allocator));
                if (frames.items.len > 0) {
                    try frames.items[frames.items.len - 1].append(self.allocator, last_node_idx.?);
                } else {
                    return error.MalformedNewickUnbalancedParentheses;
                }
            } else {
                last_node_idx = try self.parseNodeData(input, &idx, &[_]usize{});
                if (frames.items.len > 0) {
                    try frames.items[frames.items.len - 1].append(self.allocator, last_node_idx.?);
                } else {
                    return error.MalformedNewickExtraData;
                }
            }
        }

        if (frames.items.len != 1) return error.MalformedNewickUnbalancedParentheses;

        var root_children = frames.pop().?;
        defer root_children.deinit(self.allocator);
        if (root_children.items.len != 1) return error.MalformedNewickExtraData;
        const root_idx = root_children.items[0];

        const root_node = self.nodes.items[root_idx];
        const is_rooted = root_node.children.len <= 2;
        return phylogeny.PhyloTree.init(try self.nodes.toOwnedSlice(self.allocator), root_idx, is_rooted);
    }

    fn parseNodeData(self: *NewickParser, str: []const u8, idx: *usize, children: []const usize) !usize {
        var label: []const u8 = "";
        var branch_len: f64 = 0.0;
        var metadata = std.ArrayList(phylogeny.MetadataEntry).empty;

        // Parse Label
        const label_start = idx.*;
        while (idx.* < str.len and str[idx.*] != ':' and str[idx.*] != '[' and str[idx.*] != ',' and str[idx.*] != ')' and str[idx.*] != ';') : (idx.* += 1) {}
        if (idx.* > label_start) {
            label = str[label_start..idx.*];
        }

        // Parse Branch Length
        if (idx.* < str.len and str[idx.*] == ':') {
            idx.* += 1; // Consume ':'
            const len_start = idx.*;
            while (idx.* < str.len and str[idx.*] != '[' and str[idx.*] != ',' and str[idx.*] != ')' and str[idx.*] != ';') : (idx.* += 1) {}
            if (idx.* > len_start) {
                const len_str = str[len_start..idx.*];
                branch_len = std.fmt.parseFloat(f64, len_str) catch 0.0;
            }
        }

        // Parse Metadata
        if (idx.* < str.len and str[idx.*] == '[') {
            idx.* += 1; // Consume '['
            const meta_start = idx.*;
            while (idx.* < str.len and str[idx.*] != ']') : (idx.* += 1) {}

            if (idx.* >= str.len) {
                for (metadata.items) |m| {
                    self.allocator.free(m.key);
                    self.allocator.free(m.value);
                }
                metadata.deinit(self.allocator);
                return error.MalformedNewickUnbalancedBrackets;
            }

            const meta_str = str[meta_start..idx.*];
            idx.* += 1; // Consume ']'

            if (std.mem.startsWith(u8, meta_str, "&&NHX:")) {
                var kv_tokens = std.mem.splitScalar(u8, meta_str[6..], ':');
                while (kv_tokens.next()) |kv| {
                    if (std.mem.indexOfScalar(u8, kv, '=')) |eq_idx| {
                        const key = kv[0..eq_idx];
                        const val = kv[eq_idx + 1 ..];
                        try metadata.append(self.allocator, .{
                            .key = try self.allocator.dupe(u8, key),
                            .value = try self.allocator.dupe(u8, val),
                        });
                    }
                }
            } else {
                try metadata.append(self.allocator, .{
                    .key = try self.allocator.dupe(u8, "note"),
                    .value = try self.allocator.dupe(u8, meta_str),
                });
            }
        }

        const id = try self.getId(label);

        const node = phylogeny.PhyloNode.init(
            id,
            try self.allocator.dupe(u8, label),
            branch_len,
            children,
            try metadata.toOwnedSlice(self.allocator),
        );

        const node_idx = self.nodes.items.len;
        try self.nodes.append(self.allocator, node);
        return node_idx;
    }

    pub fn freePhyloTree(self: *NewickParser, tree: *phylogeny.PhyloTree) void {
        for (tree.nodes) |node| {
            self.allocator.free(node.label);
            self.allocator.free(node.children);
            for (node.metadata) |m| {
                self.allocator.free(m.key);
                self.allocator.free(m.value);
            }
            self.allocator.free(node.metadata);
        }
        self.allocator.free(tree.nodes);
    }
};

pub fn parseNewick(allocator: std.mem.Allocator, input: []const u8) !phylogeny.PhyloTree {
    var parser = NewickParser.init(allocator);
    defer parser.deinit();
    return try parser.parse(input);
}

pub fn serializeNewick(tree: phylogeny.PhyloTree, writer: anytype) !void {
    try serializeNode(tree, tree.root, writer);
    try writer.writeByte(';');
}

fn serializeNode(tree: phylogeny.PhyloTree, node_idx: usize, writer: anytype) !void {
    const node = tree.nodes[node_idx];
    if (node.children.len > 0) {
        try writer.writeByte('(');
        for (node.children, 0..) |child_idx, i| {
            try serializeNode(tree, child_idx, writer);
            if (i < node.children.len - 1) {
                try writer.writeByte(',');
            }
        }
        try writer.writeByte(')');
    }

    if (node.label.len > 0) {
        try writer.writeAll(node.label);
    }

    if (node.branch_length > 0.0 or node.children.len > 0) {
        try writer.writeByte(':');
        var buf: [64]u8 = undefined;
        const len_str = try std.fmt.bufPrint(&buf, "{d}", .{node.branch_length});
        try writer.writeAll(len_str);
    }

    if (node.metadata.len > 0) {
        try writer.writeAll("[&&NHX");
        for (node.metadata) |m| {
            try writer.writeByte(':');
            try writer.writeAll(m.key);
            try writer.writeByte('=');
            try writer.writeAll(m.value);
        }
        try writer.writeByte(']');
    }
}
