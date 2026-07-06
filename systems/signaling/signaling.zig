const std = @import("std");

pub const SignalingEvent = enum(u8) {
    Phosphorylation,
    Dephosphorylation,
    Ubiquitination,
    Binding,
    Cleavage,
};

/// Represents a signaling interaction in a pathway.
pub const SignalingInteraction = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    target: []const u8,
    event: SignalingEvent,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, target: []const u8, event: SignalingEvent) !SignalingInteraction {
        return .{
            .allocator = allocator,
            .source = try allocator.dupe(u8, source),
            .target = try allocator.dupe(u8, target),
            .event = event,
        };
    }

    pub fn deinit(self: *SignalingInteraction) void {
        self.allocator.free(self.source);
        self.allocator.free(self.target);
    }
};

/// Represents a signaling cascade or network.
pub const SignalingNetwork = struct {
    allocator: std.mem.Allocator,
    interactions: std.ArrayList(SignalingInteraction),

    // Quick lookup: source -> list of interaction indices
    downstream: std.StringHashMap(std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) SignalingNetwork {
        return .{
            .allocator = allocator,
            .interactions = .empty,
            .downstream = std.StringHashMap(std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *SignalingNetwork) void {
        for (self.interactions.items) |*i| i.deinit();
        self.interactions.deinit(self.allocator);

        var iter = self.downstream.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.downstream.deinit();
    }

    pub fn addEvent(self: *SignalingNetwork, source: []const u8, target: []const u8, event: SignalingEvent) !void {
        const idx = self.interactions.items.len;
        const interaction = try SignalingInteraction.init(self.allocator, source, target, event);
        try self.interactions.append(self.allocator, interaction);

        const entry = try self.downstream.getOrPut(source);
        if (!entry.found_existing) {
            entry.key_ptr.* = try self.allocator.dupe(u8, source);
            entry.value_ptr.* = .empty;
        }
        try entry.value_ptr.append(self.allocator, idx);
    }

    pub fn getDownstreamEvents(self: SignalingNetwork, source: []const u8) ?[]const usize {
        if (self.downstream.get(source)) |list| {
            return list.items;
        }
        return null;
    }
};

test "SignalingNetwork cascade" {
    const alloc = std.testing.allocator;
    var net = SignalingNetwork.init(alloc);
    defer net.deinit();

    try net.addEvent("EGFR", "GRB2", .Binding);
    try net.addEvent("RAF1", "KRAS", .Binding); // simplified
    try net.addEvent("MAP2K1", "MAP2K2", .Phosphorylation);

    const down = net.getDownstreamEvents("MAP2K1");
    try std.testing.expect(down != null);

    const inter = net.interactions.items[down.?[0]];
    try std.testing.expectEqualStrings("MAP2K2", inter.target);
    try std.testing.expectEqual(SignalingEvent.Phosphorylation, inter.event);
}
