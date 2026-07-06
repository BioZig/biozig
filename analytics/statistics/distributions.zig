const std = @import("std");
const math = std.math;

/// A random sampler with deterministic seeding.
pub const Sampler = struct {
    prng: std.Random.Pcg,

    pub fn init(seed: u64) Sampler {
        return .{
            .prng = std.Random.Pcg.init(seed),
        };
    }

    pub fn random(self: *Sampler) std.Random {
        return self.prng.random();
    }
};

pub const Normal = struct {
    mu: f64,
    sigma: f64,

    pub fn pdf(self: Normal, x: f64) f64 {
        const factor = 1.0 / (self.sigma * @sqrt(2.0 * math.pi));
        const exponent = -0.5 * math.pow(f64, (x - self.mu) / self.sigma, 2.0);
        return factor * math.exp(exponent);
    }

    pub fn cdf(self: Normal, x: f64) f64 {
        return 0.5 * (1.0 + @import("math_utils.zig").erf((x - self.mu) / (self.sigma * @sqrt(2.0))));
    }

    pub fn sample(self: Normal, sampler: *Sampler) f64 {
        return sampler.random().floatNorm(f64) * self.sigma + self.mu;
    }
};

pub const Uniform = struct {
    a: f64,
    b: f64,

    pub fn pdf(self: Uniform, x: f64) f64 {
        if (x < self.a or x > self.b) return 0.0;
        return 1.0 / (self.b - self.a);
    }

    pub fn cdf(self: Uniform, x: f64) f64 {
        if (x < self.a) return 0.0;
        if (x > self.b) return 1.0;
        return (x - self.a) / (self.b - self.a);
    }

    pub fn sample(self: Uniform, sampler: *Sampler) f64 {
        return sampler.random().float(f64) * (self.b - self.a) + self.a;
    }
};

pub const Poisson = struct {
    lambda: f64,

    pub fn pdf(self: Poisson, k: usize) f64 {
        const k_f = @as(f64, @floatFromInt(k));
        // Using logs for numerical stability: exp(k*log(lambda) - lambda - log(k!))
        return math.exp(k_f * math.log(f64, math.e, self.lambda) - self.lambda - @import("math_utils.zig").lgamma(k_f + 1.0));
    }

    pub fn cdf(self: Poisson, k: usize) f64 {
        var sum: f64 = 0.0;
        for (0..k + 1) |i| {
            sum += self.pdf(i);
        }
        return sum;
    }

    pub fn sample(self: Poisson, sampler: *Sampler) usize {
        // Knuth's algorithm
        const L = math.exp(-self.lambda);
        var k: usize = 0;
        var p: f64 = 1.0;
        while (p > L) {
            k += 1;
            p *= sampler.random().float(f64);
        }
        return k - 1;
    }
};

pub const Binomial = struct {
    n: usize,
    p: f64,

    pub fn pdf(self: Binomial, k: usize) f64 {
        if (k > self.n) return 0.0;
        const n_f = @as(f64, @floatFromInt(self.n));
        const k_f = @as(f64, @floatFromInt(k));
        
        // nCr using lnGamma
        const ln_ncr = @import("math_utils.zig").lgamma(n_f + 1.0) - @import("math_utils.zig").lgamma(k_f + 1.0) - @import("math_utils.zig").lgamma(n_f - k_f + 1.0);
        return math.exp(ln_ncr + k_f * math.log(f64, math.e, self.p) + (n_f - k_f) * math.log(f64, math.e, 1.0 - self.p));
    }

    pub fn cdf(self: Binomial, k: usize) f64 {
        var sum: f64 = 0.0;
        for (0..@min(k, self.n) + 1) |i| {
            sum += self.pdf(i);
        }
        return sum;
    }

    pub fn sample(self: Binomial, sampler: *Sampler) usize {
        var count: usize = 0;
        for (0..self.n) |_| {
            if (sampler.random().float(f64) < self.p) count += 1;
        }
        return count;
    }
};

