const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

pub const EntityType = enum(u8) {
    Gene,
    Protein,
    Disease,
    Pathway,
    Drug,
    Other,
};

pub const RelationshipType = enum(u8) {
    InteractsWith,
    AssociatedWith,
    PartOf,
    Regulates,
    Other,
};

/// Represents an entity in the knowledge graph.
pub const Entity = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    entity_type: EntityType,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, entity_type: EntityType) !Entity {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .entity_type = entity_type,
        };
    }

    pub fn deinit(self: *Entity) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
    }

    pub fn serialize(self: Entity, writer: anytype) !void {
        try serialization.serialize(writer, self.id);
        try serialization.serialize(writer, self.name);
        try serialization.serialize(writer, self.entity_type);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Entity {
        const id = try serialization.deserialize(reader, []const u8, allocator);
        const name = try serialization.deserialize(reader, []const u8, allocator);
        const entity_type = try serialization.deserialize(reader, EntityType, allocator);
        const entity = try Entity.init(allocator, id, name, entity_type);
        allocator.free(id);
        allocator.free(name);
        return entity;
    }
};

/// Represents a typed relationship between two entities.
pub const Relationship = struct {
    source_idx: usize,
    target_idx: usize,
    rel_type: RelationshipType,
    weight: f64 = 1.0,

    pub fn serialize(self: Relationship, writer: anytype) !void {
        try serialization.serialize(writer, self.source_idx);
        try serialization.serialize(writer, self.target_idx);
        try serialization.serialize(writer, self.rel_type);
        try serialization.serialize(writer, self.weight);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Relationship {
        return .{
            .source_idx = try serialization.deserialize(reader, usize, allocator),
            .target_idx = try serialization.deserialize(reader, usize, allocator),
            .rel_type = try serialization.deserialize(reader, RelationshipType, allocator),
            .weight = try serialization.deserialize(reader, f64, allocator),
        };
    }
};

/// Represents a Biological Knowledge Graph.
pub const KnowledgeGraph = struct {
    allocator: std.mem.Allocator,
    entities: std.ArrayList(Entity),
    relationships: std.ArrayList(Relationship),

    // Quick lookup: entity_id -> node index
    id_to_idx: std.StringHashMap(usize),

    // Adjacency list: node_idx -> list of relationship indices
    adj: std.AutoHashMap(usize, std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) KnowledgeGraph {
        return .{
            .allocator = allocator,
            .entities = .empty,
            .relationships = .empty,
            .id_to_idx = std.StringHashMap(usize).init(allocator),
            .adj = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *KnowledgeGraph) void {
        for (self.entities.items) |*e| e.deinit();
        self.entities.deinit(self.allocator);
        self.relationships.deinit(self.allocator);

        var iter = self.id_to_idx.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.id_to_idx.deinit();

        var adj_iter = self.adj.iterator();
        while (adj_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.adj.deinit();
    }

    pub fn addEntity(self: *KnowledgeGraph, id: []const u8, name: []const u8, entity_type: EntityType) !usize {
        if (self.id_to_idx.get(id)) |idx| return idx;

        const idx = self.entities.items.len;
        const entity = try Entity.init(self.allocator, id, name, entity_type);
        try self.entities.append(self.allocator, entity);
        try self.id_to_idx.put(try self.allocator.dupe(u8, id), idx);
        return idx;
    }

    pub fn addRelationship(self: *KnowledgeGraph, source_id: []const u8, target_id: []const u8, rel_type: RelationshipType, weight: f64) !void {
        const s_idx = self.id_to_idx.get(source_id) orelse return error.EntityNotFound;
        const t_idx = self.id_to_idx.get(target_id) orelse return error.EntityNotFound;

        const rel_idx = self.relationships.items.len;
        try self.relationships.append(self.allocator, .{
            .source_idx = s_idx,
            .target_idx = t_idx,
            .rel_type = rel_type,
            .weight = weight,
        });

        // Add to source adjacency
        const s_entry = try self.adj.getOrPut(s_idx);
        if (!s_entry.found_existing) s_entry.value_ptr.* = .empty;
        try s_entry.value_ptr.append(self.allocator, rel_idx);

        // Add to target adjacency (undirected traversal possible)
        const t_entry = try self.adj.getOrPut(t_idx);
        if (!t_entry.found_existing) t_entry.value_ptr.* = .empty;
        try t_entry.value_ptr.append(self.allocator, rel_idx);
    }

    pub fn getRelationships(self: KnowledgeGraph, entity_id: []const u8) ?[]const usize {
        const idx = self.id_to_idx.get(entity_id) orelse return null;
        if (self.adj.get(idx)) |list| {
            return list.items;
        }
        return null;
    }

    pub fn serialize(self: KnowledgeGraph, writer: anytype) !void {
        try serialization.serialize(writer, @as(u64, self.entities.items.len));
        for (self.entities.items) |e| {
            try e.serialize(writer);
        }
        try serialization.serialize(writer, @as(u64, self.relationships.items.len));
        for (self.relationships.items) |r| {
            try r.serialize(writer);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !KnowledgeGraph {
        var kg = KnowledgeGraph.init(allocator);
        errdefer kg.deinit();

        const entity_count = try serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < entity_count) : (i += 1) {
            const e = try Entity.deserialize(reader, allocator);
            _ = try kg.addEntity(e.id, e.name, e.entity_type);
            allocator.free(e.id);
            allocator.free(e.name);
        }

        const rel_count = try serialization.deserialize(reader, u64, allocator);
        var j: u64 = 0;
        while (j < rel_count) : (j += 1) {
            const rel = try Relationship.deserialize(reader, allocator);
            const source_id = kg.entities.items[rel.source_idx].id;
            const target_id = kg.entities.items[rel.target_idx].id;
            try kg.addRelationship(source_id, target_id, rel.rel_type, rel.weight);
        }
        return kg;
    }
};

test "KnowledgeGraph entity and relationship" {
    const alloc = std.testing.allocator;
    var kg = KnowledgeGraph.init(alloc);
    defer kg.deinit();

    _ = try kg.addEntity("ENSG00000141510", "TP53", .Gene);
    _ = try kg.addEntity("DB00001", "Lepirudin", .Drug);
    _ = try kg.addEntity("DOID:1612", "breast cancer", .Disease);

    try kg.addRelationship("ENSG00000141510", "DOID:1612", .AssociatedWith, 1.0);

    const rels = kg.getRelationships("ENSG00000141510");
    try std.testing.expect(rels != null);
    try std.testing.expectEqual(@as(usize, 1), rels.?.len);

    const inter = kg.relationships.items[rels.?[0]];
    try std.testing.expectEqual(RelationshipType.AssociatedWith, inter.rel_type);
}
