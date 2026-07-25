const std = @import("std");
const alignment = @import("alignment.zig");
const srf = @import("core").scheduling.srf;
const graph = @import("graph.zig");
const cluster = @import("cluster.zig");
const profile = @import("profile.zig");
const refinement = @import("refinement.zig");
const topology = @import("../structural/topology.zig");
const metrics = @import("../analytics/metrics.zig");
const sparse = @import("analytics").matrix.sparse;

pub const TiMSAResult = struct {
    aligned_sequences: [][]const u8,
    consensus: []const u8,
    rigidity_scores: ?[]f64 = null,
    recomb_pairs: ?[]const sparse.PersistencePair = null,
};

pub const TiMSAMode = enum { Cluster, Align, Fast, Domain, Rigidity, Recomb, Consensus };

pub const RecurrenceType = enum { Global, Local, SemiGlobal, Profile };

pub const TiMSAConfig = struct {
    mode: TiMSAMode = .Align,
    require_h1: bool = false,
    use_minhash: bool = false,
    recurrence_type: RecurrenceType = .Global,
    refinement_strategy: refinement.Strategy = .Targeted,
    memory_budget_bytes: usize = 100 * 1024 * 1024,
    gap_open: i32 = -10,
    gap_extend: i32 = -2,
    match_score: i32 = 5,
    mismatch_score: i32 = -4,
};