pub const Hypergeometric = struct {
    N: usize, // Population size
    K: usize, // Number of success states in population
    n: usize, // Number of draws
    
    pub fn pdf(self: Hypergeometric, k: usize) f64 {
        if (k > self.K or k > self.n or (self.n - k) > (self.N - self.K)) return 0.0;
        
        const log_p = @import("math_utils.zig").lnNcr(self.K, k) + 
                     @import("math_utils.zig").lnNcr(self.N - self.K, self.n - k) - 
                     @import("math_utils.zig").lnNcr(self.N, self.n);
        return math.exp(log_p);
    }

    pub fn cdf(self: Hypergeometric, k: usize) f64 {
        var sum: f64 = 0.0;
        for (0..k + 1) |i| {
            sum += self.pdf(i);
        }
        return sum;
    }

    pub fn sample(self: Hypergeometric, sampler: *Sampler) usize {
        var population_remaining = self.N;
        var successes_remaining = self.K;
        var draws_remaining = self.n;
        var count: usize = 0;

        while (draws_remaining > 0) {
            const p = @as(f64, @floatFromInt(successes_remaining)) / @as(f64, @floatFromInt(population_remaining));
            if (sampler.random().float(f64) < p) {
                count += 1;
                successes_remaining -= 1;
            }
            population_remaining -= 1;
            draws_remaining -= 1;
        }
        return count;
    }
};

pub const NegativeBinomial = struct {
    r: f64, // Number of successes
    p: f64, // Probability of success

    pub fn pdf(self: NegativeBinomial, k: usize) f64 {
        const k_f = @as(f64, @floatFromInt(k));
        // PMF: (k+r-1 choose k) * (1-p)^k * p^r
        const ln_comb = @import("math_utils.zig").lgamma(k_f + self.r) - @import("math_utils.zig").lgamma(k_f + 1.0) - @import("math_utils.zig").lgamma(self.r);
        return math.exp(ln_comb + k_f * math.log(f64, math.e, 1.0 - self.p) + self.r * math.log(f64, math.e, self.p));
    }

    pub fn cdf(self: NegativeBinomial, k: usize) f64 {
        var sum: f64 = 0.0;
        for (0..k + 1) |i| {
            sum += self.pdf(i);
        }
        return sum;
    }

    pub fn sample(self: NegativeBinomial, sampler: *Sampler) usize {
        // One way to sample: Gamma-Poisson mixture
        // Not implemented fully here, let's use a simpler approach: sum of Geometrics
        var count: usize = 0;
        var successes: usize = 0;
        const target = @as(usize, @intFromFloat(@ceil(self.r)));
        while (successes < target) {
            if (sampler.random().float(f64) < self.p) {
                successes += 1;
            } else {
                count += 1;
            }
        }
        return count;
    }
};

test "normal distribution" {
    const norm = Normal{ .mu = 0.0, .sigma = 1.0 };
    try std.testing.expectApproxEqAbs(@as(f64, 0.3989422804014327), norm.pdf(0.0), 1e-7);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), norm.cdf(0.0), 1e-7);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8413447460685429), norm.cdf(1.0), 1e-7);
}

test "binomial distribution" {
    const binom = Binomial{ .n = 10, .p = 0.5 };
    // p(k=5) = 10C5 * 0.5^10 = 252 * 0.0009765625 = 0.24609375
    try std.testing.expectApproxEqAbs(@as(f64, 0.24609375), binom.pdf(5), 1e-10);
}

test "poisson distribution" {
    const poi = Poisson{ .lambda = 4.0 };
    // p(k=0) = exp(-4) = 0.01831563888
    try std.testing.expectApproxEqAbs(@as(f64, 0.01831563888), poi.pdf(0), 1e-10);
}

test "hypergeometric distribution" {
    const hg = Hypergeometric{ .N = 100, .K = 20, .n = 10 };
    // N=100, K=20, n=10, k=2
    // p = (20C2 * 80C8) / 100C10
    // 20C2 = 190
    // 80C8 = 28989675
    // 100C10 = 17310309456440
    // 190 * 28989675 / 17310309456440 = 0.3182
    try std.testing.expectApproxEqAbs(@as(f64, 0.318209), hg.pdf(2), 1e-4);
}
