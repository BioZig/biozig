const std = @import("std");
const sparse = @import("analytics").matrix.sparse;

pub const Simplex = struct {
    vertices: [3]usize, // Max dimension 2 (0, 1, 2)
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
    // scipy.spatial.distance.pdist layout (strict upper triangle)
    const index = n * min - min * (min + 1) / 2 + max - min - 1;
    return dist_matrix[index];
}

pub fn enumerateSimplices(
    allocator: std.mem.Allocator,
    dist_matrix: []const f64,
    n_sequences: usize,
    max_distance: f64,
    knn_k: usize,
) ![]Simplex {

    var simplices = std.ArrayList(Simplex).empty;
    errdefer simplices.deinit(allocator);

    // 1. Max-Min Landmark Selection
    // We cap landmarks to a fixed size (e.g. 150) to guarantee fast O(L^3) processing.
    const L = if (n_sequences > 400) 400 else n_sequences;
    var landmarks = try allocator.alloc(usize, L);
    defer allocator.free(landmarks);

    // Array to keep track of the minimum distance from each point to the chosen landmarks
    var min_dist_to_L = try allocator.alloc(f64, n_sequences);
    defer allocator.free(min_dist_to_L);
    for (0..n_sequences) |i| min_dist_to_L[i] = std.math.inf(f64);

    // Pick the first landmark arbitrarily (index 0)
    landmarks[0] = 0;
    for (0..n_sequences) |i| {
        min_dist_to_L[i] = getDistance(dist_matrix, n_sequences, 0, i);
    }

    // Pick the remaining L-1 landmarks
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
        // Update minimum distances
        for (0..n_sequences) |i| {
            const d = getDistance(dist_matrix, n_sequences, farthest_idx, i);
            if (d < min_dist_to_L[i]) {
                min_dist_to_L[i] = d;
            }
        }
    }

    // 2. Build Witness-Rips Distance Matrix for Landmarks
    // D(l_1, l_2) = min_{w in W} max(d(w, l_1), d(w, l_2))
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

    // Precompute KNN distance thresholds for each landmark
    var knn_thresholds = try allocator.alloc(f64, L);
    defer allocator.free(knn_thresholds);
    var temp_row = try allocator.alloc(f64, L);
    defer allocator.free(temp_row);

    for (0..L) |i| {
        for (0..L) |j| {
            temp_row[j] = witness_dist[i * L + j];
        }
        std.mem.sort(f64, temp_row, {}, std.sort.asc(f64));
        // The nearest neighbor is itself (distance 0 at index 0).
        // So the k-th neighbor is at index k.
        const safe_k = @min(knn_k, L - 1);
        knn_thresholds[i] = temp_row[safe_k];
    }

    // 1-simplices
    for (0..L) |i| {
        for (i + 1..L) |j| {
            const d = witness_dist[i * L + j];
            if (d > max_distance) continue;

            // KNN constraint: Only connect if distance is <= knn_threshold for i or j
            if (d > knn_thresholds[i] and d > knn_thresholds[j]) continue;
            
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

    // 2-simplices
    for (0..L) |i| {
        for (i + 1..L) |j| {
            for (j + 1..L) |k| {
                const d_ij = witness_dist[i * L + j];
                const d_ik = witness_dist[i * L + k];
                const d_jk = witness_dist[j * L + k];
                
                const f_val = @max(d_ij, @max(d_ik, d_jk));
                if (f_val > max_distance) continue;
                
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

    // Sort globally
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
    
    // GF(2) deduplication logic
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

pub fn reduceColumn(
    allocator: std.mem.Allocator,
    col: []usize,
    pivot_map: *std.AutoHashMap(usize, []usize),
) ![]usize {
    var current = std.ArrayList(usize).empty;
    var next_current = std.ArrayList(usize).empty;
    defer next_current.deinit(allocator);
    // current will be toOwnedSlice'd at the end, so we only errdefer it
    errdefer current.deinit(allocator);
    
    try current.appendSlice(allocator, col);
    
    while (current.items.len > 0) {
        const pivot = current.items[current.items.len - 1]; // Sorted, so last is largest
        if (pivot_map.get(pivot)) |existing_col| {
            // XOR current with existing_col using merge sort
            next_current.clearRetainingCapacity();
            
            var i: usize = 0;
            var j: usize = 0;
            while (i < current.items.len and j < existing_col.len) {
                if (current.items[i] < existing_col[j]) {
                    try next_current.append(allocator, current.items[i]);
                    i += 1;
                } else if (current.items[i] > existing_col[j]) {
                    try next_current.append(allocator, existing_col[j]);
                    j += 1;
                } else {
                    i += 1;
                    j += 1;
                }
            }
            while (i < current.items.len) : (i += 1) try next_current.append(allocator, current.items[i]);
            while (j < existing_col.len) : (j += 1) try next_current.append(allocator, existing_col[j]);
            
            // Swap arrays to reuse capacity without allocations
            const temp = current;
            current = next_current;
            next_current = temp;
        } else {
            break;
        }
    }
    
    return try current.toOwnedSlice(allocator);
}

pub fn buildAndReduceRips(
    allocator: std.mem.Allocator,
    dist_matrix: []const f64,
    n_sequences: usize,
    max_distance: f64,
    knn_k: usize,
) ![]sparse.PersistencePair {
    var pairs = std.ArrayList(sparse.PersistencePair).empty;
    errdefer pairs.deinit(allocator); // We will return toOwnedSlice(allocator)

    // LOCAL ARENA: Cleans up ALL reduction matrices, hash maps, and arrays instantly!
    // We MUST use std.heap.page_allocator here, because 'allocator' might be a global arena 
    // which would silently ignore local_arena.deinit() and leak all memory anyway!
    var local_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer local_arena.deinit();
    const temp_allocator = local_arena.allocator();
    
    var pivot_map = std.AutoHashMap(usize, []usize).init(temp_allocator);
    
    const simplices = try enumerateSimplices(temp_allocator, dist_matrix, n_sequences, max_distance, knn_k);
    std.debug.print("Generated {d} simplices.\n", .{simplices.len});

    var edge_index = try temp_allocator.alloc(usize, n_sequences * n_sequences);
    @memset(edge_index, std.math.maxInt(usize));
    
    // First pass: store 1-simplices (edges) in the edge_index map
    for (simplices, 0..) |s, i| {
        if (s.dim == 1) {
            edge_index[s.vertices[0] * n_sequences + s.vertices[1]] = i;
            edge_index[s.vertices[1] * n_sequences + s.vertices[0]] = i; // symmetric
        }
    }

    for (simplices, 0..) |simplex, i| {
        var col = std.ArrayList(usize).empty;
        
        if (simplex.dim == 1) {
            // Find 0-simplices
            for (simplices, 0..) |k_simp, k| {
                if (k_simp.dim == 0) {
                    if (k_simp.vertices[0] == simplex.vertices[0] or 
                        k_simp.vertices[0] == simplex.vertices[1]) {
                        try col.append(temp_allocator, k);
                    }
                }
                if (k_simp.dim > 0) break; // Optimization: 0-simplices are first
            }
        } else if (simplex.dim == 2) {
            const e1 = edge_index[simplex.vertices[0] * n_sequences + simplex.vertices[1]];
            const e2 = edge_index[simplex.vertices[0] * n_sequences + simplex.vertices[2]];
            const e3 = edge_index[simplex.vertices[1] * n_sequences + simplex.vertices[2]];
            
            if (e1 != std.math.maxInt(usize)) try col.append(temp_allocator, e1);
            if (e2 != std.math.maxInt(usize)) try col.append(temp_allocator, e2);
            if (e3 != std.math.maxInt(usize)) try col.append(temp_allocator, e3);
            
            std.mem.sort(usize, col.items, {}, std.sort.asc(usize));
        }
        
        const reduced = try reduceColumn(temp_allocator, col.items, &pivot_map);
        
        if (reduced.len == 0) {
            // Birth without death (persistent feature)
            try pairs.append(allocator, .{
                .birth = i,
                .death = std.math.maxInt(usize),
                .dimension = simplex.dim,
                .birth_val = simplex.filtration_value,
                .death_val = std.math.inf(f64),
            });
        } else {
            // Death of a feature
            const pivot = reduced[reduced.len - 1];
            try pivot_map.put(pivot, reduced);
            
            const birth_simplex = simplices[pivot];
            try pairs.append(allocator, .{
                .birth = pivot,
                .death = i,
                .dimension = birth_simplex.dim,
                .birth_val = birth_simplex.filtration_value,
                .death_val = simplex.filtration_value,
            });
        }
    }
    
    return try pairs.toOwnedSlice(allocator);
}
