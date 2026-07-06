const std = @import("std");
const genotype = @import("../population/genotype/genotype.zig");
const BitpackedGenotypes = genotype.BitpackedGenotypes;
const GenotypeState = genotype.GenotypeState;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 10M+ variants and large panel
    const num_variants = 10_000_000;
    const num_samples = 1000;

    std.debug.print("Initializing {} variants x {} samples bitpacked genotype structure...\n", .{ num_variants, num_samples });

    var timer = try std.time.Timer.start();
    var genotypes = try BitpackedGenotypes.init(allocator, num_variants, num_samples);
    defer genotypes.deinit();

    var elapsed = timer.read();
    std.debug.print("Initialization took: {d:.3} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});

    const expected_bytes = num_variants * ((num_samples + 31) / 32) * @sizeOf(u64);
    std.debug.print("Memory allocated: {} MB\n", .{expected_bytes / (1024 * 1024)});

    std.debug.print("Populating genotypes...\n", .{});
    timer.reset();

    // Fill with some data
    var prng = std.rand.Pcg.init(42);
    const random = prng.random();

    for (0..100) |v| {
        for (0..num_samples) |s| {
            const r = random.intRangeLessThan(u2, 0, 4);
            const state = @as(GenotypeState, @enumFromInt(r));
            genotypes.set(v, s, state);
        }
    }
    elapsed = timer.read();
    std.debug.print("Setting 100 variants (x 1000 samples) took: {d:.3} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});

    std.debug.print("Computing Allele Frequency for a variant...\n", .{});
    timer.reset();

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

    elapsed = timer.read();
    std.debug.print("Scanning 1 variant (1000 samples) took: {d:.3} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    std.debug.print("Total alts: {}, Total called: {}\n", .{ total_alts, total_called });

    std.debug.print("Benchmark completed.\n", .{});
}
