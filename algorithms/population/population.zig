const std = @import("std");

/// Linkage Disequilibrium Statistics
pub const LDStats = struct {
    d: f64,
    d_prime: f64,
    r_squared: f64,
};

/// Computes Linkage Disequilibrium (LD) statistics between two diallelic loci.
/// pA: frequency of allele A at locus 1
/// pB: frequency of allele B at locus 2
/// pAB: frequency of haplotype AB
pub fn computeLD(pA: f64, pB: f64, pAB: f64) LDStats {
    const pa = 1.0 - pA;
    const pb = 1.0 - pB;

    // D = pAB - pA * pB
    const d = pAB - (pA * pB);

    // D_max is dependent on the sign of D
    var d_max: f64 = 0.0;
    if (d > 0) {
        d_max = @min(pA * pb, pa * pB);
    } else {
        d_max = @max(-pA * pB, -pa * pb);
    }

    const d_prime = if (d_max != 0.0) d / d_max else 0.0;
    
    const r_sq_denom = pA * pa * pB * pb;
    const r_squared = if (r_sq_denom > 0.0) (d * d) / r_sq_denom else 0.0;

    return .{
        .d = d,
        .d_prime = @abs(d_prime),
        .r_squared = r_squared,
    };
}

/// Represents alleles across a population. 
/// rows = individuals, cols = loci
pub const PopulationMatrix = struct {
    matrix: []const []const u8, // 0 for ref, 1 for alt

    pub fn alleleFrequency(self: PopulationMatrix, locus: usize) f64 {
        if (self.matrix.len == 0) return 0.0;
        
        var alt_count: usize = 0;
        for (self.matrix) |ind| {
            if (ind[locus] == 1) alt_count += 1;
        }
        
        return @as(f64, @floatFromInt(alt_count)) / @as(f64, @floatFromInt(self.matrix.len));
    }

    /// Computes Tajima's D proxy: pairwise differences vs segregating sites.
    /// Pi = average number of pairwise differences.
    /// S = number of segregating sites.
    pub fn selectionSignal(self: PopulationMatrix) f64 {
        const n = self.matrix.len;
        if (n < 2) return 0.0;

        const num_loci = self.matrix[0].len;
        var S: usize = 0;

        // Count segregating sites (S)
        for (0..num_loci) |l| {
            var has_0 = false;
            var has_1 = false;
            for (0..n) |i| {
                if (self.matrix[i][l] == 0) has_0 = true;
                if (self.matrix[i][l] == 1) has_1 = true;
            }
            if (has_0 and has_1) S += 1;
        }

        // Pairwise differences (Pi)
        var sum_diffs: f64 = 0.0;
        for (0..n) |i| {
            for (i + 1..n) |j| {
                for (0..num_loci) |l| {
                    if (self.matrix[i][l] != self.matrix[j][l]) {
                        sum_diffs += 1.0;
                    }
                }
            }
        }
        
        const pairs = @as(f64, @floatFromInt(n * (n - 1) / 2));
        const Pi = sum_diffs / pairs;

        // Watterson's estimator denominator (a1)
        var a1: f64 = 0.0;
        for (1..n) |i| {
            a1 += 1.0 / @as(f64, @floatFromInt(i));
        }

        const theta = @as(f64, @floatFromInt(S)) / a1;
        
        // Return difference (simplified Tajima's D numerator without variance normalization)
        return Pi - theta;
    }
};

pub const EpiSummary = struct {
    incidence_rate: f64,
    prevalence: f64,
    case_fatality_ratio: f64,
};

/// Deterministic epidemiological summaries.
pub fn computeEpidemiologicalSummary(population_size: usize, new_cases: usize, total_cases: usize, deaths: usize) EpiSummary {
    const pop_f = @as(f64, @floatFromInt(population_size));
    const cases_f = @as(f64, @floatFromInt(total_cases));
    return .{
        .incidence_rate = if (pop_f > 0) @as(f64, @floatFromInt(new_cases)) / pop_f else 0.0,
        .prevalence = if (pop_f > 0) cases_f / pop_f else 0.0,
        .case_fatality_ratio = if (cases_f > 0) @as(f64, @floatFromInt(deaths)) / cases_f else 0.0,
    };
}

