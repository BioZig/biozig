const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents a term in a biological ontology (e.g., Gene Ontology).
pub const Term = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8) !Term {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
        };
    }

    pub fn deinit(self: *Term) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
    }

    pub fn serialize(self: Term, writer: anytype) !void {
        try serialization.serialize(writer, self.id);
        try serialization.serialize(writer, self.name);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Term {
        const id = try serialization.deserialize(reader, []const u8, allocator);
        const name = try serialization.deserialize(reader, []const u8, allocator);
        const term = try Term.init(allocator, id, name);
        allocator.free(id);
        allocator.free(name);
        return term;
    }
};

/// Represents an Ontology structure, strictly as a Directed Acyclic Graph (DAG).
pub const Ontology = struct {
    allocator: std.mem.Allocator,
    terms: std.ArrayList(Term),

    // Quick lookups
    id_to_idx: std.StringHashMap(usize),

    // Adjacency lists (idx -> list of idx)
    parents: std.AutoHashMap(usize, std.ArrayList(usize)),
    children: std.AutoHashMap(usize, std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) Ontology {
        return .{
            .allocator = allocator,
            .terms = .empty,
            .id_to_idx = std.StringHashMap(usize).init(allocator),
            .parents = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator),
            .children = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *Ontology) void {
        for (self.terms.items) |*t| t.deinit();
        self.terms.deinit(self.allocator);

        var iter = self.id_to_idx.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.id_to_idx.deinit();

        var p_iter = self.parents.iterator();
        while (p_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.parents.deinit();

        var c_iter = self.children.iterator();
        while (c_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.children.deinit();
    }

    pub fn addTerm(self: *Ontology, id: []const u8, name: []const u8) !usize {
        if (self.id_to_idx.get(id)) |idx| return idx;

        const idx = self.terms.items.len;
        const term = try Term.init(self.allocator, id, name);
        try self.terms.append(self.allocator, term);
        try self.id_to_idx.put(try self.allocator.dupe(u8, id), idx);
        return idx;
    }

    pub fn addRelationship(self: *Ontology, parent_id: []const u8, child_id: []const u8) !void {
        const p_idx = self.id_to_idx.get(parent_id) orelse return error.TermNotFound;
        const c_idx = self.id_to_idx.get(child_id) orelse return error.TermNotFound;

        const c_entry = try self.children.getOrPut(p_idx);
        if (!c_entry.found_existing) c_entry.value_ptr.* = .empty;
        try c_entry.value_ptr.append(self.allocator, c_idx);

        const p_entry = try self.parents.getOrPut(c_idx);
        if (!p_entry.found_existing) p_entry.value_ptr.* = .empty;
        try p_entry.value_ptr.append(self.allocator, p_idx);
    }

    /// Verifies if the current structure is a valid DAG (no cycles).
    pub fn isValidDAG(self: Ontology) !bool {
        var visited = std.AutoHashMap(usize, u8).init(self.allocator); // 0=unvisited, 1=visiting, 2=visited
        defer visited.deinit();

        for (0..self.terms.items.len) |i| {
            if (try self.hasCycle(i, &visited)) return false;
        }
        return true;
    }

    fn hasCycle(self: Ontology, node: usize, visited: *std.AutoHashMap(usize, u8)) !bool {
        const state = visited.get(node) orelse 0;
        if (state == 1) return true; // cycle detected
        if (state == 2) return false;

        try visited.put(node, 1);
        if (self.children.get(node)) |list| {
            for (list.items) |child| {
                if (try self.hasCycle(child, visited)) return true;
            }
        }
        try visited.put(node, 2);
        return false;
    }

    pub fn getAncestors(self: Ontology, id: []const u8, allocator: std.mem.Allocator) ![]usize {
        const start_idx = self.id_to_idx.get(id) orelse return error.TermNotFound;
        var result = std.AutoHashMap(usize, void).init(allocator);
        defer result.deinit();

        var stack = std.ArrayList(usize).empty;
        defer stack.deinit(allocator);
        try stack.append(allocator, start_idx);

        while (stack.pop()) |curr| {
            if (self.parents.get(curr)) |list| {
                for (list.items) |p| {
                    const entry = try result.getOrPut(p);
                    if (!entry.found_existing) {
                        try stack.append(allocator, p);
                    }
                }
            }
        }

        var ancestors = try allocator.alloc(usize, result.count());
        var iter = result.keyIterator();
        var i: usize = 0;
        while (iter.next()) |key| : (i += 1) {
            ancestors[i] = key.*;
        }
        return ancestors;
    }
};

test "Ontology DAG and Ancestry" {
    const alloc = std.testing.allocator;
    var ont = Ontology.init(alloc);
    defer ont.deinit();

    _ = try ont.addTerm("GO:0008150", "biological_process");
    _ = try ont.addTerm("GO:0009987", "cellular_process");
    _ = try ont.addTerm("GO:0008283", "cell_proliferation");

    try ont.addRelationship("GO:0008150", "GO:0009987");
    try ont.addRelationship("GO:0009987", "GO:0008283");

    try std.testing.expect(try ont.isValidDAG());

    const ancestors = try ont.getAncestors("GO:0008283", alloc);
    defer alloc.free(ancestors);
    try std.testing.expectEqual(@as(usize, 2), ancestors.len);
}
