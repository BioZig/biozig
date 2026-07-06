const std = @import("std");
const organismal = @import("organismal_alg");

const HierarchyNode = organismal.HierarchyNode;
const Hierarchy = organismal.Hierarchy;
const PhenotypeAssociation = organismal.PhenotypeAssociation;
const DiseaseSummary = organismal.DiseaseSummary;

test "Organismal - getChildren empty" {
    const alloc = std.testing.allocator;
    const h = Hierarchy{ .nodes = &[_]HierarchyNode{} };
    const children = try h.getChildren(alloc, 1);
    defer alloc.free(children);
    try std.testing.expectEqual(@as(usize, 0), children.len);
}

test "Organismal - getChildren nonexistent" {
    const alloc = std.testing.allocator;
    const h = Hierarchy{ .nodes = &[_]HierarchyNode{
        .{ .id = 1, .parent_id = 2, .value = 0.0 },
    } };
    const children = try h.getChildren(alloc, 999);
    defer alloc.free(children);
    try std.testing.expectEqual(@as(usize, 0), children.len);
}

test "Organismal - computeCumulativeValue missing root" {
    const alloc = std.testing.allocator;
    const h = Hierarchy{ .nodes = &[_]HierarchyNode{
        .{ .id = 1, .parent_id = null, .value = 5.0 },
    } };
    const sum = try h.computeCumulativeValue(alloc, 999);
    try std.testing.expectEqual(@as(f64, 0.0), sum);
}

test "Organismal - computeCumulativeValue single node" {
    const alloc = std.testing.allocator;
    const h = Hierarchy{ .nodes = &[_]HierarchyNode{
        .{ .id = 1, .parent_id = null, .value = 42.0 },
    } };
    const sum = try h.computeCumulativeValue(alloc, 1);
    try std.testing.expectEqual(@as(f64, 42.0), sum);
}

test "Organismal - pathToRoot nonexistent leaf" {
    const alloc = std.testing.allocator;
    const h = Hierarchy{ .nodes = &[_]HierarchyNode{
        .{ .id = 1, .parent_id = null, .value = 0.0 },
    } };
    const path = try h.pathToRoot(alloc, 999);
    defer alloc.free(path);
    // Path just starts with the leaf and ends immediately because parent is not found
    try std.testing.expectEqual(@as(usize, 1), path.len);
    try std.testing.expectEqual(@as(usize, 999), path[0]);
}

test "Organismal - pathToRoot disconnected component" {
    const alloc = std.testing.allocator;
    const h = Hierarchy{
        .nodes = &[_]HierarchyNode{
            .{ .id = 1, .parent_id = 2, .value = 0.0 },
            // 2 is not in the tree
        },
    };
    const path = try h.pathToRoot(alloc, 1);
    defer alloc.free(path);
    // path is just 1, 2
    try std.testing.expectEqual(@as(usize, 2), path.len);
    try std.testing.expectEqual(@as(usize, 1), path[0]);
    try std.testing.expectEqual(@as(usize, 2), path[1]);
}

test "Organismal - summarizeDiseaseAssociations empty" {
    const alloc = std.testing.allocator;
    const empty_assocs = [_]PhenotypeAssociation{};
    const summaries = try organismal.summarizeDiseaseAssociations(alloc, &empty_assocs);
    defer alloc.free(summaries);
    try std.testing.expectEqual(@as(usize, 0), summaries.len);
}

test "Organismal - summarizeDiseaseAssociations average exact" {
    const alloc = std.testing.allocator;
    const assocs = [_]PhenotypeAssociation{
        .{ .phenotype_id = 10, .disease_id = 7, .confidence_score = 0.0 },
        .{ .phenotype_id = 11, .disease_id = 7, .confidence_score = 1.0 },
        .{ .phenotype_id = 12, .disease_id = 7, .confidence_score = 2.0 },
    };
    const summaries = try organismal.summarizeDiseaseAssociations(alloc, &assocs);
    defer alloc.free(summaries);

    try std.testing.expectEqual(@as(usize, 1), summaries.len);
    try std.testing.expectEqual(@as(usize, 7), summaries[0].disease_id);
    try std.testing.expectEqual(@as(usize, 3), summaries[0].associated_phenotypes_count);
    try std.testing.expectEqual(@as(f64, 1.0), summaries[0].mean_confidence); // (0+1+2)/3 = 1.0
}
