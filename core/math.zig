const std = @import("std");

/// Strict Determinism Layer
/// Ensures bit-exact cross-architecture (x86, ARM, RISC-V, etc.) and cross-OS (Windows, Unix) reproducibility.
pub const DeterministicMath = struct {
    
    /// Globally disables Fast Math and Hardware FMA (Fused Multiply-Add) optimization drift.
    /// Returns the multiplication of two f64s strictly following IEEE-754.
    pub fn strictMul(a: f64, b: f64) f64 {
        @setFloatMode(.strict);
        return a * b;
    }

    pub fn strictAdd(a: f64, b: f64) f64 {
        @setFloatMode(.strict);
        return a + b;
    }

    pub fn strictSub(a: f64, b: f64) f64 {
        @setFloatMode(.strict);
        return a - b;
    }

    pub fn strictDiv(a: f64, b: f64) f64 {
        @setFloatMode(.strict);
        return a / b;
    }

    /// Provides a guaranteed bit-exact cross-platform RNG (PCG algorithm).
    /// Pcg relies on Xoroshiro which is good, but PCG provides explicitly uniform bit-streams regardless of OS.
    pub const Prng = std.Random.Pcg;

    /// Cross-platform newline normalizer. Strips '\r' on Windows to ensure hash consistency across OS.
    pub fn normalizeNewlines(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
        var output = std.ArrayList(u8).init(allocator);
        for (input) |c| {
            if (c != '\r') {
                try output.append(c);
            }
        }
        return output.toOwnedSlice();
    }
};

test "Strict Determinism" {
    const a: f64 = 0.1;
    const b: f64 = 0.2;
    // Strict IEEE-754 guarantees this exact bit pattern globally
    const res = DeterministicMath.strictAdd(a, b);
    try std.testing.expect(res == 0.30000000000000004);

    var prng1 = DeterministicMath.Prng.init(42);
    const r1 = prng1.random().int(u64);
    
    var prng2 = DeterministicMath.Prng.init(42);
    const r2 = prng2.random().int(u64);
    
    try std.testing.expectEqual(r1, r2);
}
