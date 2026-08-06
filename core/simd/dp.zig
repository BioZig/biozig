const std = @import("std");

/// Standard affine gap penalties.
pub const AffineGap = struct {
    open: i16,
    extend: i16,
};

/// Foundational hardware-intrinsic operations for dynamic programming.
/// Utilizes Zig's built-in @Vector for cross-platform SIMD compilation.
pub fn DPSimd(comptime lane_width: usize) type {
    return struct {
        pub const Vector = @Vector(lane_width, i16);
        pub const V_LANE_BYTES = lane_width * @sizeOf(i16);

        /// Core horizontal scoring primitive for Affine Gap DP.
        /// Processes `lane_width` cells simultaneously.
        /// Assumes the matching scores for the current sequence pair have been pre-computed 
        /// and loaded into `match_scores`.
        pub inline fn scoreBlock(
            match_scores: Vector,
            prev_m: Vector,
            prev_i: Vector,
            prev_d: Vector,
            gap: AffineGap,
        ) struct { m: Vector, i: Vector, d: Vector } {
            const gap_open: Vector = @splat(gap.open);
            const gap_extend: Vector = @splat(gap.extend);

            // Compute Insertion state
            // I[j] = max(M[j-1] + open, I[j-1] + extend)
            const m_to_i = prev_m + gap_open;
            const i_to_i = prev_i + gap_extend;
            const new_i = @select(i16, m_to_i > i_to_i, m_to_i, i_to_i);

            // Compute Deletion state
            // D[j] = max(M_up[j] + open, D_up[j] + extend)
            const m_to_d = prev_m + gap_open;
            const d_to_d = prev_d + gap_extend;
            const new_d = @select(i16, m_to_d > d_to_d, m_to_d, d_to_d);

            // Compute Match state
            // M[j] = max(M_diag[j] + match_score, I[j], D[j])
            const diag_m = prev_m + match_scores;
            const m_vs_i = @select(i16, diag_m > new_i, diag_m, new_i);
            const new_m = @select(i16, m_vs_i > new_d, m_vs_i, new_d);

            return .{ .m = new_m, .i = new_i, .d = new_d };
        }

        /// Broadcast a scalar initialization value into a packed vector.
        pub inline fn broadcast(val: i16) Vector {
            return @splat(val);
        }
    };
}
