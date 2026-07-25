const std = @import("std");
const profile = @import("profile.zig");
const alignment = @import("alignment.zig");
const srf = @import("core").scheduling.srf;
const topology = @import("../structural/topology.zig");
const metrics = @import("../analytics/metrics.zig");
const sparse = @import("analytics").matrix.sparse;

pub const Strategy = enum { None, LeaveOneOut, Targeted, ColumnAblation };

pub const RefinementEngine = struct {
    allocator: std.mem.Allocator,
    gap_open: i32,
    gap_extend: i32,
    sub_matrix: ?*const alignment.SubstitutionMatrix,
    memory_budget_bytes: usize,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        gap_open: i32,
        gap_extend: i32,
        sub_matrix: ?*const alignment.SubstitutionMatrix,
        memory_budget_bytes: usize,
    ) Self {
        return .{
            .allocator = allocator,
            .gap_open = gap_open,
            .gap_extend = gap_extend,
            .sub_matrix = sub_matrix,
            .memory_budget_bytes = memory_budget_bytes,
        };
    }

    pub fn refine(
        self: *Self,
        sequences: []const []const u8,
        raw_pd: []const sparse.PersistencePair,
        initial_msa: [][]const u8,
        max_iters: usize,
        epsilon: f64,
        strategy: Strategy,
    ) ![][]const u8 {
        var current_msa = try self.allocator.alloc([]const u8, initial_msa.len);
        for (0..initial_msa.len) |i| {
            current_msa[i] = try self.allocator.dupe(u8, initial_msa[i]);
        }

        var prev_w_dist: f64 = std.math.inf(f64);

        var iter: usize = 0;
        while (iter < max_iters) : (iter += 1) {
            const w_dist = try self.evaluateTopology(current_msa, raw_pd);
            const delta_w = @abs(w_dist - prev_w_dist);
            
            if (delta_w < epsilon) {
                break;
            }
            prev_w_dist = w_dist;

            if (strategy == .Targeted) {
                const TargetScore = struct { idx: usize, delta: f64 };
                var targets = try self.allocator.alloc(TargetScore, sequences.len);
                defer self.allocator.free(targets);
                
                for (0..sequences.len) |i| {
                    const w_without = try self.evaluateTopologyWithout(current_msa, i, raw_pd);
                    targets[i] = .{ .idx = i, .delta = w_dist - w_without };
                }
                
                std.mem.sort(TargetScore, targets, {}, struct {
                    fn lessThan(_: void, a: TargetScore, b: TargetScore) bool {
                        return a.delta > b.delta;
                    }
                }.lessThan);
                
                var refined_any = false;
                for (targets) |t| {
                    if (t.delta > 0) {
                        try self.realignSequence(&current_msa, sequences, t.idx);
                        refined_any = true;
                    }
                }
                
                if (!refined_any) {
                    try self.realignSequence(&current_msa, sequences, targets[0].idx);
                }
            } else if (strategy == .LeaveOneOut) {
                for (0..sequences.len) |i| {
                    try self.realignSequence(&current_msa, sequences, i);
                }
            }
        }

        return current_msa;
    }

    fn realignSequence(
        self: *Self,
        current_msa_ptr: *[][]const u8,
        sequences: []const []const u8,
        i: usize,
    ) !void {
        const current_msa = current_msa_ptr.*;
        
        var rest_msa = try self.allocator.alloc([]const u8, sequences.len - 1);
        defer self.allocator.free(rest_msa);
        var idx: usize = 0;
        for (0..sequences.len) |j| {
            if (i != j) {
                rest_msa[idx] = current_msa[j];
                idx += 1;
            }
        }

        var rest_profile = try profile.Profile.fromAlignment(self.allocator, rest_msa);
        defer rest_profile.deinit();

        var seq_i_array = [_][]const u8{sequences[i]};
        var single_profile = try profile.Profile.fromAlignment(self.allocator, &seq_i_array);
        defer single_profile.deinit();

        const prof_recurrence = alignment.ProfileRecurrence{
            .profile_a = &rest_profile,
            .profile_b = &single_profile,
            .gap_open = self.gap_open,
            .gap_extend = self.gap_extend,
            .sub_matrix = self.sub_matrix,
        };

        var prof_scheduler = srf.SRFScheduler(alignment.ProfileRecurrence).init(
            self.allocator,
            prof_recurrence,
            self.memory_budget_bytes,
        );

        var seq_a_idx = try self.allocator.alloc(usize, rest_profile.length);
        defer self.allocator.free(seq_a_idx);
        for (0..rest_profile.length) |k| seq_a_idx[k] = k;

        var seq_b_idx = try self.allocator.alloc(usize, single_profile.length);
        defer self.allocator.free(seq_b_idx);
        for (0..single_profile.length) |k| seq_b_idx[k] = k;

        const res = try prof_scheduler.execute([]const usize, seq_a_idx, seq_b_idx);
        defer self.allocator.free(res.align_a);
        defer self.allocator.free(res.align_b);

        var new_msa = try self.allocator.alloc([]const u8, sequences.len);
        
        for (0..rest_msa.len) |j| {
            const old_seq = rest_msa[j];
            var expanded = std.ArrayListUnmanaged(u8).empty;
            var old_idx: usize = 0;
            for (res.align_a) |char| {
                if (char == '-') {
                    try expanded.append(self.allocator, '-');
                } else {
                    if (old_idx < old_seq.len) {
                        try expanded.append(self.allocator, old_seq[old_idx]);
                        old_idx += 1;
                    } else {
                        try expanded.append(self.allocator, '-');
                    }
                }
            }
            new_msa[if (j >= i) j + 1 else j] = try expanded.toOwnedSlice(self.allocator);
        }

        var expanded_single = std.ArrayListUnmanaged(u8).empty;
        var old_idx: usize = 0;
        for (res.align_b) |char| {
            if (char == '-') {
                try expanded_single.append(self.allocator, '-');
            } else {
                if (old_idx < sequences[i].len) {
                    try expanded_single.append(self.allocator, sequences[i][old_idx]);
                    old_idx += 1;
                } else {
                    try expanded_single.append(self.allocator, '-');
                }
            }
        }
        new_msa[i] = try expanded_single.toOwnedSlice(self.allocator);

        for (current_msa) |s| self.allocator.free(s);
        self.allocator.free(current_msa);
        current_msa_ptr.* = new_msa;
    }

    fn evaluateTopologyWithout(self: *Self, msa: [][]const u8, skip_idx: usize, raw_pd: []const sparse.PersistencePair) !f64 {
        const max_seqs = @min(msa.len, @as(usize, 200));
        var n_sub = max_seqs;
        if (skip_idx < max_seqs) n_sub -= 1;
        
        if (n_sub < 2) return 0.0;
        
        var msa_dists = try self.allocator.alloc(f64, (n_sub * (n_sub - 1)) / 2);
        defer self.allocator.free(msa_dists);

        var idx: usize = 0;
        for (0..max_seqs) |i| {
            if (i == skip_idx) continue;
            for (i + 1..max_seqs) |j| {
                if (j == skip_idx) continue;
                const s1 = msa[i];
                const s2 = msa[j];
                var diffs: usize = 0;
                var valid: usize = 0;
                for (0..s1.len) |col| {
                    if (s1[col] != '-' or s2[col] != '-') {
                        valid += 1;
                        if (s1[col] != s2[col]) diffs += 1;
                    }
                }
                msa_dists[idx] = if (valid > 0) @as(f64, @floatFromInt(diffs)) / @as(f64, @floatFromInt(valid)) else 1.0;
                idx += 1;
            }
        }

        var max_dim: usize = 1;
        for (raw_pd) |p| {
            if (p.dimension == 1) max_dim = 2;
        }
        const knn_k = @min(n_sub, @as(usize, 15));
        const msa_pd = try topology.buildAndReduceRips(self.allocator, msa_dists, n_sub, 1.0, knn_k, max_dim);
        defer self.allocator.free(msa_pd);
        
        return try metrics.wassersteinDistance(self.allocator, raw_pd, msa_pd);
    }

    fn evaluateTopology(self: *Self, msa: [][]const u8, raw_pd: []const sparse.PersistencePair) !f64 {
        const n = @min(msa.len, @as(usize, 200));
        if (n < 2) return 0.0;
        
        var msa_dists = try self.allocator.alloc(f64, (n * (n - 1)) / 2);
        defer self.allocator.free(msa_dists);

        for (0..n) |i| {
            for (i + 1..n) |j| {
                const s1 = msa[i];
                const s2 = msa[j];
                var diffs: usize = 0;
                var valid: usize = 0;
                for (0..s1.len) |col| {
                    if (s1[col] != '-' or s2[col] != '-') {
                        valid += 1;
                        if (s1[col] != s2[col]) diffs += 1;
                    }
                }
                const dist = if (valid > 0) @as(f64, @floatFromInt(diffs)) / @as(f64, @floatFromInt(valid)) else 1.0;
                const min_idx = i;
                const max_idx = j;
                const flat_idx = n * min_idx - min_idx * (min_idx + 1) / 2 + max_idx - min_idx - 1;
                msa_dists[flat_idx] = dist;
            }
        }

        var max_dim: usize = 1;
        for (raw_pd) |p| {
            if (p.dimension == 1) max_dim = 2;
        }
        const knn_k = @min(n, @as(usize, 15));
        const msa_pd = try topology.buildAndReduceRips(self.allocator, msa_dists, n, 1.0, knn_k, max_dim);
        defer self.allocator.free(msa_pd);
        
        return try metrics.wassersteinDistance(self.allocator, raw_pd, msa_pd);
    }
    
    pub fn computeAblationGradient(self: *Self, msa: [][]const u8, raw_pd: []const sparse.PersistencePair, conserved_cols: ?[]const bool, landmarks: ?[]const usize) ![]f64 {
        if (msa.len < 2 or msa[0].len == 0) {
            const empty_len = if (msa.len > 0) msa[0].len else 0;
            return try self.allocator.alloc(f64, empty_len);
        }
        const L = msa[0].len;
        const n = msa.len;
        const effective_n = if (landmarks) |lm| lm.len else n;
        
        var scores = try self.allocator.alloc(f64, L);
        for (0..L) |c| scores[c] = 0.0;
        
        const num_pairs = (effective_n * (effective_n - 1)) / 2;
        var base_diffs = try self.allocator.alloc(usize, num_pairs);
        defer self.allocator.free(base_diffs);
        var base_valid = try self.allocator.alloc(usize, num_pairs);
        defer self.allocator.free(base_valid);
        
        var base_idx: usize = 0;
        for (0..effective_n) |i| {
            for (i + 1..effective_n) |j| {
                const real_i = if (landmarks) |lm| lm[i] else i;
                const real_j = if (landmarks) |lm| lm[j] else j;
                const s1 = msa[real_i];
                const s2 = msa[real_j];
                var diffs: usize = 0;
                var valid: usize = 0;
                for (0..L) |col| {
                    if (s1[col] != '-' or s2[col] != '-') {
                        valid += 1;
                        if (s1[col] != s2[col]) diffs += 1;
                    }
                }
                base_diffs[base_idx] = diffs;
                base_valid[base_idx] = valid;
                base_idx += 1;
            }
        }
        
        var msa_dists = try self.allocator.alloc(f64, num_pairs);
        defer self.allocator.free(msa_dists);
        for (0..num_pairs) |idx| {
            msa_dists[idx] = if (base_valid[idx] > 0) @as(f64, @floatFromInt(base_diffs[idx])) / @as(f64, @floatFromInt(base_valid[idx])) else 1.0;
        }
        
        var max_dim: usize = 1;
        for (raw_pd) |p| {
            if (p.dimension == 1) max_dim = 2;
        }
        const knn_k = @min(effective_n, @as(usize, 15));
        const base_pd = try topology.buildAndReduceRips(self.allocator, msa_dists, effective_n, 1.0, knn_k, max_dim);
        defer self.allocator.free(base_pd);
        const baseline = try metrics.wassersteinDistance(self.allocator, raw_pd, base_pd);
        
        const AblationTask = struct {
            allocator: std.mem.Allocator,
            msa: [][]const u8,
            raw_pd: []const sparse.PersistencePair,
            conserved_cols: ?[]const bool,
            base_diffs: []const usize,
            base_valid: []const usize,
            baseline: f64,
            scores: []f64,
            current_col: *std.atomic.Value(usize),
            n: usize,
            knn_k: usize,
            max_dim: usize,
            landmarks: ?[]const usize,
            
            fn worker(task: *@This()) void {
                const local_num_pairs = (task.n * (task.n - 1)) / 2;
                var local_dists = task.allocator.alloc(f64, local_num_pairs) catch unreachable;
                defer task.allocator.free(local_dists);
                
                while (true) {
                    const c = task.current_col.fetchAdd(1, .monotonic);
                    if (c >= task.msa[0].len) break;
                    
                    if (task.conserved_cols) |cols| {
                        if (!cols[c]) continue;
                    }
                    
                    var idx: usize = 0;
                    for (0..task.n) |i| {
                        for (i + 1..task.n) |j| {
                            var new_diffs = task.base_diffs[idx];
                            var new_valid = task.base_valid[idx];
                            
                            const real_i = if (task.landmarks) |lm| lm[i] else i;
                            const real_j = if (task.landmarks) |lm| lm[j] else j;

                            if (task.msa[real_i][c] != '-' or task.msa[real_j][c] != '-') {
                                new_valid -= 1;
                                if (task.msa[real_i][c] != task.msa[real_j][c]) new_diffs -= 1;
                            }
                            
                            local_dists[idx] = if (new_valid > 0) @as(f64, @floatFromInt(new_diffs)) / @as(f64, @floatFromInt(new_valid)) else 1.0;
                            idx += 1;
                        }
                    }
                    
                    const w_c_pd = topology.buildAndReduceRips(task.allocator, local_dists, task.n, 1.0, task.knn_k, task.max_dim) catch unreachable;
                    defer task.allocator.free(w_c_pd);
                    const w_c = metrics.wassersteinDistance(task.allocator, task.raw_pd, w_c_pd) catch unreachable;
                    
                    task.scores[c] = w_c - task.baseline;
                }
            }
        };

        var atomic_col = std.atomic.Value(usize).init(0);
        var task_data = AblationTask{
            .allocator = self.allocator,
            .msa = msa,
            .raw_pd = raw_pd,
            .conserved_cols = conserved_cols,
            .base_diffs = base_diffs,
            .base_valid = base_valid,
            .baseline = baseline,
            .scores = scores,
            .current_col = &atomic_col,
            .n = effective_n,
            .knn_k = knn_k,
            .max_dim = max_dim,
            .landmarks = landmarks,
        };

        const num_threads = std.Thread.getCpuCount() catch 4;
        var threads = try self.allocator.alloc(std.Thread, num_threads);
        defer self.allocator.free(threads);

        for (0..num_threads) |i| {
            threads[i] = try std.Thread.spawn(.{}, AblationTask.worker, .{&task_data});
        }
        for (threads) |t| {
            t.join();
        }
        
        return scores;
    }
};
