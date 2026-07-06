const std = @import("std");
const math = std.math;

/// Natural log of the absolute value of the Gamma function.
pub fn lgamma(x: f64) f64 {
    return math.lgamma(f64, x);
}

/// Error function erf(x) approximation.
pub fn erf(x: f64) f64 {
    if (x < 0.0) return -erf(-x);
    // Abramowitz and Stegun approximation (maximum error: 1.5e-7)
    const p = 0.3275911;
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;

    const t = 1.0 / (1.0 + p * x);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x);
    return y;
}

/// Natural log of nCr.
pub fn lnNcr(n: usize, k: usize) f64 {
    if (k > n) return -math.inf(f64);
    const n_f = @as(f64, @floatFromInt(n));
    const k_f = @as(f64, @floatFromInt(k));
    return lgamma(n_f + 1.0) - lgamma(k_f + 1.0) - lgamma(n_f - k_f + 1.0);
}

pub fn nCr(n: usize, k: usize) f64 {
    return math.exp(lnNcr(n, k));
}

/// Regularized incomplete beta function I_x(a, b).
/// Uses the continued fraction method.
pub fn regularizedIncompleteBeta(x: f64, a: f64, b: f64) f64 {
    if (x < 0.0 or x > 1.0) return math.nan(f64);
    if (x == 0.0) return 0.0;
    if (x == 1.0) return 1.0;

    const bt = math.exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * math.log(f64, math.e, x) + b * math.log(f64, math.e, 1.0 - x));

    if (x < (a + 1.0) / (a + b + 2.0)) {
        return bt * betaCf(x, a, b) / a;
    } else {
        return 1.0 - bt * betaCf(1.0 - x, b, a) / b;
    }
}

/// Continued fraction for incomplete beta function.
fn betaCf(x: f64, a: f64, b: f64) f64 {
    const max_iter = 100;
    const eps = 1e-14;
    const tiny = 1e-30;

    const qab = a + b;
    const qap = a + 1.0;
    const qam = a - 1.0;
    var c: f64 = 1.0;
    var d: f64 = 1.0 - qab * x / qap;
    if (@abs(d) < tiny) d = tiny;
    d = 1.0 / d;
    var h = d;

    var m: usize = 1;
    while (m <= max_iter) : (m += 1) {
        const m_f = @as(f64, @floatFromInt(m));
        const m2 = 2.0 * m_f;
        
        // Even step
        var aa = m_f * (b - m_f) * x / ((qam + m2) * (a + m2));
        d = 1.0 + aa * d;
        if (@abs(d) < tiny) d = tiny;
        c = 1.0 + aa / c;
        if (@abs(c) < tiny) c = tiny;
        d = 1.0 / d;
        h *= d * c;

        // Odd step
        aa = -(a + m_f) * (qab + m_f) * x / ((a + m2) * (qap + m2));
        d = 1.0 + aa * d;
        if (@abs(d) < tiny) d = tiny;
        c = 1.0 + aa / c;
        if (@abs(c) < tiny) c = tiny;
        d = 1.0 / d;
        const delta = d * c;
        h *= delta;

        if (@abs(delta - 1.0) < eps) break;
    }

    return h;
}

/// Regularized incomplete gamma function P(a, x).
pub fn regularizedIncompleteGammaP(a: f64, x: f64) f64 {
    if (x < 0.0 or a <= 0.0) return 0.0;
    if (x < a + 1.0) {
        return seriesGammaP(a, x);
    } else {
        return 1.0 - continuedFractionGammaQ(a, x);
    }
}

fn seriesGammaP(a: f64, x: f64) f64 {
    const max_iter = 100;
    const eps = 1e-14;

    var sum = 1.0 / a;
    var term = sum;
    var i: usize = 1;
    while (i < max_iter) : (i += 1) {
        const i_f = @as(f64, @floatFromInt(i));
        term *= x / (a + i_f);
        sum += term;
        if (@abs(term) < @abs(sum) * eps) break;
    }
    return sum * math.exp(-x + a * math.log(f64, math.e, x) - lgamma(a));
}

fn continuedFractionGammaQ(a: f64, x: f64) f64 {
    const max_iter = 100;
    const eps = 1e-14;
    const tiny = 1e-30;

    var b = x + 1.0 - a;
    var c = 1.0 / tiny;
    var d = 1.0 / b;
    var h = d;

    var i: usize = 1;
    while (i <= max_iter) : (i += 1) {
        const i_f = @as(f64, @floatFromInt(i));
        const an = -i_f * (i_f - a);
        b += 2.0;
        d = an * d + b;
        if (@abs(d) < tiny) d = tiny;
        c = b + an / c;
        if (@abs(c) < tiny) c = tiny;
        d = 1.0 / d;
        const delta = d * c;
        h *= delta;
        if (@abs(delta - 1.0) < eps) break;
    }
    return h * math.exp(-x + a * math.log(f64, math.e, x) - lgamma(a));
}
