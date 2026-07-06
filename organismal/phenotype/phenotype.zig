const std = @import("std");
const core = @import("core");
const XxHash64 = core.hashing.XxHash64;

/// Enum specifying whether a phenotype is qualitative (described by category/presence)
/// or quantitative (described by numerical value and unit).
pub const PhenotypeType = enum(u8) {
    qualitative,
    quantitative,
};

/// Key-value metadata pair attached to a Phenotype.
pub const MetadataEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// Represents a distinct biological phenotype.
pub const Phenotype = struct {
    /// Phenotype identifier (e.g. HPO term "HP:0000118")
    id: []const u8,
    /// Human-readable name of the phenotype (e.g. "Infantilism")
    name: []const u8,
    /// Detailed description of the phenotype
    description: []const u8,
    /// Phenotype classification type
    phenotype_type: PhenotypeType,
    /// Key-value metadata annotations
    metadata: []const MetadataEntry,

    /// Initializes a Phenotype struct.
    pub fn init(
        id: []const u8,
        name: []const u8,
        description: []const u8,
        p_type: PhenotypeType,
        metadata: []const MetadataEntry,
    ) Phenotype {
        return .{
            .id = id,
            .name = name,
            .description = description,
            .phenotype_type = p_type,
            .metadata = metadata,
        };
    }

    /// Determines if two phenotypes are structurally identical.
    pub fn equals(self: Phenotype, other: Phenotype) bool {
        if (!std.mem.eql(u8, self.id, other.id)) return false;
        if (!std.mem.eql(u8, self.name, other.name)) return false;
        if (!std.mem.eql(u8, self.description, other.description)) return false;
        if (self.phenotype_type != other.phenotype_type) return false;
        if (self.metadata.len != other.metadata.len) return false;
        for (self.metadata, 0..) |entry, i| {
            const other_entry = other.metadata[i];
            if (!std.mem.eql(u8, entry.key, other_entry.key)) return false;
            if (!std.mem.eql(u8, entry.value, other_entry.value)) return false;
        }
        return true;
    }

    /// Computes a deterministic hash value for the Phenotype.
    pub fn hash(self: Phenotype) u64 {
        var h: u64 = 5381;
        h = XxHash64.hash(self.id, h);
        h = XxHash64.hash(self.name, h);
        h = XxHash64.hash(self.description, h);
        for (self.metadata) |entry| {
            h = XxHash64.hash(entry.key, h);
            h = XxHash64.hash(entry.value, h);
        }
        return h;
    }

    /// Serializes the Phenotype to a binary format.
    pub fn serialize(self: Phenotype, writer: anytype) !void {
        try core.serialization.serialize(writer, self);
    }

    /// Deserializes a Phenotype from a binary format, allocating memory for its slices.
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Phenotype {
        return try core.serialization.deserialize(reader, Phenotype, allocator);
    }

    /// Frees any memory allocated for this Phenotype during deserialization.
    pub fn deinit(self: Phenotype, allocator: std.mem.Allocator) void {
        core.serialization.free(allocator, self);
    }

    /// Performs metadata lookup by key.
    pub fn lookupMetadata(self: Phenotype, key: []const u8) ?[]const u8 {
        for (self.metadata) |entry| {
            if (std.mem.eql(u8, entry.key, key)) {
                return entry.value;
            }
        }
        return null;
    }
};

/// A collection of Phenotypes allowing lookup, indexing, and filtering.
pub const PhenotypeCollection = struct {
    phenotypes: []const Phenotype,

    /// Initializes a PhenotypeCollection.
    pub fn init(phenotypes: []const Phenotype) PhenotypeCollection {
        return .{ .phenotypes = phenotypes };
    }

    /// Looks up a Phenotype in the collection by its ID.
    pub fn lookup(self: PhenotypeCollection, id: []const u8) ?*const Phenotype {
        for (self.phenotypes) |*p| {
            if (std.mem.eql(u8, p.id, id)) return p;
        }
        return null;
    }

    /// Filters the collection to return only phenotypes of the specified type.
    /// Caller owns the returned slice and must free it.
    pub fn filterByType(self: PhenotypeCollection, t: PhenotypeType, allocator: std.mem.Allocator) ![]const *const Phenotype {
        var list = std.ArrayList(*const Phenotype).empty;
        defer list.deinit(allocator);
        for (self.phenotypes) |*p| {
            if (p.phenotype_type == t) {
                try list.append(allocator, p);
            }
        }
        return list.toOwnedSlice(allocator);
    }

    /// Filters the collection to return only phenotypes whose name contains the search query (case-insensitive).
    /// Caller owns the returned slice and must free it.
    pub fn filterByNameContains(self: PhenotypeCollection, query: []const u8, allocator: std.mem.Allocator) ![]const *const Phenotype {
        var list = std.ArrayList(*const Phenotype).empty;
        defer list.deinit(allocator);
        for (self.phenotypes) |*p| {
            if (containsIgnoreCase(p.name, query)) {
                try list.append(allocator, p);
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

test "Phenotype basic operations, collections, and serialization" {
    const allocator = std.testing.allocator;

    const meta = [_]MetadataEntry{
        .{ .key = "source", .value = "HPO" },
        .{ .key = "clinical_relevance", .value = "high" },
    };

    const p1 = Phenotype.init(
        "HP:0000118",
        "Infantilism",
        "Delayed or incomplete developmental growth.",
        .qualitative,
        &meta,
    );

    const p2 = Phenotype.init(
        "HP:0001250",
        "Seizure",
        "A paroxysmal alteration of neurological function.",
        .qualitative,
        &[_]MetadataEntry{},
    );

    // Equality and hashing
    try std.testing.expect(p1.equals(p1));
    try std.testing.expect(!p1.equals(p2));
    try std.testing.expectEqual(p1.hash(), p1.hash());
    try std.testing.expect(p1.hash() != p2.hash());

    // Metadata lookup
    try std.testing.expectEqualStrings("HPO", p1.lookupMetadata("source").?);
    try std.testing.expect(p1.lookupMetadata("non_existent") == null);

    // Collections
    const phenotypes = [_]Phenotype{ p1, p2 };
    const col = PhenotypeCollection.init(&phenotypes);

    try std.testing.expect(col.lookup("HP:0000118") != null);
    try std.testing.expectEqualStrings("Infantilism", col.lookup("HP:0000118").?.name);
    try std.testing.expect(col.lookup("HP:0000000") == null);

    // Filtering
    const name_filtered = try col.filterByNameContains("seiz", allocator);
    defer allocator.free(name_filtered);
    try std.testing.expectEqual(name_filtered.len, 1);
    try std.testing.expectEqualStrings("Seizure", name_filtered[0].name);

    const type_filtered = try col.filterByType(.qualitative, allocator);
    defer allocator.free(type_filtered);
    try std.testing.expectEqual(type_filtered.len, 2);

    // Serialization roundtrip
    var buf: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try p1.serialize(&writer);

    const written = writer.buffered();
    var reader = std.Io.Reader.fixed(written);
    const deserialized = try Phenotype.deserialize(&reader, allocator);
    defer deserialized.deinit(allocator);

    try std.testing.expect(p1.equals(deserialized));
}
