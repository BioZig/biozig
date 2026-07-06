const std = @import("std");

/// A node in a biological hierarchy (e.g., Anatomy, Taxonomy, Development).
pub const HierarchyNode = struct {
    id: usize,
    parent_id: ?usize,
    value: f64,
};

/// Tree representation for Organismal Hierarchy.
pub const Hierarchy = struct {
    nodes: []const HierarchyNode,
    
    /// Finds all children of a given node in O(N).
    pub fn getChildren(self: Hierarchy, allocator: std.mem.Allocator, node_id: usize) ![]usize {
        var children = std.ArrayList(usize).empty;
        errdefer children.deinit(allocator);

        for (self.nodes) |n| {
            if (n.parent_id == node_id) {
                try children.append(allocator, n.id);
            }
        }
        return children.toOwnedSlice(allocator);
    }

    /// Recursively computes the sum of a node's value and all its descendants.
    pub fn computeCumulativeValue(self: Hierarchy, allocator: std.mem.Allocator, root_id: usize) !f64 {
        var sum: f64 = 0.0;
        
        for (self.nodes) |n| {
            if (n.id == root_id) sum += n.value;
        }

        const children = try self.getChildren(allocator, root_id);
        defer allocator.free(children);

        for (children) |child_id| {
            sum += try self.computeCumulativeValue(allocator, child_id);
        }

        return sum;
    }

    /// Finds the path from a leaf to the root.
    pub fn pathToRoot(self: Hierarchy, allocator: std.mem.Allocator, leaf_id: usize) ![]usize {
        var path = std.ArrayList(usize).empty;
        errdefer path.deinit(allocator);

        var current_id: ?usize = leaf_id;

        while (current_id) |c| {
            try path.append(allocator, c);
            
            var next_parent: ?usize = null;
            for (self.nodes) |n| {
                if (n.id == c) {
                    next_parent = n.parent_id;
                    break;
                }
            }
            current_id = next_parent;
        }

        return path.toOwnedSlice(allocator);
    }
};

/// A Phenotype-to-Disease mapping.
pub const PhenotypeAssociation = struct {
    phenotype_id: usize,
    disease_id: usize,
    confidence_score: f64,
};

pub const DiseaseSummary = struct {
    disease_id: usize,
    associated_phenotypes_count: usize,
    mean_confidence: f64,
};

/// Deterministically summarizes diseases by their associated phenotypes.
pub fn summarizeDiseaseAssociations(allocator: std.mem.Allocator, assocs: []const PhenotypeAssociation) ![]DiseaseSummary {
    var counts = std.AutoHashMap(usize, usize).init(allocator);
    defer counts.deinit();
    
    var sums = std.AutoHashMap(usize, f64).init(allocator);
    defer sums.deinit();

    for (assocs) |a| {
        const c = try counts.getOrPutValue(a.disease_id, 0);
        c.value_ptr.* += 1;
        
        const s = try sums.getOrPutValue(a.disease_id, 0.0);
        s.value_ptr.* += a.confidence_score;
    }

    var summaries = std.ArrayList(DiseaseSummary).empty;
    errdefer summaries.deinit(allocator);

    var it = counts.iterator();
    while (it.next()) |entry| {
        const d_id = entry.key_ptr.*;
        const count = entry.value_ptr.*;
        const sum_conf = sums.get(d_id).?;
        
        try summaries.append(allocator, .{
            .disease_id = d_id,
            .associated_phenotypes_count = count,
            .mean_confidence = sum_conf / @as(f64, @floatFromInt(count)),
        });
    }

    return summaries.toOwnedSlice(allocator);
}

test "Organismal Algorithms - Hierarchy" {
    const alloc = std.testing.allocator;
    const nodes = [_]HierarchyNode{
        .{ .id = 1, .parent_id = null, .value = 10.0 }, // Root
        .{ .id = 2, .parent_id = 1, .value = 5.0 },     // Child 1
        .{ .id = 3, .parent_id = 1, .value = 2.0 },     // Child 2
        .{ .id = 4, .parent_id = 2, .value = 1.0 },     // Grandchild
    };
    const h = Hierarchy{ .nodes = &nodes };

    const cum_sum = try h.computeCumulativeValue(alloc, 1);
    try std.testing.expectEqual(@as(f64, 18.0), cum_sum); // 10+5+2+1

    const path = try h.pathToRoot(alloc, 4);
    defer alloc.free(path);
    try std.testing.expectEqual(@as(usize, 3), path.len);
    try std.testing.expectEqual(@as(usize, 4), path[0]);
    try std.testing.expectEqual(@as(usize, 2), path[1]);
    try std.testing.expectEqual(@as(usize, 1), path[2]);
}

test "Organismal Algorithms - Summaries" {
    const alloc = std.testing.allocator;
    const assocs = [_]PhenotypeAssociation{
        .{ .phenotype_id = 101, .disease_id = 1, .confidence_score = 0.8 },
        .{ .phenotype_id = 102, .disease_id = 1, .confidence_score = 1.0 },
        .{ .phenotype_id = 103, .disease_id = 2, .confidence_score = 0.5 },
    };

    const summaries = try summarizeDiseaseAssociations(alloc, &assocs);
    defer alloc.free(summaries);

    try std.testing.expectEqual(@as(usize, 2), summaries.len);
    
    const d1_idx: usize = if (summaries[0].disease_id == 1) 0 else 1;
    try std.testing.expectEqual(@as(usize, 2), summaries[d1_idx].associated_phenotypes_count);
    try std.testing.expectEqual(@as(f64, 0.9), summaries[d1_idx].mean_confidence);
}
