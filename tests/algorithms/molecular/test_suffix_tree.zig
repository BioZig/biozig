const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const suffix_tree = mol.suffix_tree;

test "SuffixTree - Empty input" {
    var st = try suffix_tree.SuffixTree.init(testing.allocator, "");
    defer st.deinit();
    try st.build();
    try testing.expectEqualStrings("", st.text);
    try testing.expectEqual(@as(usize, 0), st.root.children.count());
}

test "SuffixTree - Single character" {
    var st = try suffix_tree.SuffixTree.init(testing.allocator, "a");
    defer st.deinit();
    try st.build();
    try testing.expect(st.root.children.contains('a'));
}

test "SuffixTree - Repeated characters" {
    var st = try suffix_tree.SuffixTree.init(testing.allocator, "aaaa");
    defer st.deinit();
    try st.build();
    try testing.expect(st.root.children.contains('a'));
}

test "SuffixTree - Banana" {
    var st = try suffix_tree.SuffixTree.init(testing.allocator, "banana$");
    defer st.deinit();
    try st.build();
    try testing.expect(st.root.children.contains('b'));
    try testing.expect(st.root.children.contains('a'));
    try testing.expect(st.root.children.contains('n'));
    try testing.expect(st.root.children.contains('$'));
    try testing.expect(!st.root.children.contains('z'));
}

test "SuffixTree - DNA sequence" {
    var st = try suffix_tree.SuffixTree.init(testing.allocator, "ACGTACGT$");
    defer st.deinit();
    try st.build();
    try testing.expect(st.root.children.contains('A'));
    try testing.expect(st.root.children.contains('C'));
    try testing.expect(st.root.children.contains('G'));
    try testing.expect(st.root.children.contains('T'));
    try testing.expect(st.root.children.contains('$'));
}
