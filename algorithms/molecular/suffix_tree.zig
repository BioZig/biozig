const std = @import("std");

pub const SuffixTree = struct {
    pub const Node = struct {
        children: std.AutoHashMapUnmanaged(u8, *Node),
    };

    allocator: std.mem.Allocator,
    text: []const u8,
    root: *Node,

    pub fn init(allocator: std.mem.Allocator, text: []const u8) !SuffixTree {
        const root = try allocator.create(Node);
        root.* = .{ .children = std.AutoHashMapUnmanaged(u8, *Node).empty };
        return SuffixTree{
            .allocator = allocator,
            .text = text,
            .root = root,
        };
    }

    fn freeNode(self: *SuffixTree, node: *Node) void {
        var it = node.children.valueIterator();
        while (it.next()) |child| {
            self.freeNode(child.*);
        }
        node.children.deinit(self.allocator);
        self.allocator.destroy(node);
    }

    pub fn deinit(self: *SuffixTree) void {
        self.freeNode(self.root);
    }
    
    /// O(N^2) naive suffix trie construction algorithm
    pub fn build(self: *SuffixTree) !void {
        for (0..self.text.len) |i| {
            const suffix = self.text[i..];
            var current = self.root;
            for (suffix) |char| {
                const result = try current.children.getOrPut(self.allocator, char);
                if (!result.found_existing) {
                    const next_node = try self.allocator.create(Node);
                    next_node.* = .{ .children = std.AutoHashMapUnmanaged(u8, *Node).empty };
                    result.value_ptr.* = next_node;
                }
                current = result.value_ptr.*;
            }
        }
    }
};

test "Suffix Tree Naive" {
    const alloc = std.testing.allocator;
    var st = try SuffixTree.init(alloc, "banana$");
    defer st.deinit();
    try st.build();
    try std.testing.expectEqualStrings("banana$", st.text);
    
    // Check if 'n' exists from root
    try std.testing.expect(st.root.children.contains('n'));
}
