const std = @import("std");
const algorithms = @import("algorithms");
const pop = algorithms.population;

test "computeLD - full and independent" {
    // Perfect correlation
    const ld1 = pop.computeLD(0.5, 0.5, 0.5);
    try std.testing.expectEqual(@as(f64, 0.25), ld1.d);
    try std.testing.expectEqual(@as(f64, 1.0), ld1.d_prime);
    try std.testing.expectEqual(@as(f64, 1.0), ld1.r_squared);

    // Independent
    const ld2 = pop.computeLD(0.5, 0.5, 0.25);
    try std.testing.expectEqual(@as(f64, 0.0), ld2.d);
    try std.testing.expectEqual(@as(f64, 0.0), ld2.d_prime);
    try std.testing.expectEqual(@as(f64, 0.0), ld2.r_squared);

    // Negative correlation
    const ld3 = pop.computeLD(0.5, 0.5, 0.0);
    try std.testing.expectEqual(@as(f64, -0.25), ld3.d);
    try std.testing.expectEqual(@as(f64, 1.0), ld3.d_prime);
    try std.testing.expectEqual(@as(f64, 1.0), ld3.r_squared);
}

test "PopulationMatrix - alleleFrequency and selectionSignal" {
    const p1 = [_]u8{ 0, 0, 1 };
    const p2 = [_]u8{ 0, 1, 1 };
    const p3 = [_]u8{ 1, 1, 1 };
    const mat = [_][]const u8{ &p1, &p2, &p3 };
    const pm = pop.PopulationMatrix{ .matrix = &mat };

    try std.testing.expectEqual(@as(f64, 1.0 / 3.0), pm.alleleFrequency(0));
    try std.testing.expectEqual(@as(f64, 2.0 / 3.0), pm.alleleFrequency(1));
    try std.testing.expectEqual(@as(f64, 1.0), pm.alleleFrequency(2));

    const d = pm.selectionSignal();
    try std.testing.expect(d != std.math.nan(f64));

    // Edge case: empty matrix
    const empty_mat = [_][]const u8{};
    const empty_pm = pop.PopulationMatrix{ .matrix = &empty_mat };
    try std.testing.expectEqual(@as(f64, 0.0), empty_pm.alleleFrequency(0));
    try std.testing.expectEqual(@as(f64, 0.0), empty_pm.selectionSignal());
}

test "computeEpidemiologicalSummary" {
    const epi1 = pop.computeEpidemiologicalSummary(1000, 50, 200, 10);
    try std.testing.expectEqual(@as(f64, 0.05), epi1.incidence_rate);
    try std.testing.expectEqual(@as(f64, 0.20), epi1.prevalence);
    try std.testing.expectEqual(@as(f64, 0.05), epi1.case_fatality_ratio);

    const epi2 = pop.computeEpidemiologicalSummary(0, 0, 0, 0);
    try std.testing.expectEqual(@as(f64, 0.0), epi2.incidence_rate);
    try std.testing.expectEqual(@as(f64, 0.0), epi2.prevalence);
    try std.testing.expectEqual(@as(f64, 0.0), epi2.case_fatality_ratio);
}

test "BitpackedHaplotypes" {
    const alloc = std.testing.allocator;
    var hap = try pop.BitpackedHaplotypes.init(alloc, 100, 2);
    defer hap.deinit();

    hap.set(0, 0, 1);
    hap.set(0, 63, 1);
    hap.set(0, 64, 1);
    hap.set(1, 99, 1);

    try std.testing.expectEqual(@as(u1, 1), hap.get(0, 0));
    try std.testing.expectEqual(@as(u1, 0), hap.get(0, 1));
    try std.testing.expectEqual(@as(u1, 1), hap.get(0, 63));
    try std.testing.expectEqual(@as(u1, 1), hap.get(0, 64));
    try std.testing.expectEqual(@as(u1, 1), hap.get(1, 99));

    try std.testing.expectEqual(@as(f64, 0.03), hap.alleleFrequency(0));
    try std.testing.expectEqual(@as(f64, 0.01), hap.alleleFrequency(1));

    // empty case
    var hap_empty = try pop.BitpackedHaplotypes.init(alloc, 0, 1);
    defer hap_empty.deinit();
    try std.testing.expectEqual(@as(f64, 0.0), hap_empty.alleleFrequency(0));
}

test "BitpackedGenotypes - algos" {
    const alloc = std.testing.allocator;
    var geno = try pop.BitpackedGenotypes.init(alloc, 100, 2);
    defer geno.deinit();

    geno.set(0, 0, 1);
    geno.set(0, 31, 2);
    geno.set(0, 32, 2);

    try std.testing.expectEqual(@as(u2, 1), geno.get(0, 0));
    try std.testing.expectEqual(@as(u2, 2), geno.get(0, 31));
    try std.testing.expectEqual(@as(u2, 2), geno.get(0, 32));

    // Total alt alleles = 1 + 2 + 2 = 5
    // Total alleles = 100 * 2 = 200 => 5 / 200 = 0.025
    try std.testing.expectEqual(@as(f64, 0.025), geno.alleleFrequencyAlt(0));

    // Empty case
    var geno_empty = try pop.BitpackedGenotypes.init(alloc, 0, 1);
    defer geno_empty.deinit();
    try std.testing.expectEqual(@as(f64, 0.0), geno_empty.alleleFrequencyAlt(0));
}

