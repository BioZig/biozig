const std = @import("std");
const core = @import("core");

/// Types of anatomical relationships between structures.
pub const AnatomicalRelationshipType = enum(u8) {
    /// Spatial or hierarchical containment (e.g. hypothalamus is part of diencephalon)
    part_of,
    /// Structural connection (e.g. carotid artery connected to aorta)
    connected_to,
    /// Spatial adjacency (e.g. heart adjacent to lungs)
    adjacent_to,
};

/// Represents a distinct anatomical structure (e.g. organ, tissue, region).
pub const AnatomicalStructure = struct {
    /// Anatomical identifier (e.g. UBERON term, like "UBERON:0001893")
    id: []const u8,
    /// Human-readable name of the structure
    name: []const u8,

    /// Initializes an AnatomicalStructure.
    pub fn init(id: []const u8, name: []const u8) AnatomicalStructure {
        return .{
            .id = id,
            .name = name,
        };
    }
};

/// Represents a relationship between two anatomical structures.
pub const AnatomicalRelationship = struct {
    source_id: []const u8,
    target_id: []const u8,
    relationship_type: AnatomicalRelationshipType,

    /// Initializes an AnatomicalRelationship.
    pub fn init(
        source_id: []const u8,
        target_id: []const u8,
        rel_type: AnatomicalRelationshipType,
    ) AnatomicalRelationship {
        return .{
            .source_id = source_id,
            .target_id = target_id,
            .relationship_type = rel_type,
        };
    }
};

