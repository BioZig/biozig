const std = @import("std");
const topology = @import("../structural/topology.zig");
const sparse = @import("analytics").matrix.sparse;

pub const Cluster = struct {
    sequence_indices: []usize,
};

pub const TopologicalClusters = struct {
    allocator: std.mem.Allocator,
    clusters: []Cluster,
    raw_pd: []sparse.PersistencePair,
    landmarks: []usize,

    pub fn deinit(self: *TopologicalClusters) void {
        for (self.clusters) |cluster| {
            self.allocator.free(cluster.sequence_indices);
        }
        self.allocator.free(self.clusters);
        self.allocator.free(self.raw_pd);
        self.allocator.free(self.landmarks);
    }
};

const UnionFind = struct {
    parent: []usize,
    size: []usize,

    pub fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(usize, n);
        const size = try allocator.alloc(usize, n);
        for (0..n) |i| {
            parent[i] = i;
            size[i] = 1;
        }
        return UnionFind{ .parent = parent, .size = size };
    }

    pub fn deinit(self: *UnionFind, allocator: std.mem.Allocator) void {
        allocator.free(self.parent);
        allocator.free(self.size);
    }

    pub fn find(self: *UnionFind, i: usize) usize {
        var root = i;
        while (root != self.parent[root]) {
            root = self.parent[root];
        }
        var curr = i;
        while (curr != root) {
            const next = self.parent[curr];
            self.parent[curr] = root;
            curr = next;
        }
        return root;
    }

    pub fn merge(self: *UnionFind, i: usize, j: usize) void {
        const root_i = self.find(i);
        const root_j = self.find(j);
        if (root_i != root_j) {
            if (self.size[root_i] < self.size[root_j]) {
                self.parent[root_i] = root_j;
                self.size[root_j] += self.size[root_i];
            } else {
                self.parent[root_j] = root_i;
                self.size[root_i] += self.size[root_j];
            }
        }
    }
};

