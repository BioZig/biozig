const std = @import("std");
const visualization = @import("visualization");
const phylogeny = visualization.phylogeny;

pub const PhyloXmlParser = struct {
    allocator: std.mem.Allocator,
    interner: std.StringHashMap(usize),
    next_id: usize,
    nodes: std.ArrayList(phylogeny.PhyloNode),

    pub fn init(allocator: std.mem.Allocator) PhyloXmlParser {
        return .{
            .allocator = allocator,
            .interner = std.StringHashMap(usize).init(allocator),
            .next_id = 1,
            .nodes = std.ArrayList(phylogeny.PhyloNode).empty,
        };
    }

    pub fn deinit(self: *PhyloXmlParser) void {
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

    fn getId(self: *PhyloXmlParser, label: []const u8) !usize {
        if (self.interner.get(label)) |val| return val;
        const new_id = self.next_id;
        self.next_id += 1;
        try self.interner.put(try self.allocator.dupe(u8, label), new_id);
        return new_id;
    }

    const CladeData = struct {
        name: []const u8 = "",
        branch_length: f64 = 0.0,
        children: std.ArrayList(usize),
        metadata: std.ArrayList(phylogeny.MetadataEntry),
    };

    pub fn parse(self: *PhyloXmlParser, input: []const u8) !phylogeny.PhyloTree {
        var frames = std.ArrayList(CladeData).empty;
        defer {
            for (frames.items) |*f| {
                f.children.deinit(self.allocator);
                for (f.metadata.items) |m| {
                    self.allocator.free(m.key);
                    self.allocator.free(m.value);
                }
                f.metadata.deinit(self.allocator);
            }
            frames.deinit(self.allocator);
        }

        var idx: usize = 0;
        var root_idx_opt: ?usize = null;

        while (idx < input.len) {
            const next_open = std.mem.indexOfPos(u8, input, idx, "<");
            if (next_open == null) break;
            idx = next_open.? + 1;

            if (std.mem.startsWith(u8, input[idx..], "clade>") or std.mem.startsWith(u8, input[idx..], "clade ")) {
                idx += 5; // "clade"
                while (idx < input.len and input[idx] != '>') : (idx += 1) {}
                if (idx < input.len) idx += 1;

                try frames.append(self.allocator, .{
                    .children = std.ArrayList(usize).empty,
                    .metadata = std.ArrayList(phylogeny.MetadataEntry).empty,
                });
            } else if (std.mem.startsWith(u8, input[idx..], "/clade>")) {
                idx += 7; // "/clade>"

                var clade = frames.pop() orelse return error.MalformedPhyloXml;
                errdefer {
                    clade.children.deinit(self.allocator);
                    for (clade.metadata.items) |m| {
                        self.allocator.free(m.key);
                        self.allocator.free(m.value);
                    }
                    clade.metadata.deinit(self.allocator);
                }

                const id = try self.getId(clade.name);
                const node = phylogeny.PhyloNode.init(
                    id,
                    try self.allocator.dupe(u8, clade.name),
                    clade.branch_length,
                    try clade.children.toOwnedSlice(self.allocator),
                    try clade.metadata.toOwnedSlice(self.allocator),
                );
                const node_idx = self.nodes.items.len;
                try self.nodes.append(self.allocator, node);

                if (frames.items.len > 0) {
                    try frames.items[frames.items.len - 1].children.append(self.allocator, node_idx);
                } else {
                    root_idx_opt = node_idx;
                }
            } else if (std.mem.startsWith(u8, input[idx..], "name>")) {
                idx += 5;
                const name_end = std.mem.indexOfPos(u8, input, idx, "</name>");
                if (name_end) |end_pos| {
                    if (frames.items.len > 0) {
                        frames.items[frames.items.len - 1].name = input[idx..end_pos];
                    }
                    idx = end_pos + 7;
                } else {
                    return error.MalformedPhyloXml;
                }
            } else if (std.mem.startsWith(u8, input[idx..], "branch_length>")) {
                idx += 14;
                const len_end = std.mem.indexOfPos(u8, input, idx, "</branch_length>");
                if (len_end) |end_pos| {
                    const len_str = input[idx..end_pos];
                    const val = std.fmt.parseFloat(f64, std.mem.trim(u8, len_str, " \t\r\n")) catch 0.0;
                    if (frames.items.len > 0) {
                        frames.items[frames.items.len - 1].branch_length = val;
                    }
                    idx = end_pos + 16;
                } else {
                    return error.MalformedPhyloXml;
                }
            } else {
                // Ignore any other tag by just finding next closing brace
                const next_close = std.mem.indexOfPos(u8, input, idx, ">");
                if (next_close) |c_idx| {
                    idx = c_idx + 1;
                }
            }
        }

        if (root_idx_opt) |root_idx| {
            if (frames.items.len != 0) return error.MalformedPhyloXml;
            return phylogeny.PhyloTree.init(try self.nodes.toOwnedSlice(self.allocator), root_idx, true);
        }
        return error.NoCladeFoundInPhyloXml;
    }

    pub fn freePhyloTree(self: *PhyloXmlParser, tree: *phylogeny.PhyloTree) void {
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

pub fn parsePhyloXml(allocator: std.mem.Allocator, input: []const u8) !phylogeny.PhyloTree {
    var parser = PhyloXmlParser.init(allocator);
    defer parser.deinit();
    return try parser.parse(input);
}

pub fn serializePhyloXml(tree: phylogeny.PhyloTree, writer: anytype) !void {
    try writer.writeAll("<phyloxml>\n  <phylogeny>\n");
    try serializeNode(tree, tree.root, writer, 2);
    try writer.writeAll("  </phylogeny>\n</phyloxml>\n");
}

fn serializeNode(tree: phylogeny.PhyloTree, node_idx: usize, writer: anytype, depth: usize) !void {
    const node = tree.nodes[node_idx];
    try indent(writer, depth);
    try writer.writeAll("<clade>\n");

    if (node.label.len > 0) {
        try indent(writer, depth + 1);
        try writer.writeAll("<name>");
        try writer.writeAll(node.label);
        try writer.writeAll("</name>\n");
    }

    if (node.branch_length > 0.0) {
        try indent(writer, depth + 1);
        try writer.writeAll("<branch_length>");
        var buf: [64]u8 = undefined;
        const len_str = try std.fmt.bufPrint(&buf, "{d}", .{node.branch_length});
        try writer.writeAll(len_str);
        try writer.writeAll("</branch_length>\n");
    }

    for (node.children) |child_idx| {
        try serializeNode(tree, child_idx, writer, depth + 1);
    }

    try indent(writer, depth);
    try writer.writeAll("</clade>\n");
}

fn indent(writer: anytype, depth: usize) !void {
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        try writer.writeAll("  ");
    }
}

const StringWriter = struct {
    list: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn writeByte(self: *@This(), b: u8) !void {
        try self.list.append(self.allocator, b);
    }
    pub fn writeAll(self: *@This(), s: []const u8) !void {
        try self.list.appendSlice(self.allocator, s);
    }
    pub fn write(self: *@This(), bytes: []const u8) !usize {
        try self.list.appendSlice(self.allocator, bytes);
        return bytes.len;
    }
};

test "phyloxml valid parse" {
    const valid_xml =
        \\<phyloxml>
        \\  <phylogeny>
        \\    <clade>
        \\      <name>Root</name>
        \\      <clade>
        \\        <name>A</name>
        \\        <branch_length>0.1</branch_length>
        \\      </clade>
        \\      <clade>
        \\        <name>B</name>
        \\        <branch_length>0.2</branch_length>
        \\      </clade>
        \\    </clade>
        \\  </phylogeny>
        \\</phyloxml>
    ;
    var tree = try parsePhyloXml(std.testing.allocator, valid_xml);
    defer {
        var parser = PhyloXmlParser.init(std.testing.allocator);
        parser.freePhyloTree(&tree);
        parser.deinit();
    }

    const root = tree.nodes[tree.root];
    try std.testing.expectEqualStrings("Root", root.label);
    try std.testing.expectEqual(@as(usize, 2), root.children.len);
    try std.testing.expectEqualStrings("A", tree.nodes[root.children[0]].label);
    try std.testing.expectEqual(0.1, tree.nodes[root.children[0]].branch_length);
    try std.testing.expectEqualStrings("B", tree.nodes[root.children[1]].label);
    try std.testing.expectEqual(0.2, tree.nodes[root.children[1]].branch_length);
}

test "phyloxml invalid parse" {
    const invalid_xml =
        \\<phyloxml>
        \\  <phylogeny>
        \\    <clade>
        \\      <name>Root</name>
        \\      <clade>
        \\        <name>A
        \\      </clade>
        \\    </clade>
        \\  </phylogeny>
        \\</phyloxml>
    ;
    try std.testing.expectError(error.MalformedPhyloXml, parsePhyloXml(std.testing.allocator, invalid_xml));
}

test "phyloxml malformed parse" {
    const malformed_xml = "<phyloxml><phylogeny></phylogeny></phyloxml>";
    try std.testing.expectError(error.NoCladeFoundInPhyloXml, parsePhyloXml(std.testing.allocator, malformed_xml));
}

test "phyloxml serialization and roundtrip" {
    const nodes = [_]phylogeny.PhyloNode{phylogeny.PhyloNode{
        .id = 1,
        .label = try std.testing.allocator.dupe(u8, "Root"),
        .branch_length = 0.0,
        .children = &[_]usize{},
        .metadata = &[_]phylogeny.MetadataEntry{},
    }};
    const tree = phylogeny.PhyloTree{
        .nodes = &nodes,
        .root = 0,
        .is_rooted = true,
    };
    defer {
        std.testing.allocator.free(tree.nodes[0].label);
    }

    var out_buf = std.ArrayList(u8).empty;
    defer out_buf.deinit(std.testing.allocator);

    var writer = StringWriter{ .list = &out_buf, .allocator = std.testing.allocator };
    try serializePhyloXml(tree, &writer);

    var round_tree = try parsePhyloXml(std.testing.allocator, out_buf.items);
    defer {
        var parser = PhyloXmlParser.init(std.testing.allocator);
        parser.freePhyloTree(&round_tree);
        parser.deinit();
    }

    try std.testing.expectEqualStrings("Root", round_tree.nodes[round_tree.root].label);
}