pub const TiMSA = struct {
    allocator: std.mem.Allocator,
    config: TiMSAConfig,
    sub_matrix: ?*const alignment.SubstitutionMatrix = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: TiMSAConfig) Self {
        var active_config = config;
        if (active_config.mode == .Domain) {
            active_config.recurrence_type = .Local;
        }
        return .{
            .allocator = allocator,
            .config = active_config,
            .sub_matrix = null,
        };
    }

    pub fn executeAlignment(self: *Self, sequences: [][]const u8) !TiMSAResult {
        if (sequences.len == 0) return error.NoSequencesProvided;
        if (sequences.len == 1) {
            var aligned = try self.allocator.alloc([]const u8, 1);
            aligned[0] = try self.allocator.dupe(u8, sequences[0]);
            return TiMSAResult{
                .aligned_sequences = aligned,
                .consensus = try self.allocator.dupe(u8, sequences[0]),
            };
        }
        const k = if (sequences[0].len > 20) @as(usize, 6) else @as(usize, 3);
        var seq_graph = try graph.buildGraph(self.allocator, sequences, k);
        defer seq_graph.deinit();

        const knn_k = @min(sequences.len, @as(usize, 15));
        const max_dim: usize = if (self.config.require_h1 or self.config.mode == .Recomb) 2 else 1;
        var topo_clusters = try cluster.computeClusters(self.allocator, seq_graph.distances, sequences.len, knn_k, max_dim);
        defer topo_clusters.deinit();

        if (self.config.mode == .Cluster or self.config.mode == .Recomb) {
            var unaligned = try self.allocator.alloc([]const u8, sequences.len);
            for (0..sequences.len) |i| unaligned[i] = try self.allocator.dupe(u8, sequences[i]);
            
            var pairs: ?[]const sparse.PersistencePair = null;
            if (self.config.mode == .Recomb) {
                pairs = try self.allocator.dupe(sparse.PersistencePair, topo_clusters.raw_pd);
            }
            
            return TiMSAResult{
                .aligned_sequences = unaligned,
                .consensus = try self.allocator.dupe(u8, ""),
                .recomb_pairs = pairs,
            };
        }


        var cluster_profiles = std.ArrayListUnmanaged(profile.Profile).empty;
        defer {
            for (cluster_profiles.items) |*p| {
                if (p.frequencies.len > 0) p.deinit();
            }
            cluster_profiles.deinit(self.allocator);
        }

        const MAX_SUBCLUSTER_SIZE = if (self.config.mode == .Fast) @as(usize, 50) else @as(usize, 200);
        var chunks = std.ArrayListUnmanaged([]const usize).empty;
        defer chunks.deinit(self.allocator);
        for (topo_clusters.clusters) |c| {
            var i: usize = 0;
            while (i < c.sequence_indices.len) {
                const end = if (i + MAX_SUBCLUSTER_SIZE > c.sequence_indices.len) c.sequence_indices.len else i + MAX_SUBCLUSTER_SIZE;
                try chunks.append(self.allocator, c.sequence_indices[i..end]);
                i += MAX_SUBCLUSTER_SIZE;
            }
        }
        
        try cluster_profiles.ensureTotalCapacity(self.allocator, chunks.items.len);
        cluster_profiles.items.len = chunks.items.len;
        for (cluster_profiles.items) |*p| {
            p.frequencies = &[_]f32{}; // Default to len 0 to safely skip uninitialized deinit
        }

        const ThreadData = struct {
            allocator: std.mem.Allocator,
            chunks: [][]const usize,
            in_sequences: [][]const u8,
            distances: []const f64,
            config: TiMSAConfig,
            sub_matrix: ?*const alignment.SubstitutionMatrix,
            out_profiles: []profile.Profile,
            current_idx: *std.atomic.Value(usize),
            has_oom: *std.atomic.Value(bool),
            
            fn worker(task: *@This()) void {
                const upgma = @import("upgma_tree.zig");
                while (true) {
                    const idx = task.current_idx.fetchAdd(1, .monotonic);
                    if (idx >= task.chunks.len) break;
                    
                    const chunk = task.chunks[idx];
                    if (chunk.len == 1) {
                        var single_arr = [_][]const u8{ task.in_sequences[chunk[0]] };
                        const p = profile.Profile.fromAlignment(task.allocator, &single_arr) catch unreachable;
                        task.out_profiles[idx] = p;
                    } else {
                        if (task.config.recurrence_type == .Local) {
                            var max_score_val: i32 = 0;
                            var max_row_val: usize = 0;
                            var max_col_val: usize = 0;
                            
                            const sw_recurrence = alignment.SWRecurrence{
                                .match_score = task.config.match_score,
                                .mismatch_score = task.config.mismatch_score,
                                .gap_open = task.config.gap_open,
                                .gap_extend = task.config.gap_extend,
                                .sub_matrix = task.sub_matrix,
                                .max_score_ptr = &max_score_val,
                                .max_row_ptr = &max_row_val,
                                .max_col_ptr = &max_col_val,
                            };
                            var sched = srf.SRFScheduler(alignment.SWRecurrence).init(
                                task.allocator, 
                                sw_recurrence, 
                                task.config.memory_budget_bytes
                            );
                            const p = upgma.alignClusterUPGMA(
                                task.allocator,
                                task.in_sequences,
                                chunk,
                                task.distances,
                                task.in_sequences.len,
                                &sched,
                            ) catch |err| {
                                if (err == error.OutOfMemoryBudget) {
                                    task.has_oom.store(true, .seq_cst);
                                    break;
                                }
                                unreachable;
                            };
                            task.out_profiles[idx] = p;
                        } else {
                            const nw_recurrence = alignment.NWRecurrence{
                                .match_score = task.config.match_score,
                                .mismatch_score = task.config.mismatch_score,
                                .gap_open = task.config.gap_open,
                                .gap_extend = task.config.gap_extend,
                                .sub_matrix = task.sub_matrix,
                            };
                            var sched = srf.SRFScheduler(alignment.NWRecurrence).init(
                                task.allocator, 
                                nw_recurrence, 
                                task.config.memory_budget_bytes
                            );
                            const p = upgma.alignClusterUPGMA(
                                task.allocator,
                                task.in_sequences,
                                chunk,
                                task.distances,
                                task.in_sequences.len,
                                &sched,
                            ) catch |err| {
                                if (err == error.OutOfMemoryBudget) {
                                    task.has_oom.store(true, .seq_cst);
                                    break;
                                }
                                unreachable;
                            };
                            task.out_profiles[idx] = p;
                        }
                    }
                }
            }
        };

        var atomic_idx = std.atomic.Value(usize).init(0);
        var has_oom = std.atomic.Value(bool).init(false);
        var tdata = ThreadData{
            .allocator = self.allocator,
            .chunks = chunks.items,
            .in_sequences = sequences,
            .distances = seq_graph.distances,
            .config = self.config,
            .sub_matrix = self.sub_matrix,
            .out_profiles = cluster_profiles.items,
            .current_idx = &atomic_idx,
            .has_oom = &has_oom,
        };

        const num_threads = std.Thread.getCpuCount() catch 4;
        var threads = try self.allocator.alloc(std.Thread, num_threads);
        defer self.allocator.free(threads);

        for (0..num_threads) |i| {
            threads[i] = try std.Thread.spawn(.{}, ThreadData.worker, .{&tdata});
        }
        for (threads) |t| {
            t.join();
        }

        if (has_oom.load(.seq_cst)) {
            return error.OutOfMemoryBudget;
        }

        var ref_engine_opt: ?refinement.RefinementEngine = null;
        if (self.config.refinement_strategy != .None and self.config.mode != .Fast) {
            ref_engine_opt = refinement.RefinementEngine.init(
                self.allocator,
                self.config.gap_open,
                self.config.gap_extend,
                self.sub_matrix,
                self.config.memory_budget_bytes,
            );
        }

        const upgma_p4 = @import("upgma_align.zig");
        var final_master_profile = try upgma_p4.alignProfilesUPGMA(
            self.allocator,
            &cluster_profiles,
            self.config.gap_open,
            self.config.gap_extend,
            self.sub_matrix,
            self.config.memory_budget_bytes,
            if (self.config.refinement_strategy != .None and self.config.mode != .Fast) topo_clusters.raw_pd else null,
            if (self.config.refinement_strategy != .None and self.config.mode != .Fast) &ref_engine_opt.? else null,
        );
        defer final_master_profile.deinit();

        var valid_cols = std.ArrayListUnmanaged(usize).empty;
        defer valid_cols.deinit(self.allocator);
        
        const msa_len = final_master_profile.length;
        for (0..msa_len) |col| {
            var all_gaps = true;
            for (final_master_profile.aligned_sequences) |seq| {
                if (seq[col] != '-') {
                    all_gaps = false;
                    break;
                }
            }
            if (!all_gaps) try valid_cols.append(self.allocator, col);
        }

        var cleaned_aligned = try self.allocator.alloc([]const u8, final_master_profile.aligned_sequences.len);
        for (0..final_master_profile.aligned_sequences.len) |i| {
            var new_seq = try self.allocator.alloc(u8, valid_cols.items.len);
            for (valid_cols.items, 0..) |col, new_col| {
                new_seq[new_col] = final_master_profile.aligned_sequences[i][col];
            }
            cleaned_aligned[i] = new_seq;
        }

        var reordered_aligned = try self.allocator.alloc([]const u8, sequences.len);
        var global_idx: usize = 0;
        for (topo_clusters.clusters) |c| {
            for (c.sequence_indices) |original_idx| {
                reordered_aligned[original_idx] = cleaned_aligned[global_idx];
                global_idx += 1;
            }
        }
        
        self.allocator.free(cleaned_aligned);

        var final_output_msa: [][]const u8 = undefined;
        var rigidity_scores: ?[]f64 = null;

        if (self.config.mode == .Rigidity) {
            final_output_msa = reordered_aligned;
            var ref_engine = refinement.RefinementEngine.init(
                self.allocator,
                self.config.gap_open,
                self.config.gap_extend,
                self.sub_matrix,
                self.config.memory_budget_bytes,
            );
            
            var conserved_cols = try self.allocator.alloc(bool, reordered_aligned[0].len);
            defer self.allocator.free(conserved_cols);

            for (0..reordered_aligned[0].len) |col| {
                var counts = [_]usize{0} ** 256;
                var total: usize = 0;
                for (reordered_aligned) |seq| {
                    if (seq[col] != '-') {
                        counts[seq[col]] += 1;
                        total += 1;
                    }
                }
                
                var entropy: f64 = 0.0;
                if (total > 0) {
                    for (0..256) |char_idx| {
                        if (counts[char_idx] > 0) {
                            const p = @as(f64, @floatFromInt(counts[char_idx])) / @as(f64, @floatFromInt(total));
                            entropy -= p * @log2(p);
                        }
                    }
                } else {
                    entropy = std.math.inf(f64);
                }
                
                conserved_cols[col] = (entropy < 1.0); // Strict structural conservation
            }

            rigidity_scores = try ref_engine.computeAblationGradient(reordered_aligned, topo_clusters.raw_pd, conserved_cols, topo_clusters.landmarks);
        } else {
            final_output_msa = reordered_aligned;
        }

        var refined_profile = try profile.Profile.fromAlignment(self.allocator, final_output_msa);
        defer refined_profile.deinit();

        const final_cons = try getConsensusString(self.allocator, &refined_profile);

        var recomb_pairs: ?[]const sparse.PersistencePair = null;
        if (self.config.mode == .Recomb) {
            recomb_pairs = topo_clusters.raw_pd;
        }

        return TiMSAResult{
            .aligned_sequences = final_output_msa,
            .consensus = final_cons,
            .rigidity_scores = rigidity_scores,
            .recomb_pairs = recomb_pairs,
        };
    }

    fn getConsensusString(allocator: std.mem.Allocator, p: *const profile.Profile) ![]u8 {
        var cons = try allocator.alloc(u8, p.length);
        const map = "ABCDEFGHIJKLMNOPQRSTUVWXYZ-";
        for (0..p.length) |col| {
            var best_idx: usize = 23;
            var max_f: f32 = 0.0;
            for (0..24) |idx| {
                const f = p.frequencies[col * 24 + idx];
                if (f > max_f) {
                    max_f = f;
                    best_idx = idx;
                }
            }
            cons[col] = map[best_idx];
        }
        return cons;
    }
};
