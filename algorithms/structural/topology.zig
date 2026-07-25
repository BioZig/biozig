const std = @import("std");
const sparse = @import("analytics").matrix.sparse;

pub const Simplex = struct {
    vertices: [3]usize,
    dim: usize,
    filtration_value: f64,
    
    pub fn compare(_: void, a: Simplex, b: Simplex) bool {
        if (a.filtration_value != b.filtration_value) {
            return a.filtration_value < b.filtration_value;
        }
        return a.dim < b.dim;
    }
};

fn getDistance(dist_matrix: []const f64, n: usize, i: usize, j: usize) f64 {
    if (i == j) return 0.0;
    const min = @min(i, j);
    const max = @max(i, j);
    const index = n * min - min * (min + 1) / 2 + max - min - 1;
    return dist_matrix[index];
}

pub fn enumerateSimplices(
    allocator: std.mem.Allocator,
    dist_matrix: []const f64,
    n_sequences: usize,
    max_distance: f64,
    knn_k: usize,
    max_dim: usize,
) ![]Simplex {

    var simplices = std.ArrayList(Simplex).empty;
    errdefer simplices.deinit(allocator);

    const L = if (n_sequences > 400) 400 else n_sequences;
    var landmarks = try allocator.alloc(usize, L);
    defer allocator.free(landmarks);

    var min_dist_to_L = try allocator.alloc(f64, n_sequences);
    defer allocator.free(min_dist_to_L);
    for (0..n_sequences) |i| min_dist_to_L[i] = std.math.inf(f64);

    landmarks[0] = 0;
    for (0..n_sequences) |i| {
        min_dist_to_L[i] = getDistance(dist_matrix, n_sequences, 0, i);
    }

    for (1..L) |k| {
        var farthest_idx: usize = 0;
        var max_min_dist: f64 = -1.0;
        for (0..n_sequences) |i| {
            if (min_dist_to_L[i] > max_min_dist) {
                max_min_dist = min_dist_to_L[i];
                farthest_idx = i;
            }
        }
        landmarks[k] = farthest_idx;
        for (0..n_sequences) |i| {
            const d = getDistance(dist_matrix, n_sequences, farthest_idx, i);
            if (d < min_dist_to_L[i]) {
                min_dist_to_L[i] = d;
            }
        }
    }

    var witness_dist = try allocator.alloc(f64, L * L);
    defer allocator.free(witness_dist);
    @memset(witness_dist, std.math.inf(f64));

    for (0..L) |i| {
        witness_dist[i * L + i] = 0.0;
        for (i + 1..L) |j| {
            const l1 = landmarks[i];
            const l2 = landmarks[j];
            var best_w_dist: f64 = std.math.inf(f64);
            
            for (0..n_sequences) |w| {
                const d1 = getDistance(dist_matrix, n_sequences, w, l1);
                const d2 = getDistance(dist_matrix, n_sequences, w, l2);
                const max_d = @max(d1, d2);
                if (max_d < best_w_dist) {
                    best_w_dist = max_d;
                }
            }
            witness_dist[i * L + j] = best_w_dist;
            witness_dist[j * L + i] = best_w_dist;
        }
    }

    // 3. Generate Simplices on the Landmarks (0, 1, and 2-simplices)
    // 0-simplices
    for (0..L) |i| {
        try simplices.append(allocator, .{
            .vertices = [3]usize{ landmarks[i], 0, 0 },
            .dim = 0,
            .filtration_value = 0.0,
        });
    }

    var knn_thresholds = try allocator.alloc(f64, L);
    defer allocator.free(knn_thresholds);
    var temp_row = try allocator.alloc(f64, L);
    defer allocator.free(temp_row);

    for (0..L) |i| {
        for (0..L) |j| {
            const noise = @as(f64, @floatFromInt(j)) * 1e-9;
            temp_row[j] = witness_dist[i * L + j] + noise;
        }
        std.mem.sort(f64, temp_row, {}, std.sort.asc(f64));
        const safe_k = @min(knn_k, L - 1);
        knn_thresholds[i] = temp_row[safe_k];
    }

    for (0..L) |i| {
        for (i + 1..L) |j| {
            const d = witness_dist[i * L + j];
            if (d > max_distance) continue;

            const d_i = d + @as(f64, @floatFromInt(j)) * 1e-9;
            const d_j = d + @as(f64, @floatFromInt(i)) * 1e-9;

            if (d_i > knn_thresholds[i] and d_j > knn_thresholds[j]) continue;
            
            var v0 = landmarks[i];
            var v1 = landmarks[j];
            if (v0 > v1) { const tmp = v0; v0 = v1; v1 = tmp; }
            
            try simplices.append(allocator, .{
                .vertices = [3]usize{ v0, v1, 0 },
                .dim = 1,
                .filtration_value = d,
            });
        }
    }

    if (max_dim < 2) {
        std.mem.sort(Simplex, simplices.items, {}, Simplex.compare);
        return try simplices.toOwnedSlice(allocator);
    }

    for (0..L) |i| {
        for (i + 1..L) |j| {
            for (j + 1..L) |k| {
                const d_ij = witness_dist[i * L + j];
                const d_ik = witness_dist[i * L + k];
                const d_jk = witness_dist[j * L + k];
                
                const f_val = @max(d_ij, @max(d_ik, d_jk));
                if (f_val > max_distance) continue;

                const d_ij_i = d_ij + @as(f64, @floatFromInt(j)) * 1e-9;
                const d_ij_j = d_ij + @as(f64, @floatFromInt(i)) * 1e-9;
                if (d_ij_i > knn_thresholds[i] and d_ij_j > knn_thresholds[j]) continue;

                const d_ik_i = d_ik + @as(f64, @floatFromInt(k)) * 1e-9;
                const d_ik_k = d_ik + @as(f64, @floatFromInt(i)) * 1e-9;
                if (d_ik_i > knn_thresholds[i] and d_ik_k > knn_thresholds[k]) continue;

                const d_jk_j = d_jk + @as(f64, @floatFromInt(k)) * 1e-9;
                const d_jk_k = d_jk + @as(f64, @floatFromInt(j)) * 1e-9;
                if (d_jk_j > knn_thresholds[j] and d_jk_k > knn_thresholds[k]) continue;
                
                var arr = [3]usize{ landmarks[i], landmarks[j], landmarks[k] };
                std.mem.sort(usize, &arr, {}, std.sort.asc(usize));
                
                try simplices.append(allocator, .{
                    .vertices = [3]usize{ arr[0], arr[1], arr[2] },
                    .dim = 2,
                    .filtration_value = f_val,
                });
            }
        }
    }

    std.mem.sort(Simplex, simplices.items, {}, Simplex.compare);
    return try simplices.toOwnedSlice(allocator);
}

