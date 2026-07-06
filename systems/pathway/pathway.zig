const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents a biological pathway.
pub const Pathway = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    members: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8) !Pathway {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .members = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Pathway) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
        var iter = self.members.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.members.deinit();
    }

    pub fn addMember(self: *Pathway, entity_id: []const u8) !void {
        const entry = try self.members.getOrPut(entity_id);
        if (!entry.found_existing) {
            entry.key_ptr.* = try self.allocator.dupe(u8, entity_id);
        }
    }

    pub fn hasMember(self: Pathway, entity_id: []const u8) bool {
        return self.members.contains(entity_id);
    }

    pub fn memberCount(self: Pathway) usize {
        return self.members.count();
    }

    pub fn serialize(self: Pathway, writer: anytype) !void {
        try serialization.serialize(writer, self.id);
        try serialization.serialize(writer, self.name);
        try serialization.serialize(writer, @as(u64, self.members.count()));
        var iter = self.members.keyIterator();
        while (iter.next()) |key| {
            try serialization.serialize(writer, key.*);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Pathway {
        const id = try serialization.deserialize(reader, []const u8, allocator);
        const name = try serialization.deserialize(reader, []const u8, allocator);
        
        var pathway = try Pathway.init(allocator, id, name);
        allocator.free(id);
        allocator.free(name);

        const count = try serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            const member_id = try serialization.deserialize(reader, []const u8, allocator);
            try pathway.addMember(member_id);
            allocator.free(member_id);
        }
        return pathway;
    }
};

test "Pathway basic operations and serialization" {
    const alloc = std.testing.allocator;
    var pathway = try Pathway.init(alloc, "KEGG:00010", "Glycolysis / Gluconeogenesis");
    defer pathway.deinit();

    try pathway.addMember("HK1");
    try pathway.addMember("PFKP");

    try std.testing.expect(pathway.hasMember("HK1"));
    try std.testing.expect(!pathway.hasMember("TP53"));
    try std.testing.expectEqual(@as(usize, 2), pathway.memberCount());

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try pathway.serialize(&writer);

    var reader = std.Io.Reader.fixed(writer.buffered());
    var deserialized = try Pathway.deserialize(&reader, alloc);
    defer deserialized.deinit();

    try std.testing.expectEqualStrings("KEGG:00010", deserialized.id);
    try std.testing.expect(deserialized.hasMember("PFKP"));
}
