const std = @import("std");
const core = @import("core");
const XxHash64 = core.hashing.XxHash64;

/// Enum specifying categories of diseases.
pub const DiseaseCategory = enum(u8) {
    genetic,
    infectious,
    neoplastic,
    metabolic,
    cardiovascular,
    neurological,
    immunological,
    other,
};

/// Enum specifying standard disease relationship types.
pub const DiseaseRelationshipType = enum(u8) {
    is_a,
    subclass_of,
    associated_with,
};

/// Key-value metadata pair for disease annotations.
pub const MetadataEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// Represents a relationship between two diseases.
pub const DiseaseRelationship = struct {
    source_id: []const u8,
    target_id: []const u8,
    relationship_type: DiseaseRelationshipType,
};

/// Represents a disease entity.
pub const Disease = struct {
    /// Disease identifier (e.g. MONDO/DOID term, like "MONDO:0007739")
    id: []const u8,
    /// Disease name (e.g. "Huntington Disease")
    name: []const u8,
    /// Classification category
    category: DiseaseCategory,
    /// Disease annotations/metadata
    metadata: []const MetadataEntry,
    /// Relationships to other diseases
    relationships: []const DiseaseRelationship,

    /// Initializes a Disease struct.
    pub fn init(
        id: []const u8,
        name: []const u8,
        category: DiseaseCategory,
        metadata: []const MetadataEntry,
        relationships: []const DiseaseRelationship,
    ) Disease {
        return .{
            .id = id,
            .name = name,
            .category = category,
            .metadata = metadata,
            .relationships = relationships,
        };
    }

    /// Determines if two diseases are structurally identical.
    pub fn equals(self: Disease, other: Disease) bool {
        if (!std.mem.eql(u8, self.id, other.id)) return false;
        if (!std.mem.eql(u8, self.name, other.name)) return false;
        if (self.category != other.category) return false;
        if (self.metadata.len != other.metadata.len) return false;
        for (self.metadata, 0..) |entry, i| {
            if (!std.mem.eql(u8, entry.key, other.metadata[i].key)) return false;
            if (!std.mem.eql(u8, entry.value, other.metadata[i].value)) return false;
        }
        if (self.relationships.len != other.relationships.len) return false;
        for (self.relationships, 0..) |rel, i| {
            const o_rel = other.relationships[i];
            if (!std.mem.eql(u8, rel.source_id, o_rel.source_id)) return false;
            if (!std.mem.eql(u8, rel.target_id, o_rel.target_id)) return false;
            if (rel.relationship_type != o_rel.relationship_type) return false;
        }
        return true;
    }

    /// Computes a deterministic hash value for the Disease.
    pub fn hash(self: Disease) u64 {
        var h: u64 = 5381;
        h = XxHash64.hash(self.id, h);
        h = XxHash64.hash(self.name, h);
        for (self.metadata) |entry| {
            h = XxHash64.hash(entry.key, h);
            h = XxHash64.hash(entry.value, h);
        }
        for (self.relationships) |rel| {
            h = XxHash64.hash(rel.source_id, h);
            h = XxHash64.hash(rel.target_id, h);
        }
        return h;
    }

    /// Serializes the Disease to a binary format.
    pub fn serialize(self: Disease, writer: anytype) !void {
        try core.serialization.serialize(writer, self);
    }

    /// Deserializes a Disease from a binary format, allocating memory for its slices.
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Disease {
        return try core.serialization.deserialize(reader, Disease, allocator);
    }

    /// Frees any memory allocated for this Disease during deserialization.
    pub fn deinit(self: Disease, allocator: std.mem.Allocator) void {
        core.serialization.free(allocator, self);
    }
};

