const std = @import("std");

/// A node in a cell lineage tree.
pub const LineageNode = struct {
    allocator: std.mem.Allocator,
    cell_id: []const u8,
    parent: ?*LineageNode = null,
    children: std.ArrayList(*LineageNode),

    pub fn init(allocator: std.mem.Allocator, cell_id: []const u8) !*LineageNode {
        const node = try allocator.create(LineageNode);
        node.* = .{
            .allocator = allocator,
            .cell_id = try allocator.dupe(u8, cell_id),
            .children = .empty,
        };
        return node;
    }

    pub fn deinit(self: *LineageNode) void {
        self.allocator.free(self.cell_id);
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn addChild(self: *LineageNode, child: *LineageNode) !void {
        try self.children.append(self.allocator, child);
        child.parent = self;
    }

    pub fn serialize(self: *LineageNode, writer: anytype) !void {
        const core = @import("core");
        try core.serialization.serialize(writer, self.cell_id);
        try core.serialization.serialize(writer, @as(u64, self.children.items.len));
        for (self.children.items) |child| {
            try child.serialize(writer);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !*LineageNode {
        const core = @import("core");
        const cell_id = try core.serialization.deserialize(reader, []const u8, allocator);
        const node = try LineageNode.init(allocator, cell_id);
        allocator.free(cell_id); // init dupes it
        
        const child_count = try core.serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < child_count) : (i += 1) {
            const child = try LineageNode.deserialize(reader, allocator);
            try node.addChild(child);
        }
        return node;
    }
};

/// Represents a complete cell lineage tree.
pub const LineageTree = struct {
    allocator: std.mem.Allocator,
    root: ?*LineageNode = null,

    pub fn init(allocator: std.mem.Allocator) LineageTree {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LineageTree) void {
        if (self.root) |r| r.deinit();
    }

    pub fn serialize(self: LineageTree, writer: anytype) !void {
        const core = @import("core");
        if (self.root) |r| {
            try core.serialization.writeByte(writer, 1);
            try r.serialize(writer);
        } else {
            try core.serialization.writeByte(writer, 0);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !LineageTree {
        const core = @import("core");
        var tree = LineageTree.init(allocator);
        const has_root = try core.serialization.deserialize(reader, u8, allocator);
        if (has_root == 1) {
            tree.root = try LineageNode.deserialize(reader, allocator);
        }
        return tree;
    }

    /// Finds a node by cell_id using breadth-first search.
    pub fn findNode(self: LineageTree, cell_id: []const u8) ?*LineageNode {
        const r = self.root orelse return null;
        var queue = std.ArrayList(*LineageNode).empty;
        defer queue.deinit(self.allocator);
        queue.append(self.allocator, r) catch return null;

        var i: usize = 0;
        while (i < queue.items.len) : (i += 1) {
            const current = queue.items[i];
            if (std.mem.eql(u8, current.cell_id, cell_id)) return current;
            for (current.children.items) |child| {
                queue.append(self.allocator, child) catch return null;
            }
        }
        return null;
    }

    /// Returns the ancestry of a node (root to parent).
    pub fn getAncestry(self: LineageTree, node: *LineageNode, allocator: std.mem.Allocator) ![]*LineageNode {
        _ = self;
        var ancestry = std.ArrayList(*LineageNode).empty;
        var current: ?*LineageNode = node.parent;
        while (current) |p| {
            try ancestry.append(allocator, p);
            current = p.parent;
        }
        std.mem.reverse(*LineageNode, ancestry.items);
        return ancestry.toOwnedSlice(allocator);
    }
};

test "LineageTree traversal and ancestry" {
    const alloc = std.testing.allocator;
    var tree = LineageTree.init(alloc);
    defer tree.deinit();
    
    const root = try LineageNode.init(alloc, "Zygote");
    tree.root = root;
    
    const c1 = try LineageNode.init(alloc, "Cell_1");
    try root.addChild(c1);
    
    const c2 = try LineageNode.init(alloc, "Cell_2");
    try c1.addChild(c2);
    
    const found = tree.findNode("Cell_2");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Cell_2", found.?.cell_id);
    
    const ancestry = try tree.getAncestry(c2, alloc);
    defer alloc.free(ancestry);
    try std.testing.expectEqual(@as(usize, 2), ancestry.len);
    try std.testing.expectEqualStrings("Zygote", ancestry[0].cell_id);
    try std.testing.expectEqualStrings("Cell_1", ancestry[1].cell_id);
}