test "Population Algorithms - LD Statistics" {
    // A test case where A and B are perfectly correlated (pA = 0.5, pB = 0.5, pAB = 0.5)
    const ld1 = computeLD(0.5, 0.5, 0.5);
    try std.testing.expectEqual(@as(f64, 0.25), ld1.d);
    try std.testing.expectEqual(@as(f64, 1.0), ld1.d_prime);
    try std.testing.expectEqual(@as(f64, 1.0), ld1.r_squared);

    // Independent loci
    const ld2 = computeLD(0.5, 0.5, 0.25);
    try std.testing.expectEqual(@as(f64, 0.0), ld2.d);
    try std.testing.expectEqual(@as(f64, 0.0), ld2.r_squared);
}

test "Population Algorithms - Selection and Epi" {
    const p1 = [_]u8{ 0, 0, 1 };
    const p2 = [_]u8{ 0, 1, 1 };
    const p3 = [_]u8{ 1, 1, 1 };
    
    const mat = [_][]const u8{ &p1, &p2, &p3 };
    const pop = PopulationMatrix{ .matrix = &mat };

    try std.testing.expectEqual(@as(f64, 1.0), pop.alleleFrequency(2)); // Locus 2 is all 1s
    try std.testing.expectEqual(@as(f64, 2.0/3.0), pop.alleleFrequency(1));

    const epi = computeEpidemiologicalSummary(1000, 50, 200, 10);
    try std.testing.expectEqual(@as(f64, 0.05), epi.incidence_rate);
    try std.testing.expectEqual(@as(f64, 0.2), epi.prevalence);
    try std.testing.expectEqual(@as(f64, 0.05), epi.case_fatality_ratio);
}

/// Bitpacked representation of population haplotypes.
/// 1 bit per allele, locus-major order for fast frequency computation.
pub const BitpackedHaplotypes = struct {
    allocator: std.mem.Allocator,
    num_individuals: usize,
    num_loci: usize,
    data: []u64, // Locus-major: loci are rows, individuals are packed into bits of u64

    pub fn init(allocator: std.mem.Allocator, num_individuals: usize, num_loci: usize) !BitpackedHaplotypes {
        const words_per_locus = (num_individuals + 63) / 64;
        const total_words = num_loci * words_per_locus;
        const data = try allocator.alloc(u64, total_words);
        @memset(data, 0);
        return BitpackedHaplotypes{
            .allocator = allocator,
            .num_individuals = num_individuals,
            .num_loci = num_loci,
            .data = data,
        };
    }

    pub fn deinit(self: *BitpackedHaplotypes) void {
        self.allocator.free(self.data);
    }

    pub fn set(self: *BitpackedHaplotypes, locus: usize, ind: usize, val: u1) void {
        const words_per_locus = (self.num_individuals + 63) / 64;
        const word_idx = locus * words_per_locus + (ind / 64);
        const bit_idx = @as(u6, @intCast(ind % 64));
        if (val == 1) {
            self.data[word_idx] |= (@as(u64, 1) << bit_idx);
        } else {
            self.data[word_idx] &= ~(@as(u64, 1) << bit_idx);
        }
    }

    pub fn get(self: BitpackedHaplotypes, locus: usize, ind: usize) u1 {
        const words_per_locus = (self.num_individuals + 63) / 64;
        const word_idx = locus * words_per_locus + (ind / 64);
        const bit_idx = @as(u6, @intCast(ind % 64));
        return @as(u1, @intCast((self.data[word_idx] >> bit_idx) & 1));
    }
    
    pub fn alleleFrequency(self: BitpackedHaplotypes, locus: usize) f64 {
        if (self.num_individuals == 0) return 0.0;
        
        const words_per_locus = (self.num_individuals + 63) / 64;
        const start_idx = locus * words_per_locus;
        const end_idx = start_idx + words_per_locus;
        
        var alt_count: usize = 0;
        for (start_idx..end_idx) |i| {
            alt_count += @popCount(self.data[i]);
        }
        
        return @as(f64, @floatFromInt(alt_count)) / @as(f64, @floatFromInt(self.num_individuals));
    }
};

