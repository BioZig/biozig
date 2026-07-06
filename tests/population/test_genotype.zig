const std = @import("std");
const pop = @import("population");
const geno = pop.genotype;

test "BitpackedGenotypes - init and bounds" {
    const alloc = std.testing.allocator;
    var bg = try geno.BitpackedGenotypes.init(alloc, 5, 100); // 5 variants, 100 samples
    defer bg.deinit();
    
    try std.testing.expectEqual(@as(usize, 5), bg.num_variants);
    try std.testing.expectEqual(@as(usize, 100), bg.num_samples);
    
    // Check initial state (all hom_ref)
    for (0..5) |v| {
        for (0..100) |s| {
            try std.testing.expectEqual(geno.GenotypeState.hom_ref, bg.get(v, s));
        }
    }
}

test "BitpackedGenotypes - set and get" {
    const alloc = std.testing.allocator;
    var bg = try geno.BitpackedGenotypes.init(alloc, 10, 150);
    defer bg.deinit();
    
    bg.set(0, 0, .hom_alt);
    bg.set(0, 1, .het);
    bg.set(0, 31, .missing);
    bg.set(0, 32, .hom_alt);
    bg.set(9, 149, .het);
    
    try std.testing.expectEqual(geno.GenotypeState.hom_alt, bg.get(0, 0));
    try std.testing.expectEqual(geno.GenotypeState.het, bg.get(0, 1));
    try std.testing.expectEqual(geno.GenotypeState.missing, bg.get(0, 31));
    try std.testing.expectEqual(geno.GenotypeState.hom_alt, bg.get(0, 32));
    try std.testing.expectEqual(geno.GenotypeState.hom_ref, bg.get(0, 33)); // not set
    try std.testing.expectEqual(geno.GenotypeState.het, bg.get(9, 149));
    
    // Test overriding
    bg.set(0, 0, .missing);
    try std.testing.expectEqual(geno.GenotypeState.missing, bg.get(0, 0));
}

test "BitpackedGenotypes - edge cases" {
    const alloc = std.testing.allocator;
    // 0 variants, 0 samples
    var bg1 = try geno.BitpackedGenotypes.init(alloc, 0, 0);
    defer bg1.deinit();
    try std.testing.expectEqual(@as(usize, 0), bg1.num_variants);
    
    // Large number of samples (multiple blocks)
    var bg2 = try geno.BitpackedGenotypes.init(alloc, 1, 1000);
    defer bg2.deinit();
    bg2.set(0, 999, .hom_alt);
    try std.testing.expectEqual(geno.GenotypeState.hom_alt, bg2.get(0, 999));
}
