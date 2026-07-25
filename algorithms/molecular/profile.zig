const std = @import("std");

pub const Profile = struct {
    allocator: std.mem.Allocator,
    length: usize,
    frequencies: []f32,
    aligned_sequences: [][]const u8,

    pub fn init(allocator: std.mem.Allocator, length: usize, num_seqs: usize) !Profile {
        const freqs = try allocator.alloc(f32, length * 24);
        @memset(freqs, 0.0);
        const aligned = try allocator.alloc([]const u8, num_seqs);
        return Profile{
            .allocator = allocator,
            .length = length,
            .frequencies = freqs,
            .aligned_sequences = aligned,
        };
    }

    pub fn deinit(self: *Profile) void {
        self.allocator.free(self.frequencies);
        for (self.aligned_sequences) |seq| {
            if (seq.len > 0) self.allocator.free(seq);
        }
        self.allocator.free(self.aligned_sequences);
    }

    pub fn getFreq(self: *const Profile, col: usize, c: u8) f32 {
        const idx = getCharIndex(c);
        if (idx >= 24) return 0.0;
        return self.frequencies[col * 24 + idx];
    }

    pub fn setFreq(self: *Profile, col: usize, c: u8, freq: f32) void {
        const idx = getCharIndex(c);
        if (idx < 24) {
            self.frequencies[col * 24 + idx] = freq;
        }
    }

    fn getCharIndex(c: u8) usize {
        if (c == '-') return 23;
        const upper = std.ascii.toUpper(c);
        if (upper >= 'A' and upper <= 'Z') {
            const offset = upper - 'A';
            if (offset < 23) return offset;
        }
        return 23;
    }

    pub fn fromAlignment(allocator: std.mem.Allocator, aligned_seqs: [][]const u8) !Profile {
        if (aligned_seqs.len == 0) return error.EmptyAlignment;
        const len = aligned_seqs[0].len;
        var profile = try Profile.init(allocator, len, aligned_seqs.len);
        errdefer profile.deinit();

        for (0..aligned_seqs.len) |i| {
            profile.aligned_sequences[i] = try allocator.dupe(u8, aligned_seqs[i]);
        }

        const inv_n = 1.0 / @as(f32, @floatFromInt(aligned_seqs.len));
        for (0..len) |col| {
            for (aligned_seqs) |seq| {
                const c = seq[col];
                const idx = getCharIndex(c);
                if (idx < 24) {
                    profile.frequencies[col * 24 + idx] += inv_n;
                }
            }
        }
        return profile;
    }
};