const SimplexKey = struct {
    dim: usize,
    v0: usize,
    v1: usize,
    v2: usize,
};

pub fn buildBoundaryColumn(
    allocator: std.mem.Allocator,
    simplex: Simplex,
    simplex_map: *const std.AutoHashMap(SimplexKey, usize),
) ![]usize {
    if (simplex.dim == 0) return &[_]usize{};
    
    var col = std.ArrayList(usize).empty;
    defer col.deinit(allocator);

    const num_faces = simplex.dim + 1;
    for (0..num_faces) |skip| {
        var face = [3]usize{ 0, 0, 0 };
        var idx: usize = 0;
        for (0..num_faces) |v| {
            if (v != skip) {
                face[idx] = simplex.vertices[v];
                idx += 1;
            }
        }
        
        const key = SimplexKey{ .dim = simplex.dim - 1, .v0 = face[0], .v1 = face[1], .v2 = face[2] };
        if (simplex_map.get(key)) |face_id| {
            try col.append(allocator, face_id);
        }
    }
    
    std.mem.sort(usize, col.items, {}, std.sort.asc(usize));
    var dedup = std.ArrayList(usize).empty;
    errdefer dedup.deinit(allocator);
    
    for (col.items) |i| {
        if (dedup.items.len == 0 or dedup.items[dedup.items.len - 1] != i) {
            try dedup.append(allocator, i);
        } else {
            _ = dedup.pop();
        }
    }
    
    return try dedup.toOwnedSlice(allocator);
}

