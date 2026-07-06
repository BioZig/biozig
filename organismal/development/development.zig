const std = @import("std");
const core = @import("core");

/// Represents a specific developmental stage (e.g. blastula, gastrula).
pub const DevelopmentalStage = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,

    /// Initializes a DevelopmentalStage struct.
    pub fn init(id: []const u8, name: []const u8, description: []const u8) DevelopmentalStage {
        return .{
            .id = id,
            .name = name,
            .description = description,
        };
    }
};

/// Represents a transition relationship from a parent stage to a child stage.
pub const DevelopmentRelationship = struct {
    parent_id: []const u8,
    child_id: []const u8,

    /// Initializes a DevelopmentRelationship struct.
    pub fn init(parent_id: []const u8, child_id: []const u8) DevelopmentRelationship {
        return .{
            .parent_id = parent_id,
            .child_id = child_id,
        };
    }
};

/// Represents a timeline/graph of developmental stages.
pub const DevelopmentalTimeline = struct {
    stages: []const DevelopmentalStage,
    relationships: []const DevelopmentRelationship,

    /// Initializes a DevelopmentalTimeline.
    pub fn init(
        stages: []const DevelopmentalStage,
        relationships: []const DevelopmentRelationship,
    ) DevelopmentalTimeline {
        return .{
            .stages = stages,
            .relationships = relationships,
        };
    }

    /// Looks up a stage in the timeline by its ID.
    pub fn lookup(self: DevelopmentalTimeline, id: []const u8) ?*const DevelopmentalStage {
        for (self.stages) |*s| {
            if (std.mem.eql(u8, s.id, id)) return s;
        }
        return null;
    }

    /// Validates the integrity of the timeline:
    /// - Checks that all relationships reference valid stages.
    /// - Checks for developmental cycles (e.g. A -> B -> A).
    pub fn validate(self: DevelopmentalTimeline, allocator: std.mem.Allocator) !void {
        // 1. Verify references
        for (self.relationships) |rel| {
            var parent_found = false;
            var child_found = false;
            for (self.stages) |s| {
                if (std.mem.eql(u8, s.id, rel.parent_id)) parent_found = true;
                if (std.mem.eql(u8, s.id, rel.child_id)) child_found = true;
            }
            if (!parent_found or !child_found) {
                return error.InvalidStageReference;
            }
        }

        // 2. Cycle-free check using DFS recursion stack
        const num_stages = self.stages.len;
        if (num_stages == 0) return;

        const visited = try allocator.alloc(bool, num_stages);
        defer allocator.free(visited);
        @memset(visited, false);

        const rec_stack = try allocator.alloc(bool, num_stages);
        defer allocator.free(rec_stack);
        @memset(rec_stack, false);

        var i: usize = 0;
        while (i < num_stages) : (i += 1) {
            if (!visited[i]) {
                try self.dfsCheckCycle(i, visited, rec_stack);
            }
        }
    }

    /// Returns stages sorted in chronological/topological order of progression.
    /// Caller owns the returned slice and must free it.
    pub fn getOrderedStages(self: DevelopmentalTimeline, allocator: std.mem.Allocator) ![]const *const DevelopmentalStage {
        try self.validate(allocator);

        const num_stages = self.stages.len;
        if (num_stages == 0) return &[_]*const DevelopmentalStage{};

        const visited = try allocator.alloc(bool, num_stages);
        defer allocator.free(visited);
        @memset(visited, false);

        var result = std.ArrayList(*const DevelopmentalStage).empty;
        errdefer result.deinit(allocator);

        var i: usize = 0;
        while (i < num_stages) : (i += 1) {
            if (!visited[i]) {
                try self.topoDfs(i, visited, &result, allocator);
            }
        }

        const slice = try result.toOwnedSlice(allocator);
        // Reverse post-order to get topological sort
        var left: usize = 0;
        var right: usize = slice.len - 1;
        while (left < right) {
            std.mem.swap(*const DevelopmentalStage, &slice[left], &slice[right]);
            left += 1;
            right -= 1;
        }
        return slice;
    }

    fn dfsCheckCycle(self: DevelopmentalTimeline, u: usize, visited: []bool, rec_stack: []bool) !void {
        visited[u] = true;
        rec_stack[u] = true;

        const u_id = self.stages[u].id;
        for (self.relationships) |rel| {
            if (std.mem.eql(u8, rel.parent_id, u_id)) {
                const v = self.findStageIndex(rel.child_id).?;
                if (!visited[v]) {
                     try self.dfsCheckCycle(v, visited, rec_stack);
                } else if (rec_stack[v]) {
                     return error.DevelopmentalCycle;
                }
            }
        }

        rec_stack[u] = false;
    }

    fn topoDfs(
        self: DevelopmentalTimeline,
        u: usize,
        visited: []bool,
        result: *std.ArrayList(*const DevelopmentalStage),
        allocator: std.mem.Allocator,
    ) !void {
        visited[u] = true;
        const u_id = self.stages[u].id;
        for (self.relationships) |rel| {
            if (std.mem.eql(u8, rel.parent_id, u_id)) {
                const v = self.findStageIndex(rel.child_id).?;
                if (!visited[v]) {
                    try self.topoDfs(v, visited, result, allocator);
                }
            }
        }
        try result.append(allocator, &self.stages[u]);
    }

    fn findStageIndex(self: DevelopmentalTimeline, id: []const u8) ?usize {
        for (self.stages, 0..) |s, i| {
            if (std.mem.eql(u8, s.id, id)) return i;
        }
        return null;
    }
};

