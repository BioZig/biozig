const std = @import("std");
const core_math = @import("core").math;

pub const GibbsSampler = struct {
    allocator: std.mem.Allocator,
    sequences: [][]const u8,
    motif_len: usize,

    pub fn init(allocator: std.mem.Allocator, sequences: [][]const u8, motif_len: usize) GibbsSampler {
        return GibbsSampler{
            .allocator = allocator,
            .sequences = sequences,
            .motif_len = motif_len,
        };
    }

    pub fn sample(self: *GibbsSampler, iterations: usize) ![][]const u8 {
        var prng = core_math.DeterministicMath.Prng.init(42);
        const random = prng.random();

        var motifs = try self.allocator.alloc([]const u8, self.sequences.len);
        
        // Randomly select initial motifs
        for (self.sequences, 0..) |seq, i| {
            if (seq.len >= self.motif_len) {
                const start = random.uintLessThan(usize, seq.len - self.motif_len + 1);
                motifs[i] = seq[start .. start + self.motif_len];
            } else {
                motifs[i] = seq; // Should assert seq.len >= motif_len really
            }
        }

        var profile = try self.allocator.alloc([256]f64, self.motif_len);
        defer self.allocator.free(profile);

        // Run iterations
        for (0..iterations) |_| {
            const seq_idx = random.uintLessThan(usize, self.sequences.len);
            const seq = self.sequences[seq_idx];
            if (seq.len < self.motif_len) continue;

            // 1. Build profile from all other sequences (with pseudocounts)
            for (0..self.motif_len) |pos| {
                @memset(&profile[pos], 1.0); // Pseudocount of 1
            }

            for (motifs, 0..) |m, i| {
                if (i == seq_idx or m.len < self.motif_len) continue;
                for (0..self.motif_len) |pos| {
                    profile[pos][m[pos]] += 1.0;
                }
            }

            // Normalize profile
            const total_other = @as(f64, @floatFromInt(self.sequences.len - 1)) + 256.0;
            for (0..self.motif_len) |pos| {
                for (0..256) |char| {
                    profile[pos][char] /= total_other;
                }
            }

            // 2. Score all k-mers in sequences[seq_idx]
            const num_kmers = seq.len - self.motif_len + 1;
            var weights = try self.allocator.alloc(f64, num_kmers);
            defer self.allocator.free(weights);

            var total_weight: f64 = 0.0;
            for (0..num_kmers) |i| {
                var prob: f64 = 1.0;
                for (0..self.motif_len) |pos| {
                    prob *= profile[pos][seq[i + pos]];
                }
                weights[i] = prob;
                total_weight += prob;
            }

            // 3. Sample a new motif based on weights
            var new_start: usize = 0;
            if (total_weight > 0.0) {
                const r = random.float(f64) * total_weight;
                var cumulative: f64 = 0.0;
                for (0..num_kmers) |i| {
                    cumulative += weights[i];
                    if (cumulative >= r) {
                        new_start = i;
                        break;
                    }
                }
            } else {
                new_start = random.uintLessThan(usize, num_kmers);
            }

            motifs[seq_idx] = seq[new_start .. new_start + self.motif_len];
        }

        return motifs;
    }
};

test "Gibbs Sampler" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "ACGTACG", "ACCTACG", "ATGTACG" };
    var gibbs = GibbsSampler.init(alloc, &seqs, 4);
    const res = try gibbs.sample(10);
    defer alloc.free(res);
    try std.testing.expectEqual(@as(usize, 3), res.len);
}