pub fn computeClusters(
    allocator: std.mem.Allocator,
    dist_matrix: []const f64,
    n_sequences: usize,
    knn_k: usize,
    max_dim: usize,
) !TopologicalClusters {

    const MAX_LANDMARKS: usize = 500;
    const num_landmarks = if (n_sequences > MAX_LANDMARKS) MAX_LANDMARKS else n_sequences;

    var landmarks = try allocator.alloc(usize, num_landmarks);
    // Ownership of landmarks is transferred to TopologicalClusters
    
    var is_landmark = try allocator.alloc(bool, n_sequences);
    defer allocator.free(is_landmark);
    for (0..n_sequences) |i| is_landmark[i] = false;

    // 1. Select landmarks deterministically
    landmarks[0] = 0;
    is_landmark[0] = true;

    for (1..num_landmarks) |l_idx| {
        var max_min_dist: f64 = -1.0;
        var best_candidate: usize = 0;

        for (0..n_sequences) |i| {
            if (is_landmark[i]) continue;
            
            var min_dist_to_landmark: f64 = std.math.inf(f64);
            for (0..l_idx) |j| {
                const l_pos = landmarks[j];
                const u = if (i < l_pos) i else l_pos;
                const v = if (i < l_pos) l_pos else i;
                const idx = n_sequences * u - u * (u + 1) / 2 + v - u - 1;
                const d = dist_matrix[idx];
                if (d < min_dist_to_landmark) {
                    min_dist_to_landmark = d;
                }
            }

            if (min_dist_to_landmark > max_min_dist) {
                max_min_dist = min_dist_to_landmark;
                best_candidate = i;
            }
        }
        
        landmarks[l_idx] = best_candidate;
        is_landmark[best_candidate] = true;
    }

    // 2. Build subset distance matrix
    const num_lm_edges = num_landmarks * (num_landmarks - 1) / 2;
    var lm_dist_matrix = try allocator.alloc(f64, num_lm_edges);
    defer allocator.free(lm_dist_matrix);

    for (0..num_landmarks) |i| {
        for (i + 1..num_landmarks) |j| {
            const u = landmarks[i];
            const v = landmarks[j];
            const u_idx = if (u < v) u else v;
            const v_idx = if (u < v) v else u;
            const orig_idx = n_sequences * u_idx - u_idx * (u_idx + 1) / 2 + v_idx - u_idx - 1;
            
            const lm_idx = num_landmarks * i - i * (i + 1) / 2 + j - i - 1;
            lm_dist_matrix[lm_idx] = dist_matrix[orig_idx];
        }
    }

    // 3. Compute PH only on landmarks
    const pairs = try topology.buildAndReduceRips(allocator, lm_dist_matrix, num_landmarks, 1.0, knn_k, max_dim);
    // Ownership of pairs transferred to TopologicalClusters

    var h0_deaths = std.ArrayListUnmanaged(f64).empty;
    defer h0_deaths.deinit(allocator);

    for (pairs) |p| {
        if (p.dimension == 0 and p.death_val != std.math.inf(f64)) {
            try h0_deaths.append(allocator, p.death_val);
        }
    }

    std.mem.sort(f64, h0_deaths.items, {}, std.sort.asc(f64));

    var optimal_threshold: f64 = 0.5; // Default fallback
    if (h0_deaths.items.len > 1) {
        var max_gap: f64 = 0.0;
        var best_cut_idx: usize = 0;
        for (0..h0_deaths.items.len - 1) |i| {
            const gap = h0_deaths.items[i + 1] - h0_deaths.items[i];
            if (gap > max_gap) {
                max_gap = gap;
                best_cut_idx = i;
            }
        }
        optimal_threshold = h0_deaths.items[best_cut_idx] + (max_gap / 2.0);
    } else if (h0_deaths.items.len == 1) {
        optimal_threshold = h0_deaths.items[0] + 0.1; 
    }

    // 4. Group landmarks using UnionFind
    var uf = try UnionFind.init(allocator, num_landmarks);
    defer uf.deinit(allocator);

    for (0..num_landmarks) |i| {
        for (i + 1..num_landmarks) |j| {
            const idx = num_landmarks * i - i * (i + 1) / 2 + j - i - 1;
            if (lm_dist_matrix[idx] <= optimal_threshold) {
                uf.merge(i, j);
            }
        }
    }

    // 5. Build cluster map for landmarks
    var cluster_map = std.AutoHashMap(usize, std.ArrayListUnmanaged(usize)).init(allocator);
    defer {
        var it = cluster_map.valueIterator();
        while (it.next()) |list| {
            list.deinit(allocator);
        }
        cluster_map.deinit();
    }

    for (0..num_landmarks) |i| {
        const root = uf.find(i);
        var entry = try cluster_map.getOrPut(root);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayListUnmanaged(usize).empty;
        }
        try entry.value_ptr.append(allocator, landmarks[i]);
    }

    // 6. Project remaining non-landmarks
    for (0..n_sequences) |i| {
        if (is_landmark[i]) continue;
        
        var min_dist: f64 = std.math.inf(f64);
        var best_landmark_idx: usize = 0;
        
        for (0..num_landmarks) |j| {
            const l_pos = landmarks[j];
            const u = if (i < l_pos) i else l_pos;
            const v = if (i < l_pos) l_pos else i;
            const idx = n_sequences * u - u * (u + 1) / 2 + v - u - 1;
            const d = dist_matrix[idx];
            if (d < min_dist) {
                min_dist = d;
                best_landmark_idx = j;
            }
        }
        
        const root = uf.find(best_landmark_idx);
        var entry = cluster_map.getPtr(root).?;
        try entry.append(allocator, i);
    }

    var clusters = try allocator.alloc(Cluster, cluster_map.count());
    var c_idx: usize = 0;
    var it = cluster_map.valueIterator();
    while (it.next()) |list| {
        clusters[c_idx] = Cluster{
            .sequence_indices = try list.toOwnedSlice(allocator),
        };
        c_idx += 1;
    }

    return TopologicalClusters{
        .allocator = allocator,
        .clusters = clusters,
        .raw_pd = pairs,
        .landmarks = landmarks,
    };
}
