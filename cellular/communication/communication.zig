const std = @import("std");

/// Represents a single cell-cell interaction.
pub const Interaction = struct {
    allocator: std.mem.Allocator,
    sender_idx: usize,
    receiver_idx: usize,
    ligand: []const u8,
    receptor: []const u8,
    score: f64,

    pub fn init(allocator: std.mem.Allocator, sender: usize, receiver: usize, ligand: []const u8, receptor: []const u8, score: f64) !Interaction {
        return .{
            .allocator = allocator,
            .sender_idx = sender,
            .receiver_idx = receiver,
            .ligand = try allocator.dupe(u8, ligand),
            .receptor = try allocator.dupe(u8, receptor),
            .score = score,
        };
    }

    pub fn deinit(self: *Interaction) void {
        self.allocator.free(self.ligand);
        self.allocator.free(self.receptor);
    }

    pub fn serialize(self: Interaction, writer: anytype) !void {
        const core = @import("core");
        try core.serialization.serialize(writer, self.sender_idx);
        try core.serialization.serialize(writer, self.receiver_idx);
        try core.serialization.serialize(writer, self.ligand);
        try core.serialization.serialize(writer, self.receptor);
        try core.serialization.serialize(writer, self.score);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Interaction {
        const core = @import("core");
        const sender = try core.serialization.deserialize(reader, usize, allocator);
        const receiver = try core.serialization.deserialize(reader, usize, allocator);
        const ligand = try core.serialization.deserialize(reader, []const u8, allocator);
        const receptor = try core.serialization.deserialize(reader, []const u8, allocator);
        const score = try core.serialization.deserialize(reader, f64, allocator);
        return .{
            .allocator = allocator,
            .sender_idx = sender,
            .receiver_idx = receiver,
            .ligand = ligand,
            .receptor = receptor,
            .score = score,
        };
    }
};

/// A graph representing communication events between cells.
pub const InteractionGraph = struct {
    allocator: std.mem.Allocator,
    interactions: std.ArrayList(Interaction),

    /// Map from (sender, receiver) to list of interaction indices.
    adj: std.AutoHashMap([2]usize, std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) InteractionGraph {
        return .{
            .allocator = allocator,
            .interactions = .empty,
            .adj = std.AutoHashMap([2]usize, std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *InteractionGraph) void {
        for (self.interactions.items) |*i| i.deinit();
        self.interactions.deinit(self.allocator);

        var iter = self.adj.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.adj.deinit();
    }

    pub fn addInteraction(self: *InteractionGraph, interaction: Interaction) !void {
        const idx = self.interactions.items.len;
        try self.interactions.append(self.allocator, interaction);

        const key = [2]usize{ interaction.sender_idx, interaction.receiver_idx };
        const entry = try self.adj.getOrPut(key);
        if (!entry.found_existing) entry.value_ptr.* = .empty;
        try entry.value_ptr.append(self.allocator, idx);
    }

    pub fn serialize(self: InteractionGraph, writer: anytype) !void {
        const core = @import("core");
        try core.serialization.serialize(writer, @as(u64, self.interactions.items.len));
        for (self.interactions.items) |i| {
            try i.serialize(writer);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !InteractionGraph {
        const core = @import("core");
        var graph = InteractionGraph.init(allocator);
        const count = try core.serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            try graph.addInteraction(try Interaction.deserialize(reader, allocator));
        }
        return graph;
    }

    pub fn getInteractions(self: InteractionGraph, sender: usize, receiver: usize) ?[]const usize {
        const key = [2]usize{ sender, receiver };
        const list = self.adj.get(key) orelse return null;
        return list.items;
    }
};

test "InteractionGraph building and lookup" {
    const alloc = std.testing.allocator;
    var graph = InteractionGraph.init(alloc);
    defer graph.deinit();

    const inter1 = try Interaction.init(alloc, 0, 1, "TNF", "TNFRSF1A", 0.9);
    try graph.addInteraction(inter1);

    const matches = graph.getInteractions(0, 1);
    try std.testing.expect(matches != null);
    try std.testing.expectEqual(@as(usize, 1), matches.?.len);

    const retrieved = graph.interactions.items[matches.?[0]];
    try std.testing.expectEqualStrings("TNF", retrieved.ligand);
}
