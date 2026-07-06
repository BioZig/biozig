const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents an individual variant within a haplotype block.
pub const VariantRef = struct {
    allocator: std.mem.Allocator,
    variant_id: []const u8,
    allele: []const u8,

    pub fn init(allocator: std.mem.Allocator, variant_id: []const u8, allele: []const u8) !VariantRef {
        return .{
            .allocator = allocator,
            .variant_id = try allocator.dupe(u8, variant_id),
            .allele = try allocator.dupe(u8, allele),
        };
    }

    pub fn deinit(self: *VariantRef) void {
        self.allocator.free(self.variant_id);
        self.allocator.free(self.allele);
    }

    pub fn serialize(self: VariantRef, writer: anytype) !void {
        try serialization.serialize(writer, self.variant_id);
        try serialization.serialize(writer, self.allele);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !VariantRef {
        const variant_id = try serialization.deserialize(reader, []const u8, allocator);
        const allele = try serialization.deserialize(reader, []const u8, allocator);
        const vr = try VariantRef.init(allocator, variant_id, allele);
        allocator.free(variant_id);
        allocator.free(allele);
        return vr;
    }
};

/// Represents a Haplotype sequence.
pub const Haplotype = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    chromosome: []const u8,
    start_pos: usize,
    end_pos: usize,
    variants: std.ArrayList(VariantRef),

    pub fn init(allocator: std.mem.Allocator, id: []const u8, chromosome: []const u8, start_pos: usize, end_pos: usize) !Haplotype {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .chromosome = try allocator.dupe(u8, chromosome),
            .start_pos = start_pos,
            .end_pos = end_pos,
            .variants = .empty,
        };
    }

    pub fn deinit(self: *Haplotype) void {
        self.allocator.free(self.id);
        self.allocator.free(self.chromosome);
        for (self.variants.items) |*v| v.deinit();
        self.variants.deinit(self.allocator);
    }

    pub fn addVariant(self: *Haplotype, variant_id: []const u8, allele: []const u8) !void {
        try self.variants.append(self.allocator, try VariantRef.init(self.allocator, variant_id, allele));
    }

    pub fn serialize(self: Haplotype, writer: anytype) !void {
        try serialization.serialize(writer, self.id);
        try serialization.serialize(writer, self.chromosome);
        try serialization.serialize(writer, self.start_pos);
        try serialization.serialize(writer, self.end_pos);
        try serialization.serialize(writer, @as(u64, self.variants.items.len));
        for (self.variants.items) |v| {
            try v.serialize(writer);
        }
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Haplotype {
        const id = try serialization.deserialize(reader, []const u8, allocator);
        const chromosome = try serialization.deserialize(reader, []const u8, allocator);
        const start_pos = try serialization.deserialize(reader, usize, allocator);
        const end_pos = try serialization.deserialize(reader, usize, allocator);

        var hap = try Haplotype.init(allocator, id, chromosome, start_pos, end_pos);
        allocator.free(id);
        allocator.free(chromosome);

        const var_count = try serialization.deserialize(reader, u64, allocator);
        var i: u64 = 0;
        while (i < var_count) : (i += 1) {
            const v = try VariantRef.deserialize(reader, allocator);
            try hap.variants.append(allocator, v);
        }
        return hap;
    }
};

/// Represents a Haplotype Block.
pub const HaplotypeBlock = struct {
    allocator: std.mem.Allocator,
    chromosome: []const u8,
    start_pos: usize,
    end_pos: usize,
    haplotypes: std.StringHashMap(Haplotype),

    pub fn init(allocator: std.mem.Allocator, chromosome: []const u8, start_pos: usize, end_pos: usize) !HaplotypeBlock {
        return .{
            .allocator = allocator,
            .chromosome = try allocator.dupe(u8, chromosome),
            .start_pos = start_pos,
            .end_pos = end_pos,
            .haplotypes = std.StringHashMap(Haplotype).init(allocator),
        };
    }

    pub fn deinit(self: *HaplotypeBlock) void {
        self.allocator.free(self.chromosome);
        var iter = self.haplotypes.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.haplotypes.deinit();
    }

    pub fn addHaplotype(self: *HaplotypeBlock, haplotype: Haplotype) !void {
        const key = try self.allocator.dupe(u8, haplotype.id);
        try self.haplotypes.put(key, haplotype);
    }

    pub fn getHaplotype(self: HaplotypeBlock, id: []const u8) ?Haplotype {
        return self.haplotypes.get(id);
    }
};

test "Haplotype creation and serialization" {
    const alloc = std.testing.allocator;
    var hap = try Haplotype.init(alloc, "HAP_01", "chr1", 1000, 2000);
    defer hap.deinit();

    try hap.addVariant("rs123", "A");
    try hap.addVariant("rs456", "T");

    try std.testing.expectEqual(@as(usize, 2), hap.variants.items.len);
    try std.testing.expectEqualStrings("A", hap.variants.items[0].allele);

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try hap.serialize(&writer);

    var reader = std.Io.Reader.fixed(writer.buffered());
    var deserialized = try Haplotype.deserialize(&reader, alloc);
    defer deserialized.deinit();

    try std.testing.expectEqualStrings("HAP_01", deserialized.id);
    try std.testing.expectEqual(@as(usize, 2), deserialized.variants.items.len);
    try std.testing.expectEqualStrings("T", deserialized.variants.items[1].allele);
}