/// Bitpacked representation of population diploid genotypes.
/// 2 bits per allele, locus-major order.
pub const BitpackedGenotypes = struct {
    allocator: std.mem.Allocator,
    num_individuals: usize,
    num_loci: usize,
    data: []u64, // Locus-major: loci are rows, 32 individuals per u64 (2 bits each)

    pub fn init(allocator: std.mem.Allocator, num_individuals: usize, num_loci: usize) !BitpackedGenotypes {
        const words_per_locus = (num_individuals + 31) / 32;
        const total_words = num_loci * words_per_locus;
        const data = try allocator.alloc(u64, total_words);
        @memset(data, 0);
        return BitpackedGenotypes{
            .allocator = allocator,
            .num_individuals = num_individuals,
            .num_loci = num_loci,
            .data = data,
        };
    }

    pub fn deinit(self: *BitpackedGenotypes) void {
        self.allocator.free(self.data);
    }

    pub fn set(self: *BitpackedGenotypes, locus: usize, ind: usize, val: u2) void {
        const words_per_locus = (self.num_individuals + 31) / 32;
        const word_idx = locus * words_per_locus + (ind / 32);
        const shift = @as(u6, @intCast((ind % 32) * 2));
        
        self.data[word_idx] &= ~(@as(u64, 3) << shift);
        self.data[word_idx] |= (@as(u64, val) << shift);
    }

    pub fn get(self: BitpackedGenotypes, locus: usize, ind: usize) u2 {
        const words_per_locus = (self.num_individuals + 31) / 32;
        const word_idx = locus * words_per_locus + (ind / 32);
        const shift = @as(u6, @intCast((ind % 32) * 2));
        return @as(u2, @intCast((self.data[word_idx] >> shift) & 3));
    }
    
    pub fn alleleFrequencyAlt(self: BitpackedGenotypes, locus: usize) f64 {
        if (self.num_individuals == 0) return 0.0;
        
        const words_per_locus = (self.num_individuals + 31) / 32;
        const start_idx = locus * words_per_locus;
        const end_idx = start_idx + words_per_locus;
        
        var alt_allele_count: usize = 0;
        for (start_idx..end_idx) |i| {
            const word = self.data[i];
            const odd = word & 0x5555555555555555;
            const even = (word >> 1) & 0x5555555555555555;
            alt_allele_count += @popCount(odd) + @popCount(even) * 2;
        }
        
        return @as(f64, @floatFromInt(alt_allele_count)) / @as(f64, @floatFromInt(self.num_individuals * 2));
    }
};

test "BitpackedHaplotypes" {
    var hap = try BitpackedHaplotypes.init(std.testing.allocator, 100, 2);
    defer hap.deinit();
    
    hap.set(0, 0, 1);
    hap.set(0, 63, 1);
    hap.set(0, 64, 1);
    
    try std.testing.expectEqual(@as(u1, 1), hap.get(0, 0));
    try std.testing.expectEqual(@as(u1, 1), hap.get(0, 63));
    try std.testing.expectEqual(@as(u1, 1), hap.get(0, 64));
    try std.testing.expectEqual(@as(u1, 0), hap.get(0, 1));
    
    try std.testing.expectEqual(@as(f64, 0.03), hap.alleleFrequency(0));
    try std.testing.expectEqual(@as(f64, 0.0), hap.alleleFrequency(1));
}

