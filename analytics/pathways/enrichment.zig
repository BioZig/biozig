const std = @import("std");

/// Calculate ln(n!) using lgamma(n + 1)
fn lnFact(n: usize) f64 {
    return std.math.lgamma(f64, @as(f64, @floatFromInt(n)) + 1.0);
}

/// Calculate ln(nCr)
fn lnComb(n: usize, k: usize) f64 {
    if (k > n) return -std.math.inf(f64);
    if (k == 0 or k == n) return 0.0;
    return lnFact(n) - lnFact(k) - lnFact(n - k);
}

/// Calculate hypergeometric probability P(X = x)
pub fn hypergeometricPdf(k: usize, K: usize, n: usize, N: usize) f64 {
    if (k > K or k > n or (n - k) > (N - K)) return 0.0;
    const ln_p = lnComb(K, k) + lnComb(N - K, n - k) - lnComb(N, n);
    return @exp(ln_p);
}

/// Calculate hypergeometric p-value P(X >= k)
pub fn hypergeometricPValue(k: usize, K: usize, n: usize, N: usize) f64 {
    var p_val: f64 = 0.0;
    const max_k = @min(n, K);
    if (k > max_k) return 0.0;

    var i: usize = k;
    while (i <= max_k) : (i += 1) {
        p_val += hypergeometricPdf(i, K, n, N);
    }
    return @min(p_val, 1.0);
}

pub const RankedGene = struct {
    id: []const u8,
    score: f64,
};

pub const GseaResult = struct {
    enrichment_score: f64,
    p_value: f64,
};

/// Computes the Enrichment Score (ES) for a given gene set
pub fn calculateEnrichmentScore(
    ranked_list: []const RankedGene,
    gene_set: std.StringHashMap(void),
    p: f64,
) f64 {
    const N = ranked_list.len;
    var N_H: usize = 0;
    var N_R: f64 = 0.0;

    for (ranked_list) |gene| {
        if (gene_set.contains(gene.id)) {
            N_H += 1;
            N_R += std.math.pow(f64, @abs(gene.score), p);
        }
    }

    if (N_H == 0 or N_H == N) return 0.0;

    var max_es: f64 = 0.0;
    var min_es: f64 = 0.0;
    var running_sum: f64 = 0.0;
    const penalty = 1.0 / @as(f64, @floatFromInt(N - N_H));

    for (ranked_list) |gene| {
        if (gene_set.contains(gene.id)) {
            const hit_val = std.math.pow(f64, @abs(gene.score), p) / N_R;
            running_sum += hit_val;
        } else {
            running_sum -= penalty;
        }

        if (running_sum > max_es) max_es = running_sum;
        if (running_sum < min_es) min_es = running_sum;
    }

    if (@abs(max_es) > @abs(min_es)) {
        return max_es;
    } else {
        return min_es;
    }
}

/// Runs GSEA with permutation testing
pub fn performGsea(
    allocator: std.mem.Allocator,
    ranked_list: []const RankedGene,
    gene_set: std.StringHashMap(void),
    permutations: usize,
    p: f64,
    seed: u64,
) !GseaResult {
    const actual_es = calculateEnrichmentScore(ranked_list, gene_set, p);

    var prng = std.Random.Pcg.init(seed);
    const random = prng.random();

    var permuted_list = try allocator.alloc(RankedGene, ranked_list.len);
    defer allocator.free(permuted_list);
    @memcpy(permuted_list, ranked_list);

    var count_extreme: usize = 0;
    var valid_perms: usize = 0;

    var i: usize = 0;
    while (i < permutations) : (i += 1) {
        var j: usize = permuted_list.len - 1;
        while (j > 0) : (j -= 1) {
            const swap_idx = random.uintLessThan(usize, j + 1);
            const temp = permuted_list[j].score;
            permuted_list[j].score = permuted_list[swap_idx].score;
            permuted_list[swap_idx].score = temp;
        }

        const perm_es = calculateEnrichmentScore(permuted_list, gene_set, p);

        if (actual_es >= 0) {
            if (perm_es >= 0) {
                valid_perms += 1;
                if (perm_es >= actual_es) {
                    count_extreme += 1;
                }
            }
        } else {
            if (perm_es < 0) {
                valid_perms += 1;
                if (perm_es <= actual_es) {
                    count_extreme += 1;
                }
            }
        }
    }

    const p_value = if (valid_perms > 0)
        @as(f64, @floatFromInt(count_extreme)) / @as(f64, @floatFromInt(valid_perms))
    else
        1.0;

    return GseaResult{
        .enrichment_score = actual_es,
        .p_value = p_value,
    };
}

test "Hypergeometric distribution P-value" {
    // Probability of drawing k >= 5 successes from population N=100, where sample n=10 and total successes K=20
    const p_val = hypergeometricPValue(5, 20, 10, 100);
    try std.testing.expect(p_val > 0.0);
    try std.testing.expect(p_val < 0.05); // Should be a small p-value
}

test "GSEA calculate enrichment score" {
    const alloc = std.testing.allocator;
    var gene_set = std.StringHashMap(void).init(alloc);
    defer gene_set.deinit();

    try gene_set.put("g1", {});
    try gene_set.put("g2", {});
    try gene_set.put("g3", {});

    const ranked_list = [_]RankedGene{
        .{ .id = "g1", .score = 2.5 },
        .{ .id = "g2", .score = 2.0 },
        .{ .id = "g3", .score = 1.5 },
        .{ .id = "g4", .score = 0.5 },
        .{ .id = "g5", .score = 0.1 },
        .{ .id = "g6", .score = -0.1 },
        .{ .id = "g7", .score = -1.0 },
    };

    const es = calculateEnrichmentScore(&ranked_list, gene_set, 1.0);
    try std.testing.expect(es > 0.0);
    try std.testing.expect(es <= 1.0);
}

test "GSEA permute p-value" {
    const alloc = std.testing.allocator;
    var gene_set = std.StringHashMap(void).init(alloc);
    defer gene_set.deinit();

    try gene_set.put("g1", {});
    try gene_set.put("g2", {});
    try gene_set.put("g3", {});

    const ranked_list = [_]RankedGene{
        .{ .id = "g1", .score = 2.5 },
        .{ .id = "g2", .score = 2.0 },
        .{ .id = "g3", .score = 1.5 },
        .{ .id = "g4", .score = 0.5 },
        .{ .id = "g5", .score = 0.1 },
        .{ .id = "g6", .score = -0.1 },
        .{ .id = "g7", .score = -1.0 },
    };

    const res = try performGsea(alloc, &ranked_list, gene_set, 100, 1.0, 42);
    try std.testing.expect(res.enrichment_score > 0.0);
    try std.testing.expect(res.p_value >= 0.0);
    try std.testing.expect(res.p_value <= 1.0);
}
