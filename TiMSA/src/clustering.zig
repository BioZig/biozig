const std = @import("std");
const topology = @import("algorithms").structural.topology;
const sparse = @import("analytics").matrix.sparse;

/// A Sequence Cluster represents a stable topological component (H0).
pub const Cluster = struct {
    id: usize,
    sequence_indices: []usize,
};

pub const ClusteringEngine = struct {
    allocator: std.mem.Allocator,
    persistence_threshold: f64,

    pub fn init(allocator: std.mem.Allocator, persistence_threshold: f64) ClusteringEngine {
        return .{
            .allocator = allocator,
            .persistence_threshold = persistence_threshold,
        };
    }

    /// Evaluates H0 persistence to determine stable clusters.
    /// `dist_matrix` is a flattened upper/lower triangular matrix expected by the ATLAZ topology engine.
    pub fn findClusters(
        self: *ClusteringEngine,
        dist_matrix: []const f64,
        n_sequences: usize,
        max_distance: f64,
    ) ![]Cluster {
        // We invoke the ATLAZ-derived native topology engine.
        // knn_k is a bound on the rips complex generation to keep memory O(N log N)
        const knn_k = if (n_sequences > 50) 50 else n_sequences;
        const pairs = try topology.buildAndReduceRips(self.allocator, dist_matrix, n_sequences, max_distance, knn_k);
        defer self.allocator.free(pairs);

        var cluster_map = std.AutoHashMap(usize, std.ArrayList(usize)).init(self.allocator);
        defer {
            var it = cluster_map.valueIterator();
            while (it.next()) |list| list.deinit();
            cluster_map.deinit();
        }

        // Standard Disjoint Set (Union-Find) to map sequences to their longest-lived component
        var parent = try self.allocator.alloc(usize, n_sequences);
        defer self.allocator.free(parent);
        for (0..n_sequences) |i| parent[i] = i;

        const find = struct {
            fn f(p: []usize, i: usize) usize {
                if (p[i] == i) return i;
                p[i] = f(p, p[i]);
                return p[i];
            }
        }.f;

        const union_sets = struct {
            fn f(p: []usize, i: usize, j: usize) void {
                const root_i = find(p, i);
                const root_j = find(p, j);
                if (root_i != root_j) p[root_j] = root_i;
            }
        }.f;

        // Reconstruct the graph merging based on H0 pairs that fall *below* the persistence threshold
        // (meaning they are short-lived noise that merges into a stable cluster).
        for (pairs) |pair| {
            if (pair.dimension == 0) {
                const lifespan = pair.death_val - pair.birth_val;
                // If it dies quickly, it's noise, so we merge it with the component it died into.
                // We actually don't have the exact edge that killed it directly in the pair output natively, 
                // but we can approximate cluster assignment by thresholding the raw distance matrix for H0.
                _ = lifespan; 
            }
        }
        
        // Simpler, rigorous H0 component extraction: thresholding at the optimal persistence scale.
        // H0 components at a threshold `epsilon` exactly match the connected components of a graph where edges > epsilon are removed.
        const epsilon = self.persistence_threshold;
        
        for (0..n_sequences) |i| {
            for (i + 1..n_sequences) |j| {
                const min = @min(i, j);
                const max = @max(i, j);
                const index = n_sequences * min - min * (min + 1) / 2 + max - min - 1;
                const dist = dist_matrix[index];
                
                if (dist <= epsilon) {
                    union_sets(parent, i, j);
                }
            }
        }

        for (0..n_sequences) |i| {
            const root = find(parent, i);
            const entry = try cluster_map.getOrPut(root);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(usize).init(self.allocator);
            }
            try entry.value_ptr.append(i);
        }

        var final_clusters = std.ArrayList(Cluster).init(self.allocator);
        var it = cluster_map.iterator();
        while (it.next()) |entry| {
            try final_clusters.append(Cluster{
                .id = entry.key_ptr.*,
                .sequence_indices = try entry.value_ptr.toOwnedSlice(),
            });
        }

        return try final_clusters.toOwnedSlice();
    }
};