test "BitpackedGenotypes" {
    var geno = try BitpackedGenotypes.init(std.testing.allocator, 100, 2);
    defer geno.deinit();
    
    geno.set(0, 0, 1); // 1 alt allele
    geno.set(0, 31, 2); // 2 alt alleles
    geno.set(0, 32, 2); // 2 alt alleles
    
    try std.testing.expectEqual(@as(u2, 1), geno.get(0, 0));
    try std.testing.expectEqual(@as(u2, 2), geno.get(0, 31));
    try std.testing.expectEqual(@as(u2, 2), geno.get(0, 32));
    try std.testing.expectEqual(@as(u2, 0), geno.get(0, 1));
    
    // Total alt alleles = 1 + 2 + 2 = 5
    // Total alleles = 100 * 2 = 200
    // Frequency = 5 / 200 = 0.025
    try std.testing.expectEqual(@as(f64, 0.025), geno.alleleFrequencyAlt(0));
    try std.testing.expectEqual(@as(f64, 0.0), geno.alleleFrequencyAlt(1));
}

pub const IbsSegment = struct {
    start_locus: usize,
    end_locus: usize,
    length: usize,
};

/// 3. Identity by Descent (IBD) / Identity by State Segment Detection
pub fn detectIbsSegments(
    geno: anytype, // Expected: BitpackedGenotypes
    ind_a: usize,
    ind_b: usize,
    min_length: usize,
    allocator: std.mem.Allocator
) ![]IbsSegment {
    var segments = std.ArrayList(IbsSegment).empty;
    errdefer segments.deinit(allocator);

    var current_start: ?usize = null;
    
    for (0..geno.num_loci) |locus| {
        const a = geno.get(locus, ind_a);
        const b = geno.get(locus, ind_b);
        
        const ibs_0 = (a == 0 and b == 2) or (a == 2 and b == 0);
        const match = !ibs_0;
        
        if (match) {
            if (current_start == null) current_start = locus;
        } else {
            if (current_start) |start| {
                const len = locus - start;
                if (len >= min_length) {
                    try segments.append(allocator, .{ .start_locus = start, .end_locus = locus, .length = len });
                }
                current_start = null;
            }
        }
    }
    
    if (current_start) |start| {
        const len = geno.num_loci - start;
        if (len >= min_length) {
            try segments.append(allocator, .{ .start_locus = start, .end_locus = geno.num_loci, .length = len });
        }
    }
    
    return try segments.toOwnedSlice(allocator);
}

/// 4. Li-Stephens Model (HMMs for Imputation)
pub fn liStephensViterbi(
    allocator: std.mem.Allocator,
    obs: []const u1,
    refs: anytype, // Expected: BitpackedHaplotypes
    recomb_rate: f64,
    mut_rate: f64,
) ![]usize {
    const num_loci = obs.len;
    const num_refs = refs.num_individuals;
    
    var dp = try allocator.alloc(f64, num_refs);
    defer allocator.free(dp);
    
    var new_dp = try allocator.alloc(f64, num_refs);
    defer allocator.free(new_dp);
    
    var ptrs = try allocator.alloc([]usize, num_loci);
    defer {
        for (ptrs) |p| allocator.free(p);
        allocator.free(ptrs);
    }
    
    const log_mut = @log(mut_rate);
    const log_no_mut = @log(1.0 - mut_rate);
    const log_recomb = @log(recomb_rate / @as(f64, @floatFromInt(num_refs)));
    const log_no_recomb = @log(1.0 - recomb_rate);
    
    for (0..num_refs) |r| {
        dp[r] = -@log(@as(f64, @floatFromInt(num_refs)));
        if (obs[0] == refs.get(0, r)) {
            dp[r] += log_no_mut;
        } else {
            dp[r] += log_mut;
        }
    }
    ptrs[0] = try allocator.alloc(usize, num_refs);
    @memset(ptrs[0], 0);
    
    for (1..num_loci) |l| {
        ptrs[l] = try allocator.alloc(usize, num_refs);
        
        var max_dp: f64 = -std.math.inf(f64);
        var max_r: usize = 0;
        for (dp, 0..) |v, r| {
            if (v > max_dp) {
                max_dp = v;
                max_r = r;
            }
        }
        
        for (0..num_refs) |r| {
            const no_recomb_val = dp[r] + log_no_recomb;
            const recomb_val = max_dp + log_recomb;
            
            if (no_recomb_val >= recomb_val) {
                new_dp[r] = no_recomb_val;
                ptrs[l][r] = r;
            } else {
                new_dp[r] = recomb_val;
                ptrs[l][r] = max_r;
            }
            
            if (obs[l] == refs.get(l, r)) {
                new_dp[r] += log_no_mut;
            } else {
                new_dp[r] += log_mut;
            }
        }
        
        @memcpy(dp, new_dp);
    }
    
    var best_path = try allocator.alloc(usize, num_loci);
    var max_dp: f64 = -std.math.inf(f64);
    var best_r: usize = 0;
    for (dp, 0..) |v, r| {
        if (v > max_dp) {
            max_dp = v;
            best_r = r;
        }
    }
    
    best_path[num_loci - 1] = best_r;
    var curr_r = best_r;
    var l: usize = num_loci - 1;
    while (l > 0) {
        curr_r = ptrs[l][curr_r];
        l -= 1;
        best_path[l] = curr_r;
    }
    
    return best_path;
}

