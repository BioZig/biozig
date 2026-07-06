const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const pathway = systems.pathway;

test "Pathway - Initial state" {
    const alloc = testing.allocator;
    var path = try pathway.Pathway.init(alloc, "P1", "Metabolism");
    defer path.deinit();
    try testing.expectEqualStrings("P1", path.id);
    try testing.expectEqual(@as(usize, 0), path.memberCount());
}

test "Pathway - Membership operations" {
    const alloc = testing.allocator;
    var path = try pathway.Pathway.init(alloc, "P1", "Metabolism");
    defer path.deinit();

    try path.addMember("GENE_X");
    try testing.expectEqual(@as(usize, 1), path.memberCount());
    try testing.expect(path.hasMember("GENE_X"));
    try testing.expect(!path.hasMember("GENE_Y"));
}

test "Pathway - Redundant addition" {
    const alloc = testing.allocator;
    var path = try pathway.Pathway.init(alloc, "P1", "Metabolism");
    defer path.deinit();

    try path.addMember("GENE_X");
    try path.addMember("GENE_X");
    try testing.expectEqual(@as(usize, 1), path.memberCount());
}
