const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

pub const RegulationType = enum(u8) {
    Activation,
    Repression,
    Unknown,
};

/// Represents a regulatory interaction (e.g., Transcription Factor regulating a Gene).
pub const RegulatoryInteraction = struct {
    regulator_idx: usize,
    target_idx: usize,
    reg_type: RegulationType,
    score: f64,

    pub fn serialize(self: RegulatoryInteraction, writer: anytype) !void {
        try serialization.serialize(writer, self.regulator_idx);
        try serialization.serialize(writer, self.target_idx);
        try serialization.serialize(writer, self.reg_type);
        try serialization.serialize(writer, self.score);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !RegulatoryInteraction {
        return .{
            .regulator_idx = try serialization.deserialize(reader, usize, allocator),
            .target_idx = try serialization.deserialize(reader, usize, allocator),
            .reg_type = try serialization.deserialize(reader, RegulationType, allocator),
            .score = try serialization.deserialize(reader, f64, allocator),
        };
    }
};

/// Represents a Gene Regulatory Network (GRN).
pub const RegulatoryGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList([]const u8), // node_idx -> entity_id
    interactions: std.ArrayList(RegulatoryInteraction),

    // Quick lookups
    id_to_idx: std.StringHashMap(usize),

    // Adjacency lists
    targets_of: std.AutoHashMap(usize, std.ArrayList(usize)), // regulator -> list of interaction indices
    regulators_of: std.AutoHashMap(usize, std.ArrayList(usize)), // target -> list of interaction indices

    pub fn init(allocator: std.mem.Allocator) RegulatoryGraph {
        return .{
            .allocator = allocator,
            .nodes = .empty,
            .interactions = .empty,
            .id_to_idx = std.StringHashMap(usize).init(allocator),
            .targets_of = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator),
            .regulators_of = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *RegulatoryGraph) void {
        for (self.nodes.items) |id| self.allocator.free(id);
        self.nodes.deinit(self.allocator);
        self.interactions.deinit(self.allocator);

        var iter = self.id_to_idx.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.id_to_idx.deinit();

        var t_iter = self.targets_of.iterator();
        while (t_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.targets_of.deinit();

        var r_iter = self.regulators_of.iterator();
        while (r_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.regulators_of.deinit();
    }

    pub fn addNode(self: *RegulatoryGraph, entity_id: []const u8) !usize {
        if (self.id_to_idx.get(entity_id)) |idx| return idx;

        const idx = self.nodes.items.len;
        const id_copy = try self.allocator.dupe(u8, entity_id);
        try self.nodes.append(self.allocator, id_copy);
        try self.id_to_idx.put(try self.allocator.dupe(u8, entity_id), idx);
        return idx;
    }

    pub fn addInteraction(self: *RegulatoryGraph, regulator: []const u8, target: []const u8, reg_type: RegulationType, score: f64) !void {
        const r_idx = try self.addNode(regulator);
        const t_idx = try self.addNode(target);

        const inter_idx = self.interactions.items.len;
        try self.interactions.append(self.allocator, .{
            .regulator_idx = r_idx,
            .target_idx = t_idx,
            .reg_type = reg_type,
            .score = score,
        });

        const t_entry = try self.targets_of.getOrPut(r_idx);
        if (!t_entry.found_existing) t_entry.value_ptr.* = .empty;
        try t_entry.value_ptr.append(self.allocator, inter_idx);

        const r_entry = try self.regulators_of.getOrPut(t_idx);
        if (!r_entry.found_existing) r_entry.value_ptr.* = .empty;
        try r_entry.value_ptr.append(self.allocator, inter_idx);
    }

    pub fn getTargets(self: RegulatoryGraph, regulator: []const u8) ?[]const usize {
        const idx = self.id_to_idx.get(regulator) orelse return null;
        const list = self.targets_of.get(idx) orelse return null;
        return list.items;
    }

    pub fn getRegulators(self: RegulatoryGraph, target: []const u8) ?[]const usize {
        const idx = self.id_to_idx.get(target) orelse return null;
        const list = self.regulators_of.get(idx) orelse return null;
        return list.items;
    }
};

test "RegulatoryGraph building and lookup" {
    const alloc = std.testing.allocator;
    var grn = RegulatoryGraph.init(alloc);
    defer grn.deinit();

    try grn.addInteraction("TP53", "CDKN1A", .Activation, 0.95);
    try grn.addInteraction("TP53", "CCNB1", .Repression, 0.88);

    const targets = grn.getTargets("TP53");
    try std.testing.expect(targets != null);
    try std.testing.expectEqual(@as(usize, 2), targets.?.len);

    const inter1 = grn.interactions.items[targets.?[0]];
    try std.testing.expectEqual(RegulationType.Activation, inter1.reg_type);
}