/// 5. Admixture Proportions (Expectation-Maximization)
pub fn estimateAdmixtureEM(
    allocator: std.mem.Allocator,
    genotype: []const u2,
    pop_freqs: []const []const f64,
    max_iter: usize,
    tolerance: f64,
) ![]f64 {
    const K = pop_freqs.len;
    const L = genotype.len;
    
    var q = try allocator.alloc(f64, K);
    for (0..K) |k| q[k] = 1.0 / @as(f64, @floatFromInt(K));
    
    var new_q = try allocator.alloc(f64, K);
    defer allocator.free(new_q);
    
    for (0..max_iter) |_| {
        @memset(new_q, 0.0);
        
        for (0..L) |l| {
            const g = @as(f64, @floatFromInt(genotype[l]));
            if (g > 2.0) continue; // skip missing
            
            var denom_alt: f64 = 0.0;
            var denom_ref: f64 = 0.0;
            for (0..K) |k| {
                denom_alt += q[k] * pop_freqs[k][l];
                denom_ref += q[k] * (1.0 - pop_freqs[k][l]);
            }
            
            for (0..K) |k| {
                if (denom_alt > 0) {
                    new_q[k] += g * (q[k] * pop_freqs[k][l]) / denom_alt;
                }
                if (denom_ref > 0) {
                    new_q[k] += (2.0 - g) * (q[k] * (1.0 - pop_freqs[k][l])) / denom_ref;
                }
            }
        }
        
        var sum_q: f64 = 0.0;
        for (0..K) |k| {
            new_q[k] /= @as(f64, @floatFromInt(2 * L));
            sum_q += new_q[k];
        }
        
        var diff: f64 = 0.0;
        for (0..K) |k| {
            new_q[k] /= sum_q;
            diff += @abs(q[k] - new_q[k]);
            q[k] = new_q[k];
        }
        
        if (diff < tolerance) break;
    }
    
    return q;
}

/// 6. GWAS Linear Mixed Models
pub const GwasResult = struct {
    beta: f64,
    se: f64,
    chi2: f64,
};

