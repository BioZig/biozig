const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents a Linkage Disequilibrium record between two loci.
pub const LinkageDisequilibriumRecord = struct {
    allocator: std.mem.Allocator,
    locus_a: []const u8,
    locus_b: []const u8,
    r_squared: f64,
    d_prime: f64,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, locus_a: []const u8, locus_b: []const u8, r_squared: f64, d_prime: f64) !LinkageDisequilibriumRecord {
        std.debug.assert(r_squared >= 0.0 and r_squared <= 1.0);
        std.debug.assert(d_prime >= -1.0 and d_prime <= 1.0);

        return .{
            .allocator = allocator,
            .locus_a = try allocator.dupe(u8, locus_a),
            .locus_b = try allocator.dupe(u8, locus_b),
            .r_squared = r_squared,
            .d_prime = d_prime,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *LinkageDisequilibriumRecord) void {
        self.allocator.free(self.locus_a);
        self.allocator.free(self.locus_b);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addMetadata(self: *LinkageDisequilibriumRecord, key: []const u8, value: []const u8) !void {
        try self.metadata.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }

    pub fn serialize(self: LinkageDisequilibriumRecord, writer: anytype) !void {
        try serialization.serialize(writer, self.locus_a);
        try serialization.serialize(writer, self.locus_b);
        try serialization.serialize(writer, self.r_squared);
        try serialization.serialize(writer, self.d_prime);
        try serialization.serialize(writer, @as(u64, self.metadata.count()));
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            try serialization.serialize(writer, entry.key_ptr.*);
            try serialization.serialize(writer, entry.value_ptr.*);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !LinkageDisequilibriumRecord {
        const locus_a = try serialization.deserialize(reader, []const u8, allocator);
        const locus_b = try serialization.deserialize(reader, []const u8, allocator);
        const r_squared = try serialization.deserialize(reader, f64, allocator);
        const d_prime = try serialization.deserialize(reader, f64, allocator);

        var record = try LinkageDisequilibriumRecord.init(allocator, locus_a, locus_b, r_squared, d_prime);
        allocator.free(locus_a);
        allocator.free(locus_b);

        const count = try serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            const k = try serialization.deserialize(reader, []const u8, allocator);
            const v = try serialization.deserialize(reader, []const u8, allocator);
            try record.metadata.put(k, v);
        }
        return record;
    }
};

/// A dense matrix holding LD values for a specific region.
pub const LDMatrix = struct {
    allocator: std.mem.Allocator,
    loci: [][]const u8,
    r_squared_matrix: []f64,
    d_prime_matrix: []f64,
    size: usize,

    pub fn init(allocator: std.mem.Allocator, loci: [][]const u8) !LDMatrix {
        const size = loci.len;
        const r2 = try allocator.alloc(f64, size * size);
        @memset(r2, 0.0);
        const dp = try allocator.alloc(f64, size * size);
        @memset(dp, 0.0);

        var duped_loci = try allocator.alloc([]const u8, size);
        for (loci, 0..) |l, i| {
            duped_loci[i] = try allocator.dupe(u8, l);
        }

        return .{
            .allocator = allocator,
            .loci = duped_loci,
            .r_squared_matrix = r2,
            .d_prime_matrix = dp,
            .size = size,
        };
    }

    pub fn deinit(self: *LDMatrix) void {
        for (self.loci) |l| self.allocator.free(l);
        self.allocator.free(self.loci);
        self.allocator.free(self.r_squared_matrix);
        self.allocator.free(self.d_prime_matrix);
    }

    pub fn set(self: *LDMatrix, i: usize, j: usize, r2: f64, dp: f64) void {
        std.debug.assert(i < self.size and j < self.size);
        std.debug.assert(r2 >= 0.0 and r2 <= 1.0);
        std.debug.assert(dp >= -1.0 and dp <= 1.0);

        self.r_squared_matrix[i * self.size + j] = r2;
        self.r_squared_matrix[j * self.size + i] = r2;
        self.d_prime_matrix[i * self.size + j] = dp;
        self.d_prime_matrix[j * self.size + i] = dp;
    }

    pub fn get(self: LDMatrix, i: usize, j: usize) struct { r_squared: f64, d_prime: f64 } {
        std.debug.assert(i < self.size and j < self.size);
        return .{
            .r_squared = self.r_squared_matrix[i * self.size + j],
            .d_prime = self.d_prime_matrix[i * self.size + j],
        };
    }
};

test "LD structures validation" {
    const alloc = std.testing.allocator;
    var ld = try LinkageDisequilibriumRecord.init(alloc, "rs1", "rs2", 0.8, 0.9);
    defer ld.deinit();
    try std.testing.expectEqual(@as(f64, 0.8), ld.r_squared);

    const loci = [_][]const u8{ "rs1", "rs2", "rs3" };
    var matrix = try LDMatrix.init(alloc, @constCast(&loci));
    defer matrix.deinit();

    matrix.set(0, 1, 0.5, 0.6);
    try std.testing.expectEqual(@as(f64, 0.5), matrix.get(1, 0).r_squared);
}
