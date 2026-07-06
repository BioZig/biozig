const std = @import("std");
const visualization = @import("visualization");
const phylogeny = visualization.phylogeny;
const newick = @import("newick.zig");

pub const NexusParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) NexusParser {
        return .{ .allocator = allocator };
    }

    pub fn parse(self: NexusParser, input: []const u8) !phylogeny.PhyloTree {
        var in_trees_block = false;
        var newick_str = std.ArrayList(u8).empty;
        defer newick_str.deinit(self.allocator);

        var lines = std.mem.splitScalar(u8, input, '\n');
        var found_tree = false;

        while (lines.next()) |raw_line| {
            var line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0) continue;

            const upper_line = try self.allocator.dupe(u8, line);
            defer self.allocator.free(upper_line);
            for (upper_line) |*c| c.* = std.ascii.toUpper(c.*);

            if (std.mem.startsWith(u8, upper_line, "BEGIN TREES;")) {
                in_trees_block = true;
                continue;
            }

            if (in_trees_block) {
                if (std.mem.startsWith(u8, upper_line, "END;")) {
                    in_trees_block = false;
                    break;
                }

                if (std.mem.startsWith(u8, upper_line, "TREE ")) {
                    if (found_tree) return error.MultipleTreesNotSupported;

                    if (std.mem.indexOfScalar(u8, line, '=')) |eq_idx| {
                        const tree_def = std.mem.trim(u8, line[eq_idx + 1 ..], " \t\r");
                        try newick_str.appendSlice(self.allocator, tree_def);
                        found_tree = true;
                    }
                }
            }
        }

        if (!found_tree) return error.NoTreeFoundInNexus;

        return try newick.parseNewick(self.allocator, newick_str.items);
    }
};

pub fn parseNexus(allocator: std.mem.Allocator, input: []const u8) !phylogeny.PhyloTree {
    var parser = NexusParser.init(allocator);
    return try parser.parse(input);
}

pub fn serializeNexus(tree: phylogeny.PhyloTree, writer: anytype) !void {
    try writer.writeAll("#NEXUS\nBEGIN TREES;\n  TREE tree = ");
    try newick.serializeNewick(tree, writer);
    try writer.writeAll("\nEND;\n");
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

test "nexus valid parse" {
    const valid_nexus =
        \\#NEXUS
        \\BEGIN TAXA;
        \\  TAXLABELS A B C;
        \\END;
        \\BEGIN TREES;
        \\  TREE tree1 = (A:0.1,B:0.2,C:0.3);
        \\END;
    ;
    var tree = try parseNexus(std.testing.allocator, valid_nexus);
    defer {
        var n_parser = newick.NewickParser.init(std.testing.allocator);
        n_parser.freePhyloTree(&tree);
        n_parser.deinit();
    }

    const root = tree.nodes[tree.root];
    try std.testing.expectEqualStrings("A", tree.nodes[root.children[0]].label);
}

test "nexus invalid parse" {
    const invalid_nexus =
        \\#NEXUS
        \\BEGIN TREES;
        \\  TREE tree1 = (A:0.1,B:0.2,C:0.3;
        \\END;
    ;
    try std.testing.expectError(error.MalformedNewickUnbalancedParentheses, parseNexus(std.testing.allocator, invalid_nexus));
}

test "nexus malformed parse" {
    const malformed_nexus =
        \\#NEXUS
        \\BEGIN TAXA;
        \\END;
    ;
    try std.testing.expectError(error.NoTreeFoundInNexus, parseNexus(std.testing.allocator, malformed_nexus));
}

test "nexus serialization and roundtrip" {
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
    try serializeNexus(tree, &writer);

    var round_tree = try parseNexus(std.testing.allocator, out_buf.items);
    defer {
        var n_parser = newick.NewickParser.init(std.testing.allocator);
        n_parser.freePhyloTree(&round_tree);
        n_parser.deinit();
    }

    try std.testing.expectEqualStrings("Root", round_tree.nodes[round_tree.root].label);
}