/// A collection of diseases supporting index, lookup, and filtering.
pub const DiseaseCollection = struct {
    diseases: []const Disease,

    /// Initializes a DiseaseCollection.
    pub fn init(diseases: []const Disease) DiseaseCollection {
        return .{ .diseases = diseases };
    }

    /// Looks up a Disease in the collection by its ID.
    pub fn lookup(self: DiseaseCollection, id: []const u8) ?*const Disease {
        for (self.diseases) |*d| {
            if (std.mem.eql(u8, d.id, id)) return d;
        }
        return null;
    }

    /// Filters the collection to return only diseases of the specified category.
    /// Caller owns the returned slice and must free it.
    pub fn filterByCategory(self: DiseaseCollection, cat: DiseaseCategory, allocator: std.mem.Allocator) ![]const *const Disease {
        var list = std.ArrayList(*const Disease).empty;
        defer list.deinit(allocator);
        for (self.diseases) |*d| {
            if (d.category == cat) {
                try list.append(allocator, d);
            }
        }
        return list.toOwnedSlice(allocator);
    }

    /// Filters the collection to return only diseases whose name contains the query (case-insensitive).
    /// Caller owns the returned slice and must free it.
    pub fn filterByNameContains(self: DiseaseCollection, query: []const u8, allocator: std.mem.Allocator) ![]const *const Disease {
        var list = std.ArrayList(*const Disease).empty;
        defer list.deinit(allocator);
        for (self.diseases) |*d| {
            if (containsIgnoreCase(d.name, query)) {
                try list.append(allocator, d);
            }
        }
        return list.toOwnedSlice(allocator);
    }

    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len == 0) return true;
        if (haystack.len < needle.len) return false;
        var i: usize = 0;
        while (i <= haystack.len - needle.len) : (i += 1) {
            var match = true;
            var j: usize = 0;
            while (j < needle.len) : (j += 1) {
                const char_h = std.ascii.toUpper(haystack[i + j]);
                const char_n = std.ascii.toUpper(needle[j]);
                if (char_h != char_n) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        return false;
    }
};

/// Type of entity that can be associated with a disease.
pub const EntityType = enum(u8) {
    gene,
    protein,
    phenotype,
    anatomy,
    other,
};

/// Quality / confidence of the association evidence.
pub const EvidenceLevel = enum(u8) {
    high,
    moderate,
    low,
    conflicting,
};

/// Represents an association link between a biological entity and a disease.
pub const DiseaseAssociation = struct {
    entity_type: EntityType,
    entity_id: []const u8,
    disease_id: []const u8,
    evidence_level: EvidenceLevel,

    /// Initializes a DiseaseAssociation.
    pub fn init(
        e_type: EntityType,
        e_id: []const u8,
        d_id: []const u8,
        e_level: EvidenceLevel,
    ) DiseaseAssociation {
        return .{
            .entity_type = e_type,
            .entity_id = e_id,
            .disease_id = d_id,
            .evidence_level = e_level,
        };
    }
};

test "Disease basic operations, collections, and associations" {
    const allocator = std.testing.allocator;

    const rels = [_]DiseaseRelationship{
        .{ .source_id = "MONDO:0007739", .target_id = "MONDO:0020011", .relationship_type = .subclass_of },
    };

    const d1 = Disease.init(
        "MONDO:0007739",
        "Huntington Disease",
        .neurological,
        &[_]MetadataEntry{
            .{ .key = "OMIM", .value = "143100" },
        },
        &rels,
    );

    const d2 = Disease.init(
        "MONDO:0005016",
        "Type 2 Diabetes Mellitus",
        .metabolic,
        &[_]MetadataEntry{},
        &[_]DiseaseRelationship{},
    );

    // Equality, hashing
    try std.testing.expect(d1.equals(d1));
    try std.testing.expect(!d1.equals(d2));
    try std.testing.expectEqual(d1.hash(), d1.hash());
    try std.testing.expect(d1.hash() != d2.hash());

    // Collections
    const diseases = [_]Disease{ d1, d2 };
    const col = DiseaseCollection.init(&diseases);

    try std.testing.expect(col.lookup("MONDO:0007739") != null);
    try std.testing.expect(col.lookup("MONDO:0000000") == null);

    const filtered_cat = try col.filterByCategory(.metabolic, allocator);
    defer allocator.free(filtered_cat);
    try std.testing.expectEqual(filtered_cat.len, 1);
    try std.testing.expectEqualStrings("Type 2 Diabetes Mellitus", filtered_cat[0].name);

    const filtered_name = try col.filterByNameContains("hunting", allocator);
    defer allocator.free(filtered_name);
    try std.testing.expectEqual(filtered_name.len, 1);

    // Associations
    const assoc = DiseaseAssociation.init(.gene, "HTT", "MONDO:0007739", .high);
    try std.testing.expectEqual(assoc.entity_type, .gene);
    try std.testing.expectEqualStrings("HTT", assoc.entity_id);
    try std.testing.expectEqualStrings("MONDO:0007739", assoc.disease_id);
    try std.testing.expectEqual(assoc.evidence_level, .high);

    // Serialization roundtrip
    var buf: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try d1.serialize(&writer);

    const written = writer.buffered();
    var reader = std.Io.Reader.fixed(written);
    const deserialized = try Disease.deserialize(&reader, allocator);
    defer deserialized.deinit(allocator);

    try std.testing.expect(d1.equals(deserialized));
}
