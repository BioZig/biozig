const std = @import("std");
const alignment = @import("alignment.zig");

pub const MSA = struct {
    allocator: std.mem.Allocator,
    sequences: [][]const u8,

    pub fn init(allocator: std.mem.Allocator, sequences: [][]const u8) MSA {
        return MSA{
            .allocator = allocator,
            .sequences = sequences,
        };
    }

    pub fn alignProgressive(self: *MSA, opts: anytype) ![][]const u8 {
        _ = opts;
        if (self.sequences.len == 0) return &[_][]const u8{};
        if (self.sequences.len == 1) {
            var res = try self.allocator.alloc([]const u8, 1);
            res[0] = try self.allocator.dupe(u8, self.sequences[0]);
            return res;
        }

        var aligned = std.ArrayList([]const u8).empty;
        try aligned.append(self.allocator, try self.allocator.dupe(u8, self.sequences[0]));

        for (self.sequences[1..]) |seq| {
            const len = aligned.items[0].len;
            var consensus = try self.allocator.alloc(u8, len);
            defer self.allocator.free(consensus);

            for (0..len) |i| {
                var counts = [_]usize{0} ** 256;
                for (aligned.items) |s| {
                    counts[s[i]] += 1;
                }
                var max_char: u8 = 'A';
                var max_count: usize = 0;
                for ("ACGT-") |c| {
                    if (counts[c] > max_count) {
                        max_count = counts[c];
                        max_char = c;
                    }
                }
                consensus[i] = max_char;
            }

            const rows = consensus.len + 1;
            const cols = seq.len + 1;
            var dp = try self.allocator.alloc(i32, rows * cols);
            defer self.allocator.free(dp);

            for (0..rows) |i| dp[i * cols + 0] = -@as(i32, @intCast(i));
            for (0..cols) |j| dp[0 * cols + j] = -@as(i32, @intCast(j));

            for (1..rows) |i| {
                for (1..cols) |j| {
                    const match = dp[(i - 1) * cols + (j - 1)] + if (consensus[i - 1] == seq[j - 1]) @as(i32, 1) else @as(i32, -1);
                    const delete = dp[(i - 1) * cols + j] - 1;
                    const insert = dp[i * cols + (j - 1)] - 1;
                    dp[i * cols + j] = @max(match, @max(delete, insert));
                }
            }

            var align_a = std.ArrayListUnmanaged(u8).empty;
            var align_b = std.ArrayListUnmanaged(u8).empty;
            defer align_a.deinit(self.allocator);
            defer align_b.deinit(self.allocator);

            var i: usize = consensus.len;
            var j: usize = seq.len;

            while (i > 0 or j > 0) {
                if (i > 0 and j > 0) {
                    const match_val = dp[(i - 1) * cols + (j - 1)] + if (consensus[i - 1] == seq[j - 1]) @as(i32, 1) else @as(i32, -1);
                    if (dp[i * cols + j] == match_val) {
                        try align_a.append(self.allocator, consensus[i - 1]);
                        try align_b.append(self.allocator, seq[j - 1]);
                        i -= 1;
                        j -= 1;
                        continue;
                    }
                }
                if (i > 0 and dp[i * cols + j] == dp[(i - 1) * cols + j] - 1) {
                    try align_a.append(self.allocator, consensus[i - 1]);
                    try align_b.append(self.allocator, '-');
                    i -= 1;
                    continue;
                }
                if (j > 0 and dp[i * cols + j] == dp[i * cols + (j - 1)] - 1) {
                    try align_a.append(self.allocator, '-');
                    try align_b.append(self.allocator, seq[j - 1]);
                    j -= 1;
                    continue;
                }
            }

            std.mem.reverse(u8, align_a.items);
            std.mem.reverse(u8, align_b.items);

            var new_aligned = std.ArrayList([]const u8).empty;
            for (aligned.items) |old_seq| {
                var expanded = std.ArrayListUnmanaged(u8).empty;
                var old_idx: usize = 0;
                for (align_a.items) |c| {
                    if (c == '-') {
                        try expanded.append(self.allocator, '-');
                    } else {
                        try expanded.append(self.allocator, old_seq[old_idx]);
                        old_idx += 1;
                    }
                }
                try new_aligned.append(self.allocator, try expanded.toOwnedSlice(self.allocator));
                self.allocator.free(old_seq);
            }
            try new_aligned.append(self.allocator, try align_b.toOwnedSlice(self.allocator));

            aligned.deinit(self.allocator);
            aligned = new_aligned;
        }

        return aligned.toOwnedSlice(self.allocator);
    }
};

test "MSA Progressive consensus algorithm test" {
    const alloc = std.testing.allocator;
    var seqs = [_][]const u8{ "ACGT", "ACCT", "ATGT" };
    var msa = MSA.init(alloc, &seqs);
    const res = try msa.alignProgressive(.{});
    defer {
        for (res) |s| alloc.free(s);
        alloc.free(res);
    }
    try std.testing.expectEqual(@as(usize, 3), res.len);
    try std.testing.expectEqualStrings("ACGT", res[0]);
    try std.testing.expectEqualStrings("ACCT", res[1]);
    try std.testing.expectEqualStrings("ATGT", res[2]);
}
