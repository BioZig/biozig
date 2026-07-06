const std = @import("std");

/// The primary phases of the eukaryotic cell cycle.
pub const Phase = enum {
    G1,
    S,
    G2,
    M,

    pub fn toString(self: Phase) []const u8 {
        return @tagName(self);
    }
};

/// Represents the cell cycle state of an individual cell.
pub const State = struct {
    allocator: std.mem.Allocator,
    phase: Phase,
    confidence: f64 = 1.0,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, phase: Phase) State {
        return .{
            .allocator = allocator,
            .phase = phase,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *State) void {
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addMetadata(self: *State, key: []const u8, value: []const u8) !void {
        try self.metadata.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }

    pub fn serialize(self: State, writer: anytype) !void {
        const core = @import("core");
        try core.serialization.serialize(writer, self.phase);
        try core.serialization.serialize(writer, self.confidence);
        try core.serialization.serialize(writer, @as(u64, self.metadata.count()));
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            try core.serialization.serialize(writer, entry.key_ptr.*);
            try core.serialization.serialize(writer, entry.value_ptr.*);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !State {
        const core = @import("core");
        const phase = try core.serialization.deserialize(reader, Phase, allocator);
        const confidence = try core.serialization.deserialize(reader, f64, allocator);
        const count = try core.serialization.deserialize(reader, u64, allocator);
        
        var metadata = std.StringHashMap([]const u8).init(allocator);
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            const k = try core.serialization.deserialize(reader, []const u8, allocator);
            const v = try core.serialization.deserialize(reader, []const u8, allocator);
            try metadata.put(k, v);
        }
        
        return .{
            .allocator = allocator,
            .phase = phase,
            .confidence = confidence,
            .metadata = metadata,
        };
    }
};

/// Utilities for cell cycle analysis.
pub const Utils = struct {
    /// Deterministically assigns a phase based on marker scores.
    pub fn assignPhase(g1_score: f64, s_score: f64, g2m_score: f64) Phase {
        if (s_score > g1_score and s_score > g2m_score) return .S;
        if (g2m_score > g1_score) return .G2; // Simplification: G2 and M often grouped in scoring
        return .G1;
    }
};

test "Cell cycle phase assignment" {
    const p = Utils.assignPhase(0.1, 0.8, 0.2);
    try std.testing.expectEqual(Phase.S, p);
    
    var state = State.init(std.testing.allocator, .M);
    defer state.deinit();
    try state.addMetadata("marker", "phospho-H3");
    try std.testing.expectEqualStrings("phospho-H3", state.metadata.get("marker").?);
}
