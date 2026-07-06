const std = @import("std");
const core = @import("core");
const numerics = core.numerics;

/// Computes log2(x + 1) for a slice of values (common for expression data).
pub fn log2p1(slice: []f64) void {
    for (slice) |*x| {
        x.* = std.math.log2(x.* + 1.0);
    }
}

/// Computes Counts Per Million (CPM).
pub fn cpm(counts: []f64) void {
    var total: f64 = 0.0;
    for (counts) |x| total += x;
    if (total == 0.0) return;
    const factor = 1e6 / total;
    for (counts) |*x| x.* *= factor;
}

/// Computes Transcripts Per Million (TPM).
/// tpm_i = (counts_i / length_i) / sum(counts_j / length_j) * 1e6
pub fn tpm(counts: []f64, lengths: []const f64) void {
    std.debug.assert(counts.len == lengths.len);
    var sum_rpk: f64 = 0.0;
    for (0..counts.len) |i| {
        const rpk = counts[i] / (lengths[i] / 1000.0);
        counts[i] = rpk;
        sum_rpk += rpk;
    }
    if (sum_rpk == 0.0) return;
    const factor = 1e6 / sum_rpk;
    for (counts) |*x| x.* *= factor;
}

/// Computes Reads Per Kilobase Million (RPKM).
/// rpkm_i = counts_i / (length_i/1000 * total_counts/1e6)
pub fn rpkm(counts: []f64, lengths: []const f64) void {
    std.debug.assert(counts.len == lengths.len);
    var total_counts: f64 = 0.0;
    for (counts) |x| total_counts += x;
    if (total_counts == 0.0) return;
    // rpkm = counts / (L_kb * N_million)
    const n_million = total_counts / 1e6;
    for (0..counts.len) |i| {
        const l_kb = lengths[i] / 1000.0;
        counts[i] /= (l_kb * n_million);
    }
}