pub fn gwasLmmWaldTest(x: []const f64, y: []const f64, v_inv: []const f64) GwasResult {
    const n = x.len;
    
    var xt_vinv_x: f64 = 0.0;
    var xt_vinv_y: f64 = 0.0;
    
    for (0..n) |i| {
        var vinv_x_i: f64 = 0.0;
        var vinv_y_i: f64 = 0.0;
        for (0..n) |j| {
            const v = v_inv[i * n + j];
            vinv_x_i += v * x[j];
            vinv_y_i += v * y[j];
        }
        xt_vinv_x += x[i] * vinv_x_i;
        xt_vinv_y += x[i] * vinv_y_i;
    }
    
    const var_beta = if (xt_vinv_x > 0.0) 1.0 / xt_vinv_x else 0.0;
    const beta = if (xt_vinv_x > 0.0) xt_vinv_y / xt_vinv_x else 0.0;
    const chi2 = if (var_beta > 0.0) (beta * beta) / var_beta else 0.0;
    
    return .{ .beta = beta, .se = @sqrt(var_beta), .chi2 = chi2 };
}

/// 1. Hardy-Weinberg Equilibrium (HWE) Exact Test
pub fn hweExactTest(obs_aa: usize, obs_ab: usize, obs_bb: usize) f64 {
    const n = obs_aa + obs_ab + obs_bb;
    const n_a = 2 * obs_aa + obs_ab;
    const n_b = 2 * obs_bb + obs_ab;

    const ln_2 = 0.6931471805599453;
    const ln_n_fact = lnFact(n);
    const ln_2n_fact = lnFact(2 * n);
    const ln_na_fact = lnFact(n_a);
    const ln_nb_fact = lnFact(n_b);
    
    const const_term = ln_n_fact - ln_2n_fact + ln_na_fact + ln_nb_fact;
    
    const calcLogProb = struct {
        fn call(aa: usize, ab: usize, bb: usize, c_term: f64, l2: f64) f64 {
            return c_term - lnFact(aa) - lnFact(ab) - lnFact(bb) + @as(f64, @floatFromInt(ab)) * l2;
        }
    }.call;

    const obs_log_prob = calcLogProb(obs_aa, obs_ab, obs_bb, const_term, ln_2);
    
    var p_value: f64 = 0.0;
    
    const min_ab = n_a % 2;
    const max_ab = @min(n_a, n_b);
    
    var ab = min_ab;
    while (ab <= max_ab) : (ab += 2) {
        const aa = (n_a - ab) / 2;
        const bb = (n_b - ab) / 2;
        
        const log_prob = calcLogProb(aa, ab, bb, const_term, ln_2);
        if (log_prob <= obs_log_prob + 1e-9) {
            p_value += @exp(log_prob);
        }
    }
    
    return @min(1.0, p_value);
}

fn lnFact(n: usize) f64 {
    if (n <= 1) return 0.0;
    if (n < 20) {
        var res: f64 = 0.0;
        for (2..n + 1) |i| res += @log(@as(f64, @floatFromInt(i)));
        return res;
    }
    const x = @as(f64, @floatFromInt(n));
    return x * @log(x) - x + 0.5 * @log(2.0 * std.math.pi * x) + 1.0 / (12.0 * x) - 1.0 / (360.0 * x * x * x);
}

/// 2. Wright's F-statistics
pub const FStats = struct {
    fis: f64,
    fst: f64,
    fit: f64,
};

pub fn computeFStatistics(subpop_allele_freqs: []const f64, subpop_obs_hets: []const f64, subpop_sizes: []const usize) FStats {
    var total_size: usize = 0;
    for (subpop_sizes) |s| total_size += s;
    const total_f = @as(f64, @floatFromInt(total_size));

    var ht: f64 = 0.0;
    var hs: f64 = 0.0;
    var ho: f64 = 0.0;
    
    var mean_p: f64 = 0.0;

    for (subpop_allele_freqs, subpop_obs_hets, subpop_sizes) |p, obs_het, s| {
        const weight = @as(f64, @floatFromInt(s)) / total_f;
        mean_p += p * weight;
        
        const exp_het = 2.0 * p * (1.0 - p);
        hs += exp_het * weight;
        ho += obs_het * weight;
    }
    
    ht = 2.0 * mean_p * (1.0 - mean_p);
    
    const fis = if (hs > 0) (hs - ho) / hs else 0.0;
    const fst = if (ht > 0) (ht - hs) / ht else 0.0;
    const fit = if (ht > 0) (ht - ho) / ht else 0.0;
    
    return .{ .fis = fis, .fst = fst, .fit = fit };
}

