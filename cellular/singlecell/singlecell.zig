const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents an individual cell with its associated data and metadata.
pub const Cell = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    features: []f64,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, id: []const u8, num_features: usize) !Cell {
        const features = try allocator.alloc(f64, num_features);
        @memset(features, 0.0);
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .features = features,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Cell) void {
        self.allocator.free(self.id);
        self.allocator.free(self.features);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addMetadata(self: *Cell, key: []const u8, value: []const u8) !void {
        try self.metadata.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }

    pub fn serialize(self: Cell, writer: anytype) !void {
        try serialization.serialize(writer, self.id);
        try serialization.serialize(writer, self.features);

        try serialization.serialize(writer, @as(u64, self.metadata.count()));
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            try serialization.serialize(writer, entry.key_ptr.*);
            try serialization.serialize(writer, entry.value_ptr.*);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Cell {
        const id = try serialization.deserialize(reader, []const u8, allocator);
        const features = try serialization.deserialize(reader, []f64, allocator);
        const count = try serialization.deserialize(reader, u64, allocator);

        var metadata = std.StringHashMap([]const u8).init(allocator);
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            const k = try serialization.deserialize(reader, []const u8, allocator);
            const v = try serialization.deserialize(reader, []const u8, allocator);
            try metadata.put(k, v);
        }

        return .{
            .allocator = allocator,
            .id = id,
            .features = features,
            .metadata = metadata,
        };
    }
};

/// A collection of cells representing a single-cell dataset or cluster.
pub const CellCollection = struct {
    allocator: std.mem.Allocator,
    cells: std.ArrayList(Cell),
    annotations: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) CellCollection {
        return .{
            .allocator = allocator,
            .cells = .empty,
            .annotations = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *CellCollection) void {
        for (self.cells.items) |*cell| {
            cell.deinit();
        }
        self.cells.deinit(self.allocator);
        var iter = self.annotations.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.annotations.deinit();
    }

    pub fn addCell(self: *CellCollection, cell: Cell) !void {
        try self.cells.append(self.allocator, cell);
    }

    pub fn serialize(self: CellCollection, writer: anytype) !void {
        try serialization.serialize(writer, @as(u64, self.cells.items.len));
        for (self.cells.items) |cell| {
            try cell.serialize(writer);
        }

        try serialization.serialize(writer, @as(u64, self.annotations.count()));
        var iter = self.annotations.iterator();
        while (iter.next()) |entry| {
            try serialization.serialize(writer, entry.key_ptr.*);
            try serialization.serialize(writer, entry.value_ptr.*);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !CellCollection {
        const cell_count = try serialization.deserialize(reader, u64, allocator);
        var cells = std.ArrayList(Cell).empty;
        var i: u64 = 0;
        while (i < cell_count) : (i += 1) {
            try cells.append(allocator, try Cell.deserialize(reader, allocator));
        }

        const ann_count = try serialization.deserialize(reader, u64, allocator);
        var annotations = std.StringHashMap([]const u8).init(allocator);
        var j: u64 = 0;
        while (j < ann_count) : (j += 1) {
            const k = try serialization.deserialize(reader, []const u8, allocator);
            const v = try serialization.deserialize(reader, []const u8, allocator);
            try annotations.put(k, v);
        }

        return .{
            .allocator = allocator,
            .cells = cells,
            .annotations = annotations,
        };
    }

    /// Neighborhood representation: adjacency list of cell indices.
    pub const Neighborhood = struct {
        adj: std.AutoHashMap(usize, std.ArrayList(usize)),

        pub fn init(allocator: std.mem.Allocator) Neighborhood {
            return .{ .adj = std.AutoHashMap(usize, std.ArrayList(usize)).init(allocator) };
        }

        pub fn deinit(self: *Neighborhood) void {
            var iter = self.adj.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit(self.adj.allocator);
            }
            self.adj.deinit();
        }

        pub fn addEdge(self: *Neighborhood, a: usize, b: usize) !void {
            const entry1 = try self.adj.getOrPut(a);
            if (!entry1.found_existing) entry1.value_ptr.* = .empty;
            try entry1.value_ptr.append(self.adj.allocator, b);

            const entry2 = try self.adj.getOrPut(b);
            if (!entry2.found_existing) entry2.value_ptr.* = .empty;
            try entry2.value_ptr.append(self.adj.allocator, a);
        }
    };
};

test "Cell and CellCollection basic usage" {
    const alloc = std.testing.allocator;
    var cell = try Cell.init(alloc, "Cell_A", 5);
    defer cell.deinit();

    try cell.addMetadata("type", "Neuron");
    try std.testing.expectEqualStrings("Neuron", cell.metadata.get("type").?);

    var collection = CellCollection.init(alloc);
    defer collection.deinit();

    try collection.addCell(try Cell.init(alloc, "Cell_B", 5));
    try std.testing.expectEqual(@as(usize, 1), collection.cells.items.len);
}