pub fn buildAndReduceRips(
    allocator: std.mem.Allocator,
    dist_matrix: []const f64,
    n_sequences: usize,
    max_distance: f64,
    knn_k: usize,
    max_dim: usize,
) ![]sparse.PersistencePair {
    var pairs = std.ArrayList(sparse.PersistencePair).empty;
    errdefer pairs.deinit(allocator);

    var local_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer local_arena.deinit();
    const temp_allocator = local_arena.allocator();
    
    const simplices = try enumerateSimplices(temp_allocator, dist_matrix, n_sequences, max_distance, knn_k, max_dim);

    if (max_dim < 2) {
        var parent = try temp_allocator.alloc(usize, n_sequences);
        for (0..n_sequences) |i| parent[i] = i;
        
        const FindFn = struct {
            fn find(p: []usize, i: usize) usize {
                if (p[i] == i) return i;
                p[i] = find(p, p[i]);
                return p[i];
            }
        }.find;

        for (simplices, 0..) |simplex, i| {
            if (simplex.dim == 0) {
                try pairs.append(allocator, .{
                    .birth = i,
                    .death = std.math.maxInt(usize),
                    .dimension = 0,
                    .birth_val = simplex.filtration_value,
                    .death_val = std.math.inf(f64),
                });
            } else if (simplex.dim == 1) {
                const u = simplex.vertices[0];
                const v = simplex.vertices[1];
                const root_u = FindFn(parent, u);
                const root_v = FindFn(parent, v);
                
                if (root_u != root_v) {
                    const survivor = @min(root_u, root_v);
                    const killed = @max(root_u, root_v);
                    parent[killed] = survivor;
                    
                    for (pairs.items) |*pair| {
                        if (pair.birth == killed and pair.death == std.math.maxInt(usize)) {
                            pair.death = i;
                            pair.death_val = simplex.filtration_value;
                            break;
                        }
                    }
                }
            }
        }
        
        var final_pairs = std.ArrayList(sparse.PersistencePair).empty;
        for (pairs.items) |p| {
            if (p.birth_val != p.death_val) {
                try final_pairs.append(allocator, p);
            }
        }
        pairs.deinit(allocator);
        return try final_pairs.toOwnedSlice(allocator);
    }

    var pivot_map = std.AutoHashMap(usize, std.DynamicBitSetUnmanaged).init(temp_allocator);
    var edge_index = try temp_allocator.alloc(usize, n_sequences * n_sequences);
    @memset(edge_index, std.math.maxInt(usize));
    
    for (simplices, 0..) |s, i| {
        if (s.dim == 1) {
            edge_index[s.vertices[0] * n_sequences + s.vertices[1]] = i;
            edge_index[s.vertices[1] * n_sequences + s.vertices[0]] = i; 
        }
    }

    var working_col_indices = std.ArrayList(usize).empty;
    var working_bitset = try std.DynamicBitSetUnmanaged.initEmpty(temp_allocator, simplices.len);
    const masks_len = (simplices.len + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);

    for (simplices, 0..) |simplex, i| {
        working_col_indices.clearRetainingCapacity();
        
        if (simplex.dim == 1) {
            for (simplices, 0..) |k_simp, k| {
                if (k_simp.dim == 0) {
                    if (k_simp.vertices[0] == simplex.vertices[0] or 
                        k_simp.vertices[0] == simplex.vertices[1]) {
                        try working_col_indices.append(temp_allocator, k);
                    }
                }
                if (k_simp.dim > 0) break;
            }
        } else if (simplex.dim == 2) {
            const e1 = edge_index[simplex.vertices[0] * n_sequences + simplex.vertices[1]];
            const e2 = edge_index[simplex.vertices[0] * n_sequences + simplex.vertices[2]];
            const e3 = edge_index[simplex.vertices[1] * n_sequences + simplex.vertices[2]];
            
            if (e1 != std.math.maxInt(usize)) try working_col_indices.append(temp_allocator, e1);
            if (e2 != std.math.maxInt(usize)) try working_col_indices.append(temp_allocator, e2);
            if (e3 != std.math.maxInt(usize)) try working_col_indices.append(temp_allocator, e3);
            
            std.mem.sort(usize, working_col_indices.items, {}, std.sort.asc(usize));
        }
        
        working_bitset.setRangeValue(.{ .start = 0, .end = working_bitset.capacity() }, false);
        for (working_col_indices.items) |idx| working_bitset.set(idx);
        
        while (true) {
            if (working_bitset.findLastSet()) |pivot| {
                if (pivot_map.get(pivot)) |existing_col| {
                    var m_idx: usize = 0;
                    while (m_idx < masks_len) : (m_idx += 1) {
                        working_bitset.masks[m_idx] ^= existing_col.masks[m_idx];
                    }
                } else break;
            } else break;
        }
        
        if (working_bitset.findLastSet()) |pivot| {
            const reduced_copy = try working_bitset.clone(temp_allocator);
            try pivot_map.put(pivot, reduced_copy);
            
            const birth_simplex = simplices[pivot];
            if (birth_simplex.filtration_value != simplex.filtration_value) {
                try pairs.append(allocator, .{
                    .birth = pivot,
                    .death = i,
                    .dimension = birth_simplex.dim,
                    .birth_val = birth_simplex.filtration_value,
                    .death_val = simplex.filtration_value,
                });
            }
        } else {
            try pairs.append(allocator, .{
                .birth = i,
                .death = std.math.maxInt(usize),
                .dimension = simplex.dim,
                .birth_val = simplex.filtration_value,
                .death_val = std.math.inf(f64),
            });
        }
    }
    
    return try pairs.toOwnedSlice(allocator);
}