test "detectIbsSegments" {
    var geno = try BitpackedGenotypes.init(std.testing.allocator, 2, 10);
    defer geno.deinit();
    
    // Set some alleles
    for (0..10) |locus| {
        geno.set(locus, 0, 1);
        geno.set(locus, 1, 1);
    }
    // Locus 5 breaks IBS=1 match because ind 0 has 0, ind 1 has 2.
    geno.set(5, 0, 0);
    geno.set(5, 1, 2);
    
    const segments = try detectIbsSegments(geno, 0, 1, 2, std.testing.allocator);
    defer std.testing.allocator.free(segments);
    
    try std.testing.expectEqual(@as(usize, 2), segments.len);
    try std.testing.expectEqual(@as(usize, 0), segments[0].start_locus);
    try std.testing.expectEqual(@as(usize, 5), segments[0].end_locus);
    try std.testing.expectEqual(@as(usize, 5), segments[0].length);
    
    try std.testing.expectEqual(@as(usize, 6), segments[1].start_locus);
    try std.testing.expectEqual(@as(usize, 10), segments[1].end_locus);
    try std.testing.expectEqual(@as(usize, 4), segments[1].length);
}

test "hweExactTest" {
    const p = hweExactTest(15, 20, 5);
    try std.testing.expect(p >= 0.0 and p <= 1.0);
}

test "computeFStatistics" {
    const freqs = [_]f64{ 0.2, 0.4 };
    const hets = [_]f64{ 0.3, 0.4 };
    const sizes = [_]usize{ 100, 100 };
    const res = computeFStatistics(&freqs, &hets, &sizes);
    try std.testing.expect(res.fst >= 0.0);
}

test "liStephensViterbi" {
    var refs = try BitpackedHaplotypes.init(std.testing.allocator, 2, 5);
    defer refs.deinit();
    
    // ref 0: 0,0,0,0,0
    // ref 1: 1,1,1,1,1
    for (0..5) |l| {
        refs.set(l, 0, 0);
        refs.set(l, 1, 1);
    }
    
    const obs = [_]u1{0, 0, 1, 1, 1}; // switches from ref 0 to ref 1
    const path = try liStephensViterbi(std.testing.allocator, &obs, refs, 0.1, 0.01);
    defer std.testing.allocator.free(path);
    
    try std.testing.expectEqual(@as(usize, 5), path.len);
    try std.testing.expectEqual(@as(usize, 0), path[0]);
    try std.testing.expectEqual(@as(usize, 1), path[4]);
}

test "estimateAdmixtureEM" {
    const genotype = [_]u2{ 0, 1, 2, 2 }; // individual's genotype
    
    const pop1_freqs = [_]f64{ 0.1, 0.5, 0.9, 0.9 };
    const pop2_freqs = [_]f64{ 0.9, 0.5, 0.1, 0.1 };
    
    const pop_freqs = [_][]const f64{ &pop1_freqs, &pop2_freqs };
    
    const q = try estimateAdmixtureEM(std.testing.allocator, &genotype, &pop_freqs, 10, 1e-4);
    defer std.testing.allocator.free(q);
    
    // individual matches pop1 perfectly
    try std.testing.expect(q[0] > 0.9);
}

test "gwasLmmWaldTest" {
    const x = [_]f64{ 0.0, 1.0, 2.0 };
    const y = [_]f64{ 0.1, 1.2, 2.3 };
    const v_inv = [_]f64{
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    };
    
    const res = gwasLmmWaldTest(&x, &y, &v_inv);
    try std.testing.expect(res.beta > 0.0);
    try std.testing.expect(res.chi2 > 0.0);
}