test "Developmental timeline validation and sorting" {
    const allocator = std.testing.allocator;

    const s1 = DevelopmentalStage.init("stage_0", "Zygote", "Fertilized egg cell.");
    const s2 = DevelopmentalStage.init("stage_1", "Cleavage", "Rapid cell division.");
    const s3 = DevelopmentalStage.init("stage_2", "Blastula", "Hollow sphere of cells.");
    const s4 = DevelopmentalStage.init("stage_3", "Gastrula", "Three germ layers form.");

    const stages = [_]DevelopmentalStage{ s1, s2, s3, s4 };

    // 1. Valid linear timeline
    const rels_valid = [_]DevelopmentRelationship{
        DevelopmentRelationship.init("stage_0", "stage_1"),
        DevelopmentRelationship.init("stage_1", "stage_2"),
        DevelopmentRelationship.init("stage_2", "stage_3"),
    };

    const timeline = DevelopmentalTimeline.init(&stages, &rels_valid);
    try timeline.validate(allocator);

    const ordered = try timeline.getOrderedStages(allocator);
    defer allocator.free(ordered);

    try std.testing.expectEqual(ordered.len, 4);
    try std.testing.expectEqualStrings("Zygote", ordered[0].name);
    try std.testing.expectEqualStrings("Cleavage", ordered[1].name);
    try std.testing.expectEqualStrings("Blastula", ordered[2].name);
    try std.testing.expectEqualStrings("Gastrula", ordered[3].name);

    // 2. Timeline with cycle
    const rels_cycle = [_]DevelopmentRelationship{
        DevelopmentRelationship.init("stage_0", "stage_1"),
        DevelopmentRelationship.init("stage_1", "stage_2"),
        DevelopmentRelationship.init("stage_2", "stage_0"), // cycle back
    };
    const timeline_cycle = DevelopmentalTimeline.init(stages[0..3], &rels_cycle);
    try std.testing.expectError(error.DevelopmentalCycle, timeline_cycle.validate(allocator));

    // 3. Timeline with invalid stage reference
    const rels_invalid = [_]DevelopmentRelationship{
        DevelopmentRelationship.init("stage_0", "stage_99"),
    };
    const timeline_invalid = DevelopmentalTimeline.init(&stages, &rels_invalid);
    try std.testing.expectError(error.InvalidStageReference, timeline_invalid.validate(allocator));
}