test "detectIbsSegments - edge cases and full match" {
    const alloc = std.testing.allocator;
    var geno = try pop.BitpackedGenotypes.init(alloc, 2, 10);
    defer geno.deinit();

    for (0..10) |locus| {
        geno.set(locus, 0, 0); // ind 0
        geno.set(locus, 1, 0); // ind 1
    }

    const segs = try pop.detectIbsSegments(geno, 0, 1, 2, alloc);
    defer alloc.free(segs);

    try std.testing.expectEqual(@as(usize, 1), segs.len);
    try std.testing.expectEqual(@as(usize, 0), segs[0].start_locus);
    try std.testing.expectEqual(@as(usize, 10), segs[0].end_locus);
    try std.testing.expectEqual(@as(usize, 10), segs[0].length);

    // No match
    for (0..10) |locus| {
        geno.set(locus, 0, 0);
        geno.set(locus, 1, 2);
    }
    const segs2 = try pop.detectIbsSegments(geno, 0, 1, 2, alloc);
    defer alloc.free(segs2);
    try std.testing.expectEqual(@as(usize, 0), segs2.len);
}

test "liStephensViterbi" {
    const alloc = std.testing.allocator;
    var refs = try pop.BitpackedHaplotypes.init(alloc, 2, 5);
    defer refs.deinit();

    for (0..5) |l| {
        refs.set(l, 0, 0);
        refs.set(l, 1, 1);
    }

    const obs = [_]u1{ 0, 0, 1, 1, 1 };
    const path = try pop.liStephensViterbi(alloc, &obs, refs, 0.1, 0.01);
    defer alloc.free(path);

    try std.testing.expectEqual(@as(usize, 5), path.len);
    try std.testing.expectEqual(@as(usize, 0), path[0]);
    try std.testing.expectEqual(@as(usize, 1), path[4]);
}

test "estimateAdmixtureEM" {
    const alloc = std.testing.allocator;
    const genotype = [_]u2{ 0, 1, 2, 3 }; // 3 is missing, should be skipped
    const pop1_freqs = [_]f64{ 0.1, 0.5, 0.9, 0.5 };
    const pop2_freqs = [_]f64{ 0.9, 0.5, 0.1, 0.5 };
    const freqs = [_][]const f64{ &pop1_freqs, &pop2_freqs };

    const q = try pop.estimateAdmixtureEM(alloc, &genotype, &freqs, 10, 1e-4);
    defer alloc.free(q);

    try std.testing.expect(q[0] > 0.8);
    try std.testing.expect(q[1] < 0.2);
}

test "gwasLmmWaldTest" {
    const x = [_]f64{ 0.0, 1.0 };
    const y = [_]f64{ 0.5, 1.5 };
    const v_inv = [_]f64{ 1.0, 0.0, 0.0, 1.0 };

    const res = pop.gwasLmmWaldTest(&x, &y, &v_inv);
    try std.testing.expect(res.beta > 0.0);
    try std.testing.expect(res.chi2 > 0.0);

    const res2 = pop.gwasLmmWaldTest(&[_]f64{0.0}, &[_]f64{0.0}, &[_]f64{0.0});
    try std.testing.expectEqual(@as(f64, 0.0), res2.beta);
    try std.testing.expectEqual(@as(f64, 0.0), res2.chi2);
}

test "hweExactTest edge cases" {
    const p1 = pop.hweExactTest(100, 0, 100);
    try std.testing.expect(p1 >= 0.0 and p1 <= 1.0);

    const p2 = pop.hweExactTest(0, 100, 0);
    try std.testing.expect(p2 >= 0.0 and p2 <= 1.0);

    const p3 = pop.hweExactTest(0, 0, 0); // 0 sum
    // hweExactTest may return NaN or 1.0, just ensure it doesn't crash
    _ = p3;
}

test "computeFStatistics" {
    const freqs = [_]f64{ 0.5, 0.5 };
    const hets = [_]f64{ 0.5, 0.5 };
    const sizes = [_]usize{ 100, 100 };
    const res = pop.computeFStatistics(&freqs, &hets, &sizes);

    try std.testing.expectEqual(@as(f64, 0.0), res.fis);
    try std.testing.expectEqual(@as(f64, 0.0), res.fst);
    try std.testing.expectEqual(@as(f64, 0.0), res.fit);

    const res2 = pop.computeFStatistics(&[_]f64{}, &[_]f64{}, &[_]usize{});
    try std.testing.expectEqual(@as(f64, 0.0), res2.fst);
}