/// Represents the hierarchy/DAG of anatomical structures and relationships.
pub const AnatomicalHierarchy = struct {
    structures: []const AnatomicalStructure,
    relationships: []const AnatomicalRelationship,

    /// Initializes an AnatomicalHierarchy.
    pub fn init(
        structures: []const AnatomicalStructure,
        relationships: []const AnatomicalRelationship,
    ) AnatomicalHierarchy {
        return .{
            .structures = structures,
            .relationships = relationships,
        };
    }

    /// Looks up a structure in the hierarchy by its ID.
    pub fn lookup(self: AnatomicalHierarchy, id: []const u8) ?*const AnatomicalStructure {
        for (self.structures) |*s| {
            if (std.mem.eql(u8, s.id, id)) return s;
        }
        return null;
    }

    /// Performs ancestry lookup (recursively following part_of relationships upwards).
    /// Returns a slice of ancestor IDs.
    /// Caller owns the returned slice and must free it.
    pub fn ancestryLookup(
        self: AnatomicalHierarchy,
        id: []const u8,
        allocator: std.mem.Allocator,
    ) ![]const []const u8 {
        var visited = std.StringHashMap(void).init(allocator);
        defer visited.deinit();

        var queue = std.ArrayList([]const u8).empty;
        defer queue.deinit(allocator);

        try queue.append(allocator, id);
        try visited.put(id, {});

        var result = std.ArrayList([]const u8).empty;
        errdefer result.deinit(allocator);

        var head: usize = 0;
        while (head < queue.items.len) : (head += 1) {
            const curr = queue.items[head];
            if (!std.mem.eql(u8, curr, id)) {
                try result.append(allocator, curr);
            }

            for (self.relationships) |rel| {
                if (rel.relationship_type == .part_of and std.mem.eql(u8, rel.source_id, curr)) {
                    const parent = rel.target_id;
                    if (!visited.contains(parent)) {
                        try visited.put(parent, {});
                        try queue.append(allocator, parent);
                    }
                }
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Performs descendant lookup (recursively following part_of relationships downwards).
    /// Returns a slice of descendant IDs.
    /// Caller owns the returned slice and must free it.
    pub fn descendantLookup(
        self: AnatomicalHierarchy,
        id: []const u8,
        allocator: std.mem.Allocator,
    ) ![]const []const u8 {
        var visited = std.StringHashMap(void).init(allocator);
        defer visited.deinit();

        var queue = std.ArrayList([]const u8).empty;
        defer queue.deinit(allocator);

        try queue.append(allocator, id);
        try visited.put(id, {});

        var result = std.ArrayList([]const u8).empty;
        errdefer result.deinit(allocator);

        var head: usize = 0;
        while (head < queue.items.len) : (head += 1) {
            const curr = queue.items[head];
            if (!std.mem.eql(u8, curr, id)) {
                try result.append(allocator, curr);
            }

            for (self.relationships) |rel| {
                if (rel.relationship_type == .part_of and std.mem.eql(u8, rel.target_id, curr)) {
                    const child = rel.source_id;
                    if (!visited.contains(child)) {
                        try visited.put(child, {});
                        try queue.append(allocator, child);
                    }
                }
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Determines if a child structure is transitively part of a parent structure.
    pub fn containmentQuery(
        self: AnatomicalHierarchy,
        child_id: []const u8,
        parent_id: []const u8,
        allocator: std.mem.Allocator,
    ) !bool {
        const ancestors = try self.ancestryLookup(child_id, allocator);
        defer allocator.free(ancestors);
        for (ancestors) |anc| {
            if (std.mem.eql(u8, anc, parent_id)) return true;
        }
        return false;
    }

    /// Validates the integrity of the anatomical hierarchy:
    /// - Checks that all relationships reference valid structures.
    /// - Checks for cycles in part_of relationships.
    pub fn validate(self: AnatomicalHierarchy, allocator: std.mem.Allocator) !void {
        for (self.relationships) |rel| {
            var source_found = false;
            var target_found = false;
            for (self.structures) |s| {
                if (std.mem.eql(u8, s.id, rel.source_id)) source_found = true;
                if (std.mem.eql(u8, s.id, rel.target_id)) target_found = true;
            }
            if (!source_found or !target_found) {
                return error.InvalidStructureReference;
            }
        }

        const num_structures = self.structures.len;
        if (num_structures == 0) return;

        const visited = try allocator.alloc(bool, num_structures);
        defer allocator.free(visited);
        @memset(visited, false);

        const rec_stack = try allocator.alloc(bool, num_structures);
        defer allocator.free(rec_stack);
        @memset(rec_stack, false);

        var i: usize = 0;
        while (i < num_structures) : (i += 1) {
            if (!visited[i]) {
                try self.dfsCheckCycle(i, visited, rec_stack);
            }
        }
    }

    fn dfsCheckCycle(self: AnatomicalHierarchy, u: usize, visited: []bool, rec_stack: []bool) !void {
        visited[u] = true;
        rec_stack[u] = true;

        const u_id = self.structures[u].id;
        for (self.relationships) |rel| {
            if (rel.relationship_type == .part_of and std.mem.eql(u8, rel.source_id, u_id)) {
                const v = self.findStructureIndex(rel.target_id).?;
                if (!visited[v]) {
                    try self.dfsCheckCycle(v, visited, rec_stack);
                } else if (rec_stack[v]) {
                    return error.AnatomicalCycle;
                }
            }
        }

        rec_stack[u] = false;
    }

    fn findStructureIndex(self: AnatomicalHierarchy, id: []const u8) ?usize {
        for (self.structures, 0..) |s, i| {
            if (std.mem.eql(u8, s.id, id)) return i;
        }
        return null;
    }
};

test "AnatomicalHierarchy validation, traversal, and containment queries" {
    const allocator = std.testing.allocator;

    const s1 = AnatomicalStructure.init("UBERON:0001893", "Hypothalamus");
    const s2 = AnatomicalStructure.init("UBERON:0001892", "Diencephalon");
    const s3 = AnatomicalStructure.init("UBERON:0001890", "Forebrain");
    const s4 = AnatomicalStructure.init("UBERON:0000955", "Brain");

    const structures = [_]AnatomicalStructure{ s1, s2, s3, s4 };

    // Valid DAG-like containment
    const rels_valid = [_]AnatomicalRelationship{
        AnatomicalRelationship.init("UBERON:0001893", "UBERON:0001892", .part_of),
        AnatomicalRelationship.init("UBERON:0001892", "UBERON:0001890", .part_of),
        AnatomicalRelationship.init("UBERON:0001890", "UBERON:0000955", .part_of),
        // Additional non-part_of relationship for connectivity
        AnatomicalRelationship.init("UBERON:0001893", "UBERON:0000955", .connected_to),
    };

    const hierarchy = AnatomicalHierarchy.init(&structures, &rels_valid);
    try hierarchy.validate(allocator);

    // Containment queries
    try std.testing.expect(try hierarchy.containmentQuery("UBERON:0001893", "UBERON:0000955", allocator));
    try std.testing.expect(try hierarchy.containmentQuery("UBERON:0001893", "UBERON:0001892", allocator));
    try std.testing.expect(!try hierarchy.containmentQuery("UBERON:0000955", "UBERON:0001893", allocator)); // Brain is not part of Hypothalamus

    // Ancestry and descendant lookups
    const ancestors = try hierarchy.ancestryLookup("UBERON:0001893", allocator);
    defer allocator.free(ancestors);
    try std.testing.expectEqual(ancestors.len, 3);

    const descendants = try hierarchy.descendantLookup("UBERON:0000955", allocator);
    defer allocator.free(descendants);
    try std.testing.expectEqual(descendants.len, 3);

    // Cycle validation
    const rels_cycle = [_]AnatomicalRelationship{
        AnatomicalRelationship.init("UBERON:0001893", "UBERON:0001892", .part_of),
        AnatomicalRelationship.init("UBERON:0001892", "UBERON:0001893", .part_of),
    };
    const hierarchy_cycle = AnatomicalHierarchy.init(structures[0..2], &rels_cycle);
    try std.testing.expectError(error.AnatomicalCycle, hierarchy_cycle.validate(allocator));
}
