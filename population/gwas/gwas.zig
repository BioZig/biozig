const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents a single GWAS association result.
pub const AssociationRecord = struct {
    allocator: std.mem.Allocator,
    variant_id: []const u8,
    trait_id: []const u8,
    p_value: f64,
    effect_size: f64,
    ci_lower: f64,
    ci_upper: f64,

    pub fn init(allocator: std.mem.Allocator, variant_id: []const u8, trait_id: []const u8, p_value: f64, effect_size: f64, ci_lower: f64, ci_upper: f64) !AssociationRecord {
        return .{
            .allocator = allocator,
            .variant_id = try allocator.dupe(u8, variant_id),
            .trait_id = try allocator.dupe(u8, trait_id),
            .p_value = p_value,
            .effect_size = effect_size,
            .ci_lower = ci_lower,
            .ci_upper = ci_upper,
        };
    }

    pub fn deinit(self: *AssociationRecord) void {
        self.allocator.free(self.variant_id);
        self.allocator.free(self.trait_id);
    }

    pub fn serialize(self: AssociationRecord, writer: anytype) !void {
        try serialization.serialize(writer, self.variant_id);
        try serialization.serialize(writer, self.trait_id);
        try serialization.serialize(writer, self.p_value);
        try serialization.serialize(writer, self.effect_size);
        try serialization.serialize(writer, self.ci_lower);
        try serialization.serialize(writer, self.ci_upper);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !AssociationRecord {
        const variant_id = try serialization.deserialize(reader, []const u8, allocator);
        const trait_id = try serialization.deserialize(reader, []const u8, allocator);
        const p_value = try serialization.deserialize(reader, f64, allocator);
        const effect_size = try serialization.deserialize(reader, f64, allocator);
        const ci_lower = try serialization.deserialize(reader, f64, allocator);
        const ci_upper = try serialization.deserialize(reader, f64, allocator);
        
        const record = try AssociationRecord.init(allocator, variant_id, trait_id, p_value, effect_size, ci_lower, ci_upper);
        allocator.free(variant_id);
        allocator.free(trait_id);
        return record;
    }
};

/// A collection of association records.
pub const AssociationCollection = struct {
    allocator: std.mem.Allocator,
    records: std.ArrayList(AssociationRecord),
    
    // Quick indices
    variant_idx: std.StringHashMap(std.ArrayList(usize)),
    trait_idx: std.StringHashMap(std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) AssociationCollection {
        return .{
            .allocator = allocator,
            .records = .empty,
            .variant_idx = std.StringHashMap(std.ArrayList(usize)).init(allocator),
            .trait_idx = std.StringHashMap(std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *AssociationCollection) void {
        for (self.records.items) |*r| r.deinit();
        self.records.deinit(self.allocator);
        
        var v_iter = self.variant_idx.iterator();
        while (v_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.variant_idx.deinit();

        var t_iter = self.trait_idx.iterator();
        while (t_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.trait_idx.deinit();
    }

    pub fn addRecord(self: *AssociationCollection, record: AssociationRecord) !void {
        const idx = self.records.items.len;
        try self.records.append(self.allocator, record);

        const v_entry = try self.variant_idx.getOrPut(record.variant_id);
        if (!v_entry.found_existing) {
            v_entry.key_ptr.* = try self.allocator.dupe(u8, record.variant_id);
            v_entry.value_ptr.* = .empty;
        }
        try v_entry.value_ptr.append(self.allocator, idx);

        const t_entry = try self.trait_idx.getOrPut(record.trait_id);
        if (!t_entry.found_existing) {
            t_entry.key_ptr.* = try self.allocator.dupe(u8, record.trait_id);
            t_entry.value_ptr.* = .empty;
        }
        try t_entry.value_ptr.append(self.allocator, idx);
    }

    pub fn getByVariant(self: AssociationCollection, variant_id: []const u8) ?[]const usize {
        if (self.variant_idx.get(variant_id)) |list| return list.items;
        return null;
    }

    pub fn getByTrait(self: AssociationCollection, trait_id: []const u8) ?[]const usize {
        if (self.trait_idx.get(trait_id)) |list| return list.items;
        return null;
    }
};

test "AssociationRecord and Collection" {
    const alloc = std.testing.allocator;
    var col = AssociationCollection.init(alloc);
    defer col.deinit();

    const r1 = try AssociationRecord.init(alloc, "rs1042522", "Height", 5e-8, 1.2, 1.0, 1.4);
    try col.addRecord(r1);
    
    const r2 = try AssociationRecord.init(alloc, "rs1042522", "Weight", 0.05, 0.5, -0.1, 1.1);
    try col.addRecord(r2);

    const hits = col.getByVariant("rs1042522");
    try std.testing.expect(hits != null);
    try std.testing.expectEqual(@as(usize, 2), hits.?.len);
    
    const traits = col.getByTrait("Height");
    try std.testing.expect(traits != null);
    try std.testing.expectEqual(@as(usize, 1), traits.?.len);
}
