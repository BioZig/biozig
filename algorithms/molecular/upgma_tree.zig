const std = @import("std");
const alignment = @import("alignment.zig");
const srf = @import("core").scheduling.srf;
const profile = @import("profile.zig");

pub const UPGMANode = struct {
    sequences: std.ArrayListUnmanaged([]const u8),
    indices: std.ArrayListUnmanaged(usize),
    consensus: []const u8,
    size: usize,
};

fn computeConsensus(allocator: std.mem.Allocator, sequences: [][]const u8) ![]const u8 {
    if (sequences.len == 0) return "";
    const length = sequences[0].len;
    var cons = try allocator.alloc(u8, length);
    
    var counts = [_]usize{0} ** 256;
    for (0..length) |col| {
        @memset(&counts, 0);
        for (sequences) |seq| {
            counts[seq[col]] += 1;
        }
        var max_count: usize = 0;
        var best_char: u8 = '-';
        for (0..256) |char_idx| {
            if (char_idx == '-') continue;
            if (counts[char_idx] > max_count) {
                max_count = counts[char_idx];
                best_char = @intCast(char_idx);
            }
        }
        if (max_count == 0) best_char = '-';
        cons[col] = best_char;
    }
    return cons;
}

pub fn alignClusterUPGMA(
    allocator: std.mem.Allocator,
    original_sequences: [][]const u8,
    cluster_indices: []const usize,
    dist_matrix: []const f64,
    num_total_sequences: usize,
    scheduler: anytype,
) !profile.Profile {
    var unique_indices = std.ArrayListUnmanaged(usize).empty;
    defer unique_indices.deinit(allocator);
    
    var identical_map = std.AutoHashMap(usize, std.ArrayListUnmanaged(usize)).init(allocator);
    defer {
        var it = identical_map.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        identical_map.deinit();
    }

    for (cluster_indices) |idx| {
        var found_duplicate = false;
        for (unique_indices.items) |uidx| {
            if (std.mem.eql(u8, original_sequences[idx], original_sequences[uidx])) {
                var entry = try identical_map.getOrPut(uidx);
                if (!entry.found_existing) {
                    entry.value_ptr.* = std.ArrayListUnmanaged(usize).empty;
                }
                try entry.value_ptr.append(allocator, idx);
                found_duplicate = true;
                break;
            }
        }
        if (!found_duplicate) {
            try unique_indices.append(allocator, idx);
        }
    }

    const n = unique_indices.items.len;
    var nodes = try allocator.alloc(?UPGMANode, n);
    defer {
        for (nodes) |*node_opt| {
            if (node_opt.*) |*node| {
                for (node.sequences.items) |s| allocator.free(s);
                node.sequences.deinit(allocator);
                node.indices.deinit(allocator);
                allocator.free(node.consensus);
            }
        }
        allocator.free(nodes);
    }
    
    var D = try allocator.alloc(f64, n * n);
    defer allocator.free(D);
    @memset(D, std.math.inf(f64));

    for (0..n) |i| {
        var seqs = std.ArrayListUnmanaged([]const u8).empty;
        try seqs.append(allocator, try allocator.dupe(u8, original_sequences[unique_indices.items[i]]));
        var inds = std.ArrayListUnmanaged(usize).empty;
        try inds.append(allocator, unique_indices.items[i]);
        nodes[i] = UPGMANode{
            .sequences = seqs,
            .indices = inds,
            .consensus = try allocator.dupe(u8, original_sequences[unique_indices.items[i]]),
            .size = 1,
        };
        
        for (0..i) |j| {
            const u_i = unique_indices.items[i];
            const u_j = unique_indices.items[j];
            const min_idx = @min(u_i, u_j);
            const max_idx = @max(u_i, u_j);
            const flat_idx = num_total_sequences * min_idx - min_idx * (min_idx + 1) / 2 + max_idx - min_idx - 1;
            const dist = dist_matrix[flat_idx];
            D[i * n + j] = dist;
            D[j * n + i] = dist;
        }
    }

    var active_count = n;
    while (active_count > 1) {
        var min_dist = std.math.inf(f64);
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
        var node_i = &nodes[best_i].?;
        var node_j = &nodes[best_j].?;
        
        const res = try scheduler.execute([]const u8, node_i.consensus, node_j.consensus);
        const aligned_cons_i = res.align_a;
        const aligned_cons_j = res.align_b;
        defer {
            allocator.free(aligned_cons_i);
            allocator.free(aligned_cons_j);
        }

        var new_seqs = std.ArrayListUnmanaged([]const u8).empty;
        var new_inds = std.ArrayListUnmanaged(usize).empty;
        
        for (node_i.sequences.items, 0..) |old_seq, idx| {
            var expanded = try allocator.alloc(u8, aligned_cons_i.len);
            var old_idx: usize = 0;
            for (aligned_cons_i, 0..) |char, col| {
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
            try new_seqs.append(allocator, expanded);
            try new_inds.append(allocator, node_i.indices.items[idx]);
            allocator.free(old_seq);
        }
        
        for (node_j.sequences.items, 0..) |old_seq, idx| {
            var expanded = try allocator.alloc(u8, aligned_cons_j.len);
            var old_idx: usize = 0;
            for (aligned_cons_j, 0..) |char, col| {
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
            try new_seqs.append(allocator, expanded);
            try new_inds.append(allocator, node_j.indices.items[idx]);
            allocator.free(old_seq);
        }

        const old_size_i: f64 = @floatFromInt(node_i.size);
        const old_size_j: f64 = @floatFromInt(node_j.size);
        const new_size = node_i.size + node_j.size;
        const new_consensus = try computeConsensus(allocator, new_seqs.items);
        
        node_i.sequences.deinit(allocator);
        node_j.sequences.deinit(allocator);
        node_i.indices.deinit(allocator);
        node_j.indices.deinit(allocator);
        allocator.free(node_i.consensus);
        allocator.free(node_j.consensus);

        nodes[best_i] = UPGMANode{
            .sequences = new_seqs,
            .indices = new_inds,
            .consensus = new_consensus,
            .size = new_size,
        };
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

    var final_node: *UPGMANode = undefined;
    for (0..n) |i| {
        if (nodes[i]) |*n_opt| {
            final_node = n_opt;
            break;
        }
    }

    var sorted_seqs = try allocator.alloc([]const u8, unique_indices.items.len);
    defer allocator.free(sorted_seqs);
    for (0..unique_indices.items.len) |i| {
        const target_uidx = unique_indices.items[i];
        for (0..final_node.indices.items.len) |j| {
            if (final_node.indices.items[j] == target_uidx) {
                sorted_seqs[i] = final_node.sequences.items[j];
                break;
            }
        }
    }

    var final_all_seqs = std.ArrayListUnmanaged([]const u8).empty;
    defer {
        for (final_all_seqs.items) |s| allocator.free(s);
        final_all_seqs.deinit(allocator);
    }
    
    for (0..unique_indices.items.len) |idx| {
        const uidx = unique_indices.items[idx];
        const seq_aligned = sorted_seqs[idx];
        
        try final_all_seqs.append(allocator, try allocator.dupe(u8, seq_aligned));
        
        if (identical_map.get(uidx)) |dups| {
            for (dups.items) |_| {
                try final_all_seqs.append(allocator, try allocator.dupe(u8, seq_aligned));
            }
        }
    }

    const p = try profile.Profile.fromAlignment(allocator, final_all_seqs.items);
    return p;
}
