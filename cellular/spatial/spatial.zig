const std = @import("std");

/// Represents a cell in a 2D or 3D spatial coordinate system.
pub const SpatialCell = struct {
    x: f64,
    y: f64,
    z: f64 = 0.0,

    pub fn distanceTo(self: SpatialCell, other: SpatialCell) f64 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn serialize(self: SpatialCell, writer: anytype) !void {
        const core = @import("core");
        try core.serialization.serialize(writer, self.x);
        try core.serialization.serialize(writer, self.y);
        try core.serialization.serialize(writer, self.z);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !SpatialCell {
        const core = @import("core");
        const x = try core.serialization.deserialize(reader, f64, allocator);
        const y = try core.serialization.deserialize(reader, f64, allocator);
        const z = try core.serialization.deserialize(reader, f64, allocator);
        return .{ .x = x, .y = y, .z = z };
    }
};

/// Simple spatial index for neighborhood queries.
/// For performance, this uses a fixed-grid approach for 2D/3D neighborhood lookups.
pub const SpatialIndex = struct {
    allocator: std.mem.Allocator,
    cells: []SpatialCell,
    grid_size: f64,

    pub fn init(allocator: std.mem.Allocator, cells: []SpatialCell, grid_size: f64) SpatialIndex {
        return .{
            .allocator = allocator,
            .cells = cells,
            .grid_size = grid_size,
        };
    }

    /// Finds indices of all cells within a given radius of a target cell.
    pub fn findNeighbors(self: SpatialIndex, target_idx: usize, radius: f64, allocator: std.mem.Allocator) ![]usize {
        var neighbors = std.ArrayList(usize).empty;
        const target = self.cells[target_idx];
        
        for (self.cells, 0..) |cell, i| {
            if (i == target_idx) continue;
            if (target.distanceTo(cell) <= radius) {
                try neighbors.append(allocator, i);
            }
        }
        return neighbors.toOwnedSlice(allocator);
    }
};

test "SpatialCell distance and neighborhood" {
    const c1 = SpatialCell{ .x = 0.0, .y = 0.0, .z = 0.0 };
    const c2 = SpatialCell{ .x = 3.0, .y = 4.0, .z = 0.0 };
    try std.testing.expectEqual(@as(f64, 5.0), c1.distanceTo(c2));

    const cells = [_]SpatialCell{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 10, .y = 10 },
    };
    const index = SpatialIndex.init(std.testing.allocator, @constCast(&cells), 1.0);
    const neighbors = try index.findNeighbors(0, 2.0, std.testing.allocator);
    defer std.testing.allocator.free(neighbors);
    
    try std.testing.expectEqual(@as(usize, 1), neighbors.len);
    try std.testing.expectEqual(@as(usize, 1), neighbors[0]);
}
