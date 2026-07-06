const std = @import("std");

/// Represents a signal of positive or balancing selection.
pub const SelectionSignal = struct {
    allocator: std.mem.Allocator,
    locus: []const u8,
    statistic_name: []const u8,
    statistic_value: f64,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, locus: []const u8, statistic_name: []const u8, statistic_value: f64) !SelectionSignal {
        return .{
            .allocator = allocator,
            .locus = try allocator.dupe(u8, locus),
            .statistic_name = try allocator.dupe(u8, statistic_name),
            .statistic_value = statistic_value,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *SelectionSignal) void {
        self.allocator.free(self.locus);
        self.allocator.free(self.statistic_name);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addMetadata(self: *SelectionSignal, key: []const u8, value: []const u8) !void {
        try self.metadata.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }
};

/// A collection of selection signals for a population or genomic region.
pub const SelectionCollection = struct {
    allocator: std.mem.Allocator,
    signals: std.ArrayList(SelectionSignal),

    // Quick lookup: locus -> list of signal indices
    locus_idx: std.StringHashMap(std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) SelectionCollection {
        return .{
            .allocator = allocator,
            .signals = .empty,
            .locus_idx = std.StringHashMap(std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *SelectionCollection) void {
        for (self.signals.items) |*s| s.deinit();
        self.signals.deinit(self.allocator);

        var iter = self.locus_idx.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.locus_idx.deinit();
    }

    pub fn addSignal(self: *SelectionCollection, signal: SelectionSignal) !void {
        const idx = self.signals.items.len;
        try self.signals.append(self.allocator, signal);

        const entry = try self.locus_idx.getOrPut(signal.locus);
        if (!entry.found_existing) {
            entry.key_ptr.* = try self.allocator.dupe(u8, signal.locus);
            entry.value_ptr.* = .empty;
        }
        try entry.value_ptr.append(self.allocator, idx);
    }

    pub fn getByLocus(self: SelectionCollection, locus: []const u8) ?[]const usize {
        if (self.locus_idx.get(locus)) |list| return list.items;
        return null;
    }
};

test "SelectionSignal and Collection" {
    const alloc = std.testing.allocator;
    var col = SelectionCollection.init(alloc);
    defer col.deinit();

    const s1 = try SelectionSignal.init(alloc, "LCT", "iHS", 2.5);
    try col.addSignal(s1);

    const s2 = try SelectionSignal.init(alloc, "LCT", "TajimaD", -1.8);
    try col.addSignal(s2);

    const hits = col.getByLocus("LCT");
    try std.testing.expect(hits != null);
    try std.testing.expectEqual(@as(usize, 2), hits.?.len);

    const hit_1 = col.signals.items[hits.?[0]];
    try std.testing.expectEqualStrings("iHS", hit_1.statistic_name);
    try std.testing.expectEqual(@as(f64, 2.5), hit_1.statistic_value);
}
