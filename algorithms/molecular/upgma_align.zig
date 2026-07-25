const std = @import("std");
const alignment = @import("alignment.zig");
const srf = @import("core").scheduling.srf;
const profile = @import("profile.zig");

pub const UPGMAClusterNode = struct {
    profile_data: profile.Profile,
    indices: std.ArrayListUnmanaged(usize),
    size: usize,
};

pub const MergeTask = struct {
    left: usize,
    right: usize,
    result_idx: usize,
    dist: f32,
};

pub fn alignProfilesUPGMA(
    allocator: std.mem.Allocator,
    cluster_profiles: *std.ArrayListUnmanaged(profile.Profile),
    gap_open: i32,
    gap_extend: i32,
    sub_matrix: ?*const alignment.SubstitutionMatrix,
    memory_budget_bytes: usize,
    raw_pd: ?[]const @import("analytics").matrix.sparse.PersistencePair,
    ref_engine_opt: ?*@import("refinement.zig").RefinementEngine,
) !profile.Profile {
    const n = cluster_profiles.items.len;
    if (n == 0) return error.EmptyClusters;
    if (n == 1) {
        const p = cluster_profiles.items[0];
        cluster_profiles.clearRetainingCapacity();
        return p;
    }

    var nodes = try allocator.alloc(?UPGMAClusterNode, n);
    
    var D = try allocator.alloc(f32, n * n);
    
    var global_seq_idx: usize = 0;
    var initial_indices = try allocator.alloc(std.ArrayListUnmanaged(usize), n);
    defer allocator.free(initial_indices);

    for (0..n) |i| {
        var inds = std.ArrayListUnmanaged(usize).empty;
        for (0..cluster_profiles.items[i].aligned_sequences.len) |_| {
            try inds.append(allocator, global_seq_idx);
            global_seq_idx += 1;
        }
        initial_indices[i] = inds;
        nodes[i] = UPGMAClusterNode{
            .profile_data = cluster_profiles.items[i],
            .indices = inds, 
            .size = cluster_profiles.items[i].aligned_sequences.len,
        };
        for (0..n) |j| {
            if (i == j) {
                D[i * n + j] = 0.0;
            } else {
                D[i * n + j] = 1.0;
            }
        }
    }
    
    var cluster_id = try allocator.alloc(usize, n);
    for (0..n) |i| cluster_id[i] = i;

    var tasks = try allocator.alloc(MergeTask, n - 1);
    defer allocator.free(tasks);
    
    var task_idx: usize = 0;
    var next_internal_id: usize = n;
    var active_count = n;

    // Phase 4a: Fast Topological Tree Construction (O(N^3) Math)
    while (active_count > 1) {
        var min_dist = std.math.inf(f32);
        var best_i: usize = 0;
        var best_j: usize = 0;
        
        for (0..n) |i| {
            if (nodes[i] == null) continue;
            for (i + 1..n) |j| {
                if (nodes[j] == null) continue;
                if (D[i * n + j] < min_dist) {
                    min_dist = D[i * n + j];
                    best_i = i;
                    best_j = j;
                }
            }
        }

        const id_i = cluster_id[best_i];
        const id_j = cluster_id[best_j];
        const id_new = next_internal_id;
        next_internal_id += 1;

        tasks[task_idx] = .{
            .left = id_i,
            .right = id_j,
            .result_idx = id_new,
            .dist = min_dist,
        };
        task_idx += 1;

        const old_size_i: f32 = @floatFromInt(nodes[best_i].?.size);
        const old_size_j: f32 = @floatFromInt(nodes[best_j].?.size);
        const new_size = nodes[best_i].?.size + nodes[best_j].?.size;
        
        nodes[best_i].?.size = new_size;
        cluster_id[best_i] = id_new;
        nodes[best_j] = null;

        for (0..n) |k| {
            if (k == best_i or nodes[k] == null) continue;
            const d_ik = D[best_i * n + k];
            const d_jk = D[best_j * n + k];
            const new_d = (old_size_i * d_ik + old_size_j * d_jk) / (old_size_i + old_size_j);
            D[best_i * n + k] = new_d;
            D[k * n + best_i] = new_d;
        }

        active_count -= 1;
    }

    // Explicitly free the O(N^2) Math constructs BEFORE spawning memory-intensive thread pools!
    allocator.free(D);
    allocator.free(nodes);
    allocator.free(cluster_id);

    // Phase 4b: Parallel Post-Order DAG Execution
    const TaskState = enum(u8) { Pending, Claimed, Completed };
    
    var states = try allocator.alloc(std.atomic.Value(u8), 2 * n - 1);
    defer allocator.free(states);
    for (0..n) |i| states[i] = std.atomic.Value(u8).init(@intFromEnum(TaskState.Completed));
    for (n..2 * n - 1) |i| states[i] = std.atomic.Value(u8).init(@intFromEnum(TaskState.Pending));

    var global_profiles = try allocator.alloc(?profile.Profile, 2 * n - 1);
    defer allocator.free(global_profiles);
    
    var global_indices = try allocator.alloc(?std.ArrayListUnmanaged(usize), 2 * n - 1);
    defer allocator.free(global_indices);

    for (0..2*n-1) |i| {
        global_profiles[i] = null;
        global_indices[i] = null;
    }
    
    for (0..n) |i| {
        global_profiles[i] = cluster_profiles.items[i];
        global_indices[i] = initial_indices[i];
    }
    
    const ThreadData = struct {
        allocator: std.mem.Allocator,
        tasks: []const MergeTask,
        states: []std.atomic.Value(u8),
        profiles: []?profile.Profile,
        indices: []?std.ArrayListUnmanaged(usize),
        gap_open: i32,
        gap_extend: i32,
        sub_matrix: ?*const alignment.SubstitutionMatrix,
        memory_budget_bytes: usize,
        raw_pd: ?[]const @import("analytics").matrix.sparse.PersistencePair,
        ref_engine_opt: ?*@import("refinement.zig").RefinementEngine,
        num_tasks_done: *std.atomic.Value(usize),
        total_tasks: usize,
        has_oom: *std.atomic.Value(bool),

        fn worker(data: *@This()) void {
            while (data.num_tasks_done.load(.seq_cst) < data.total_tasks) {
                if (data.has_oom.load(.seq_cst)) break;
                var did_work = false;
                for (data.tasks) |t| {
                    const l_state = data.states[t.left].load(.seq_cst);
                    const r_state = data.states[t.right].load(.seq_cst);
                    
                    if (l_state == @intFromEnum(TaskState.Completed) and r_state == @intFromEnum(TaskState.Completed)) {
                        const target_state = data.states[t.result_idx].load(.seq_cst);
                        if (target_state == @intFromEnum(TaskState.Pending)) {
                            // Atomic Claim
                            if (data.states[t.result_idx].cmpxchgStrong(@intFromEnum(TaskState.Pending), @intFromEnum(TaskState.Claimed), .seq_cst, .seq_cst)) |_| {
                                continue;
                            }
                            did_work = true;
                            
                            var p_left = &data.profiles[t.left].?;
                            var p_right = &data.profiles[t.right].?;
                            var i_left = &data.indices[t.left].?;
                            var i_right = &data.indices[t.right].?;

                            const divergence = if (t.dist > 1.0) 1.0 else t.dist;
                            const scale_factor: f32 = @floatCast(1.0 - (divergence * 0.5));

                            const prof_recurrence = alignment.ProfileRecurrence{
                                .profile_a = p_left,
                                .profile_b = p_right,
                                .gap_open = data.gap_open,
                                .gap_extend = data.gap_extend,
                                .sub_matrix = data.sub_matrix,
                                .divergence_scale = scale_factor,
                            };

                            var prof_scheduler = srf.SRFScheduler(alignment.ProfileRecurrence).init(
                                data.allocator, 
                                prof_recurrence, 
                                data.memory_budget_bytes
                            );

                            var seq_a_idx = data.allocator.alloc(usize, p_left.length) catch unreachable;
                            for (0..p_left.length) |i| seq_a_idx[i] = i;

                            var seq_b_idx = data.allocator.alloc(usize, p_right.length) catch unreachable;
                            for (0..p_right.length) |i| seq_b_idx[i] = i;

                            const res = prof_scheduler.execute([]const usize, seq_a_idx, seq_b_idx) catch |err| {
                                if (err == error.OutOfMemoryBudget) {
                                    data.has_oom.store(true, .seq_cst);
                                    data.allocator.free(seq_a_idx);
                                    data.allocator.free(seq_b_idx);
                                    break;
                                }
                                unreachable;
                            };
                            const new_cons = res.align_a;
                            const new_seq = res.align_b;
                            data.allocator.free(seq_a_idx);
                            data.allocator.free(seq_b_idx);

                            var final_aligned = std.ArrayListUnmanaged([]const u8).empty;
                            var new_inds = std.ArrayListUnmanaged(usize).empty;
                            
                            for (p_left.aligned_sequences, 0..) |old_seq, idx| {
                                var expanded = data.allocator.alloc(u8, new_cons.len) catch unreachable;
                                var old_idx: usize = 0;
                                for (new_cons, 0..) |char, col| {
                                    if (char == '-') {
                                        expanded[col] = '-';
                                    } else {
                                        if (old_idx < old_seq.len) {
                                            expanded[col] = old_seq[old_idx];
                                            old_idx += 1;
                                        } else {
                                            expanded[col] = '-';
                                        }
                                    }
                                }
                                final_aligned.append(data.allocator, expanded) catch unreachable;
                                new_inds.append(data.allocator, i_left.items[idx]) catch unreachable;
                            }

                            for (p_right.aligned_sequences, 0..) |old_seq, idx| {
                                var expanded = data.allocator.alloc(u8, new_seq.len) catch unreachable;
                                var old_idx: usize = 0;
                                for (new_seq, 0..) |char, col| {
                                    if (char == '-') {
                                        expanded[col] = '-';
                                    } else {
                                        if (old_idx < old_seq.len) {
                                            expanded[col] = old_seq[old_idx];
                                            old_idx += 1;
                                        } else {
                                            expanded[col] = '-';
                                        }
                                    }
                                }
                                final_aligned.append(data.allocator, expanded) catch unreachable;
                                new_inds.append(data.allocator, i_right.items[idx]) catch unreachable;
                            }

                            p_left.deinit();
                            p_right.deinit();
                            i_left.deinit(data.allocator);
                            i_right.deinit(data.allocator);
                            data.profiles[t.left] = null;
                            data.profiles[t.right] = null;
                            data.indices[t.left] = null;
                            data.indices[t.right] = null;
                            
                            data.allocator.free(new_cons);
                            data.allocator.free(new_seq);
                            
                            var final_merged_profile = profile.Profile.fromAlignment(data.allocator, final_aligned.items) catch unreachable;
                            for (final_aligned.items) |item| data.allocator.free(item);
                            final_aligned.deinit(data.allocator);

                            if (t.dist > 0.8) {
                                if (data.raw_pd) |pd| {
                                    if (data.ref_engine_opt) |engine| {
                                        var unaligned_seqs = data.allocator.alloc([]const u8, final_merged_profile.aligned_sequences.len) catch unreachable;
                                        var seq_ptrs = std.ArrayListUnmanaged([]const u8).empty;

                                        for (0..final_merged_profile.aligned_sequences.len) |k| {
                                            const s = final_merged_profile.aligned_sequences[k];
                                            var no_gaps = std.ArrayListUnmanaged(u8).empty;
                                            for (s) |char| {
                                                if (char != '-') no_gaps.append(data.allocator, char) catch unreachable;
                                            }
                                            const no_gaps_slice = no_gaps.toOwnedSlice(data.allocator) catch unreachable;
                                            seq_ptrs.append(data.allocator, no_gaps_slice) catch unreachable;
                                            unaligned_seqs[k] = no_gaps_slice;
                                        }
                                        
                                        const refined_msa = engine.refine(
                                            unaligned_seqs, 
                                            pd, 
                                            final_merged_profile.aligned_sequences, 
                                            5, 
                                            0.05, 
                                            .Targeted
                                        ) catch unreachable;
                                        
                                        final_merged_profile.deinit();
                                        final_merged_profile = profile.Profile.fromAlignment(data.allocator, refined_msa) catch unreachable;
                                        
                                        for (refined_msa) |s| data.allocator.free(s);
                                        data.allocator.free(refined_msa);
                                        for (seq_ptrs.items) |ptr| data.allocator.free(ptr);
                                        data.allocator.free(unaligned_seqs);
                                        seq_ptrs.deinit(data.allocator);
                                    }
                                }
                            }

                            data.profiles[t.result_idx] = final_merged_profile;
                            data.indices[t.result_idx] = new_inds;
                            data.states[t.result_idx].store(@intFromEnum(TaskState.Completed), .seq_cst);
                            
                            _ = data.num_tasks_done.fetchAdd(1, .seq_cst);
                        }
                    }
                }
                if (!did_work) {
                    std.atomic.spinLoopHint(); // emit PAUSE to prevent OS kernel context thrashing
                }
            }
        }
    };

    var tasks_done = std.atomic.Value(usize).init(0);
    var has_oom = std.atomic.Value(bool).init(false);
    var tdata = ThreadData{
        .allocator = allocator,
        .tasks = tasks,
        .states = states,
        .profiles = global_profiles,
        .indices = global_indices,
        .gap_open = gap_open,
        .gap_extend = gap_extend,
        .sub_matrix = sub_matrix,
        .memory_budget_bytes = memory_budget_bytes,
        .raw_pd = raw_pd,
        .ref_engine_opt = ref_engine_opt,
        .num_tasks_done = &tasks_done,
        .total_tasks = n - 1,
        .has_oom = &has_oom,
    };

    const sys_threads = std.Thread.getCpuCount() catch 4;
    const num_threads = if (sys_threads > 4) 4 else sys_threads;
    
    var threads = try allocator.alloc(std.Thread, num_threads);
    defer allocator.free(threads);

    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, ThreadData.worker, .{&tdata});
    }
    for (threads) |t| {
        t.join();
    }
    
    if (has_oom.load(.seq_cst)) {
        return error.OutOfMemoryBudget;
    }

    const root_idx = 2 * n - 2;
    var root_profile = global_profiles[root_idx].?;
    var root_indices = global_indices[root_idx].?;

    const total_seqs = root_indices.items.len;
    var sorted_seqs = try allocator.alloc([]const u8, total_seqs);
    defer allocator.free(sorted_seqs);
    for (0..total_seqs) |target_idx| {
        for (0..total_seqs) |j| {
            if (root_indices.items[j] == target_idx) {
                sorted_seqs[target_idx] = root_profile.aligned_sequences[j];
                break;
            }
        }
    }
    
    const final_profile = try profile.Profile.fromAlignment(allocator, sorted_seqs);
    root_profile.deinit();
    root_indices.deinit(allocator);
    
    cluster_profiles.clearRetainingCapacity();
    
    return final_profile;
}
