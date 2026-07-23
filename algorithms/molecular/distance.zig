const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;

pub fn hammingDistance(a: DNA2View, b: DNA2View) !usize {
    if (a.len != b.len) return error.LengthMismatch;

    var dist: usize = 0;

    if (a.start % 4 == 0 and b.start % 4 == 0) {
        const bytes_len = a.len / 4;
        const a_bytes = a.bytes[a.start / 4 .. (a.start / 4) + bytes_len];
        const b_bytes = b.bytes[b.start / 4 .. (b.start / 4) + bytes_len];

        var i: usize = 0;
        while (i + 8 <= a_bytes.len) : (i += 8) {
            const a_word = std.mem.readInt(u64, a_bytes[i .. i + 8][0..8], .little);
            const b_word = std.mem.readInt(u64, b_bytes[i .. i + 8][0..8], .little);
            const xor_word = a_word ^ b_word;
            const mismatch_bits = (xor_word | (xor_word >> 1)) & 0x5555555555555555;
            dist += @popCount(mismatch_bits);
        }

        for (a_bytes[i..], b_bytes[i..]) |byte_a, byte_b| {
            const xor_byte = byte_a ^ byte_b;
            const mismatch_bits = (xor_byte | (xor_byte >> 1)) & 0x55;
            dist += @popCount(@as(u8, @truncate(mismatch_bits)));
        }

        for (bytes_len * 4..a.len) |idx| {
            if (a.get(idx) != b.get(idx)) dist += 1;
        }
    } else {
        for (0..a.len) |idx| {
            if (a.get(idx) != b.get(idx)) dist += 1;
        }
    }

    return dist;
}

pub fn levenshteinDistance(allocator: std.mem.Allocator, a: DNA2View, b: DNA2View) !usize {
    const s1 = if (a.len <= b.len) a else b;
    const s2 = if (a.len <= b.len) b else a;

    if (s1.len == 0) return s2.len;

    var prev_row = try allocator.alloc(usize, s1.len + 1);
    defer allocator.free(prev_row);
    var curr_row = try allocator.alloc(usize, s1.len + 1);
    defer allocator.free(curr_row);

    for (prev_row, 0..) |*item, i| {
        item.* = i;
    }

    for (0..s2.len) |j| {
        curr_row[0] = j + 1;
        const char2 = s2.get(j);

        for (0..s1.len) |i| {
            const char1 = s1.get(i);
            const cost: usize = if (char1 == char2) 0 else 1;

            const del = prev_row[i + 1] + 1;
            const ins = curr_row[i] + 1;
            const sub = prev_row[i] + cost;

            curr_row[i + 1] = @min(@min(del, ins), sub);
        }

        const temp = prev_row;
        prev_row = curr_row;
        curr_row = temp;
    }

    return prev_row[s1.len];
}

test "Sequence Distance - Hamming" {
    const alloc = std.testing.allocator;
    var a = try dna_module.DNA2.init("GATTACA", alloc);
    defer a.deinit();
    var b = try dna_module.DNA2.init("GACTATA", alloc);
    defer b.deinit();

    try std.testing.expectEqual(@as(usize, 2), try hammingDistance(a.view(), b.view()));

    var short_a = try dna_module.DNA2.init("A", alloc);
    defer short_a.deinit();
    var short_b = try dna_module.DNA2.init("AA", alloc);
    defer short_b.deinit();

    try std.testing.expectError(error.LengthMismatch, hammingDistance(short_a.view(), short_b.view()));
}

test "Sequence Distance - Levenshtein" {
    const alloc = std.testing.allocator;

    var a1 = try dna_module.DNA2.init("GATTACA", alloc);
    defer a1.deinit();
    var b1 = try dna_module.DNA2.init("GATACCA", alloc);
    defer b1.deinit();
    try std.testing.expectEqual(@as(usize, 2), try levenshteinDistance(alloc, a1.view(), b1.view()));

    var a2 = try dna_module.DNA2.init("GCAT", alloc);
    defer a2.deinit();
    var b2 = try dna_module.DNA2.init("GCAT", alloc);
    defer b2.deinit();
    try std.testing.expectEqual(@as(usize, 0), try levenshteinDistance(alloc, a2.view(), b2.view()));

    var a3 = try dna_module.DNA2.init("", alloc);
    defer a3.deinit();
    var b3 = try dna_module.DNA2.init("ATCGG", alloc);
    defer b3.deinit();
    try std.testing.expectEqual(@as(usize, 5), try levenshteinDistance(alloc, a3.view(), b3.view()));
}
