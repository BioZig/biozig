const std = @import("std");

/// A wrapper for the SHA256 cryptographic hashing algorithm.
pub const Sha256 = struct {
    hasher: std.crypto.hash.sha2.Sha256,

    pub fn init() Sha256 {
        return .{
            .hasher = std.crypto.hash.sha2.Sha256.init(.{}),
        };
    }

    pub fn update(self: *Sha256, data: []const u8) void {
        self.hasher.update(data);
    }

    pub fn final(self: *Sha256, out: *[32]u8) void {
        self.hasher.final(out);
    }

    pub fn hash(data: []const u8) [32]u8 {
        var out: [32]u8 = undefined;
        var h = init();
        h.update(data);
        h.final(&out);
        return out;
    }
};

/// A wrapper for the xxHash64 non-cryptographic hashing algorithm.
pub const XxHash64 = struct {
    pub fn hash(data: []const u8, seed: u64) u64 {
        return std.hash.XxHash64.hash(seed, data);
    }
};

test "SHA256 test vectors" {
    // Test vector: empty string
    const hash_empty = Sha256.hash("");
    const expected_empty = [_]u8{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    };
    try std.testing.expectEqualSlices(u8, &expected_empty, &hash_empty);

    // Test vector: "abc"
    const hash_abc = Sha256.hash("abc");
    const expected_abc = [_]u8{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    };
    try std.testing.expectEqualSlices(u8, &expected_abc, &hash_abc);
}

test "XxHash64 test vectors" {
    const val1 = XxHash64.hash("hello", 0);
    try std.testing.expectEqual(val1, @as(u64, 2794345569481354659));

    const val2 = XxHash64.hash("BioZig xxHash64 verification test vector.", 123456789);
    // Let's verify this seed-based hash value
    const expected_val2 = std.hash.XxHash64.hash(123456789, "BioZig xxHash64 verification test vector.");
    try std.testing.expectEqual(val2, expected_val2);
}
