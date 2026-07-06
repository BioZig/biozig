const std = @import("std");
const genotype = @import("genotype.zig");
const BitpackedGenotypes = genotype.BitpackedGenotypes;
const GenotypeState = genotype.GenotypeState;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 10M+ variants and large panel
    const num_variants = 10_000_000;
    const num_samples = 1000;

    std.debug.print("Initializing {} variants x {} samples bitpacked genotype structure...\n", .{ num_variants, num_samples });

    var genotypes = try BitpackedGenotypes.init(allocator, num_variants, num_samples);
    defer genotypes.deinit();

    const expected_bytes = num_variants * ((num_samples + 31) / 32) * @sizeOf(u64);
    std.debug.print("Memory allocated: {} MB\n", .{expected_bytes / (1024 * 1024)});

    std.debug.print("Populating genotypes...\n", .{});

    // Fill with some data
    var prng = std.Random.Pcg.init(42);
    const random = prng.random();

    for (0..100) |v| {
        for (0..num_samples) |s| {
            const state = @as(GenotypeState, @enumFromInt(random.int(u2)));
            genotypes.set(v, s, state);
        }
    }

    std.debug.print("Computing Allele Frequency for a variant...\n", .{});

    // Benchmark scanning a variant
    var total_alts: usize = 0;
    var total_called: usize = 0;
    for (0..num_samples) |s| {
        const state = genotypes.get(0, s);
        switch (state) {
            .hom_ref => {
                total_called += 2;
            },
            .het => {
                total_called += 2;
                total_alts += 1;
            },
            .hom_alt => {
                total_called += 2;
                total_alts += 2;
            },
            .missing => {},
        }
    }

    std.debug.print("Total alts: {}, Total called: {}\n", .{ total_alts, total_called });
    std.debug.print("Benchmark completed.\n", .{});
}
