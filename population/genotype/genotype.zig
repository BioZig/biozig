const std = @import("std");

pub const GenotypeState = enum(u2) {
    hom_ref = 0,
    het = 1,
    hom_alt = 2,
    missing = 3,
};

pub const BitpackedGenotypes = struct {
    allocator: std.mem.Allocator,
    num_variants: usize,
    num_samples: usize,
    blocks_per_variant: usize,
    data: []u64,

    pub fn init(allocator: std.mem.Allocator, num_variants: usize, num_samples: usize) !BitpackedGenotypes {
        const blocks_per_variant = (num_samples + 31) / 32;
        const total_blocks = num_variants * blocks_per_variant;
        const data = try allocator.alloc(u64, total_blocks);
        // Initialize with hom_ref (0).
        @memset(data, 0);

        return BitpackedGenotypes{
            .allocator = allocator,
            .num_variants = num_variants,
            .num_samples = num_samples,
            .blocks_per_variant = blocks_per_variant,
            .data = data,
        };
    }

    pub fn deinit(self: *BitpackedGenotypes) void {
        self.allocator.free(self.data);
    }

    pub inline fn set(self: *BitpackedGenotypes, variant_idx: usize, sample_idx: usize, state: GenotypeState) void {
        const block_idx = (variant_idx * self.blocks_per_variant) + (sample_idx / 32);
        const shift = @as(u6, @intCast((sample_idx % 32) * 2));
        const mask = ~(@as(u64, 3) << shift);
        const val = @as(u64, @intFromEnum(state)) << shift;
        
        self.data[block_idx] = (self.data[block_idx] & mask) | val;
    }

    pub inline fn get(self: *const BitpackedGenotypes, variant_idx: usize, sample_idx: usize) GenotypeState {
        const block_idx = (variant_idx * self.blocks_per_variant) + (sample_idx / 32);
        const shift = @as(u6, @intCast((sample_idx % 32) * 2));
        const val = (self.data[block_idx] >> shift) & 3;
        return @as(GenotypeState, @enumFromInt(@as(u2, @intCast(val))));
    }
};

test "BitpackedGenotypes basic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var genotypes = try BitpackedGenotypes.init(allocator, 10, 100);
    genotypes.set(0, 0, .hom_alt);
    genotypes.set(0, 5, .het);
    genotypes.set(1, 99, .missing);

    try std.testing.expectEqual(GenotypeState.hom_alt, genotypes.get(0, 0));
    try std.testing.expectEqual(GenotypeState.hom_ref, genotypes.get(0, 1));
    try std.testing.expectEqual(GenotypeState.het, genotypes.get(0, 5));
    try std.testing.expectEqual(GenotypeState.missing, genotypes.get(1, 99));
}
