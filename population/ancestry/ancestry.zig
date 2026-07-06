const std = @import("std");

/// Represents a distinct population group.
pub const Population = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8) !Population {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Population) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addMetadata(self: *Population, key: []const u8, value: []const u8) !void {
        try self.metadata.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }
};

/// Represents an evolutionary relationship between populations.
pub const PopulationRelationship = struct {
    allocator: std.mem.Allocator,
    parent_id: []const u8,
    derived_id: []const u8,
    split_time: ?f64,
    admixture_proportion: ?f64,

    pub fn init(allocator: std.mem.Allocator, parent_id: []const u8, derived_id: []const u8, split_time: ?f64, admixture: ?f64) !PopulationRelationship {
        return .{
            .allocator = allocator,
            .parent_id = try allocator.dupe(u8, parent_id),
            .derived_id = try allocator.dupe(u8, derived_id),
            .split_time = split_time,
            .admixture_proportion = admixture,
        };
    }

    pub fn deinit(self: *PopulationRelationship) void {
        self.allocator.free(self.parent_id);
        self.allocator.free(self.derived_id);
    }
};

/// A graph representing population history (admixture graphs).
pub const AncestryGraph = struct {
    allocator: std.mem.Allocator,
    populations: std.StringHashMap(Population),
    edges: std.ArrayList(PopulationRelationship),

    // Adjacency lists by population ID
    parents_of: std.StringHashMap(std.ArrayList(usize)),
    children_of: std.StringHashMap(std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) AncestryGraph {
        return .{
            .allocator = allocator,
            .populations = std.StringHashMap(Population).init(allocator),
            .edges = .empty,
            .parents_of = std.StringHashMap(std.ArrayList(usize)).init(allocator),
            .children_of = std.StringHashMap(std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *AncestryGraph) void {
        var pop_iter = self.populations.iterator();
        while (pop_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.populations.deinit();

        for (self.edges.items) |*e| e.deinit();
        self.edges.deinit(self.allocator);

        var p_iter = self.parents_of.iterator();
        while (p_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.parents_of.deinit();

        var c_iter = self.children_of.iterator();
        while (c_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.children_of.deinit();
    }

    pub fn addPopulation(self: *AncestryGraph, pop: Population) !void {
        const key = try self.allocator.dupe(u8, pop.id);
        try self.populations.put(key, pop);
    }

    pub fn addRelationship(self: *AncestryGraph, rel: PopulationRelationship) !void {
        const idx = self.edges.items.len;
        try self.edges.append(self.allocator, rel);

        const p_entry = try self.parents_of.getOrPut(rel.derived_id);
        if (!p_entry.found_existing) {
            p_entry.key_ptr.* = try self.allocator.dupe(u8, rel.derived_id);
            p_entry.value_ptr.* = .empty;
        }
        try p_entry.value_ptr.append(self.allocator, idx);

        const c_entry = try self.children_of.getOrPut(rel.parent_id);
        if (!c_entry.found_existing) {
            c_entry.key_ptr.* = try self.allocator.dupe(u8, rel.parent_id);
            c_entry.value_ptr.* = .empty;
        }
        try c_entry.value_ptr.append(self.allocator, idx);
    }

    pub fn getAncestry(self: AncestryGraph, pop_id: []const u8) ?[]const usize {
        if (self.parents_of.get(pop_id)) |list| return list.items;
        return null;
    }

    pub fn getDescendants(self: AncestryGraph, pop_id: []const u8) ?[]const usize {
        if (self.children_of.get(pop_id)) |list| return list.items;
        return null;
    }
};

test "AncestryGraph building" {
    const alloc = std.testing.allocator;
    var graph = AncestryGraph.init(alloc);
    defer graph.deinit();

    try graph.addPopulation(try Population.init(alloc, "PopA", "Ancestral"));
    try graph.addPopulation(try Population.init(alloc, "PopB", "Derived1"));
    try graph.addPopulation(try Population.init(alloc, "PopC", "Derived2"));

    try graph.addRelationship(try PopulationRelationship.init(alloc, "PopA", "PopB", 1000.0, null));
    try graph.addRelationship(try PopulationRelationship.init(alloc, "PopA", "PopC", 1000.0, null));

    const children = graph.getDescendants("PopA");
    try std.testing.expect(children != null);
    try std.testing.expectEqual(@as(usize, 2), children.?.len);

    const parents = graph.getAncestry("PopB");
    try std.testing.expect(parents != null);
    try std.testing.expectEqual(@as(usize, 1), parents.?.len);
}
