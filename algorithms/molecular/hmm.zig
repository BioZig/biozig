const std = @import("std");

pub const HMM = struct {
    allocator: std.mem.Allocator,
    num_states: usize,
    num_emissions: usize,

    initial_probs: []f64,
    transition_probs: [][]f64,
    emission_probs: [][]f64,

    pub fn init(allocator: std.mem.Allocator, num_states: usize, num_emissions: usize) !HMM {
        const initial_probs = try allocator.alloc(f64, num_states);
        @memset(initial_probs, 0);

        const transition_probs = try allocator.alloc([]f64, num_states);
        for (transition_probs) |*row| {
            row.* = try allocator.alloc(f64, num_states);
            @memset(row.*, 0);
        }

        const emission_probs = try allocator.alloc([]f64, num_states);
        for (emission_probs) |*row| {
            row.* = try allocator.alloc(f64, num_emissions);
            @memset(row.*, 0);
        }

        return HMM{
            .allocator = allocator,
            .num_states = num_states,
            .num_emissions = num_emissions,
            .initial_probs = initial_probs,
            .transition_probs = transition_probs,
            .emission_probs = emission_probs,
        };
    }

    pub fn deinit(self: *HMM) void {
        self.allocator.free(self.initial_probs);
        for (self.transition_probs) |row| self.allocator.free(row);
        self.allocator.free(self.transition_probs);
        for (self.emission_probs) |row| self.allocator.free(row);
        self.allocator.free(self.emission_probs);
    }

    pub fn viterbi(self: *const HMM, allocator: std.mem.Allocator, emissions: []const usize) ![]usize {
        const t_len = emissions.len;
        if (t_len == 0) return &[_]usize{};

        var v_path = try allocator.alloc([]f64, t_len);
        defer {
            for (v_path) |row| allocator.free(row);
            allocator.free(v_path);
        }
        var ptr = try allocator.alloc([]usize, t_len);
        defer {
            for (ptr) |row| allocator.free(row);
            allocator.free(ptr);
        }

        for (0..t_len) |t| {
            v_path[t] = try allocator.alloc(f64, self.num_states);
            ptr[t] = try allocator.alloc(usize, self.num_states);
        }

        for (0..self.num_states) |s| {
            v_path[0][s] = self.initial_probs[s] * self.emission_probs[s][emissions[0]];
            ptr[0][s] = 0;
        }

        for (1..t_len) |t| {
            for (0..self.num_states) |s| {
                var max_p: f64 = -1.0;
                var max_s: usize = 0;
                for (0..self.num_states) |s_prev| {
                    const p = v_path[t - 1][s_prev] * self.transition_probs[s_prev][s] * self.emission_probs[s][emissions[t]];
                    if (p > max_p) {
                        max_p = p;
                        max_s = s_prev;
                    }
                }
                v_path[t][s] = max_p;
                ptr[t][s] = max_s;
            }
        }

        var path = try allocator.alloc(usize, t_len);
        var max_p: f64 = -1.0;
        var max_s: usize = 0;
        for (0..self.num_states) |s| {
            if (v_path[t_len - 1][s] > max_p) {
                max_p = v_path[t_len - 1][s];
                max_s = s;
            }
        }

        path[t_len - 1] = max_s;
        var t = t_len - 1;
        while (t > 0) : (t -= 1) {
            path[t - 1] = ptr[t][path[t]];
        }

        return path;
    }
};

test "HMM Viterbi" {
    const alloc = std.testing.allocator;
    var hmm = try HMM.init(alloc, 2, 2);
    defer hmm.deinit();

    hmm.initial_probs[0] = 0.6;
    hmm.initial_probs[1] = 0.4;

    hmm.transition_probs[0][0] = 0.7;
    hmm.transition_probs[0][1] = 0.3;
    hmm.transition_probs[1][0] = 0.4;
    hmm.transition_probs[1][1] = 0.6;

    hmm.emission_probs[0][0] = 0.5;
    hmm.emission_probs[0][1] = 0.5;
    hmm.emission_probs[1][0] = 0.1;
    hmm.emission_probs[1][1] = 0.9;

    const emissions = [_]usize{ 0, 1, 1 };
    const path = try hmm.viterbi(alloc, &emissions);
    defer alloc.free(path);

    try std.testing.expectEqual(@as(usize, 3), path.len);
}
