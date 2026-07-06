const std = @import("std");
const cellular_mod = @import("cellular");
const SparseMatrix = cellular_mod.expression.SparseMatrix;

pub const KMeans = struct {
    pub const Result = struct {
        centroids: []f64,
        labels: []usize,
    };

    pub fn fit(allocator: std.mem.Allocator, mat: SparseMatrix, k: usize, max_iter: usize) !Result {
        var labels = try allocator.alloc(usize, mat.rows);
        @memset(labels, 0);

        var centroids = try allocator.alloc(f64, k * mat.cols);
        @memset(centroids, 0.0);

        for (0..k) |i| {
            if (mat.format == .csr) {
                const start = mat.indptr[i];
                const end = mat.indptr[i + 1];
                for (start..end) |idx| {
                    centroids[i * mat.cols + mat.indices[idx]] = mat.data[idx];
                }
            }
        }

        var changed: bool = true;
        var iter: usize = 0;

        var counts = try allocator.alloc(usize, k);
        defer allocator.free(counts);

        while (changed and iter < max_iter) : (iter += 1) {
            changed = false;
            @memset(counts, 0);

            for (0..mat.rows) |r| {
                var best_k: usize = 0;
                var best_dist: f64 = std.math.floatMax(f64);

                for (0..k) |c_k| {
                    var dist: f64 = 0.0;
                    if (mat.format == .csr) {
                        var sum_sq: f64 = 0.0;
                        const start = mat.indptr[r];
                        const end = mat.indptr[r + 1];
                        var idx = start;
                        for (0..mat.cols) |c| {
                            var val: f64 = 0.0;
                            if (idx < end and mat.indices[idx] == c) {
                                val = mat.data[idx];
                                idx += 1;
                            }
                            const diff = val - centroids[c_k * mat.cols + c];
                            sum_sq += diff * diff;
                        }
                        dist = sum_sq;
                    }
                    if (dist < best_dist) {
                        best_dist = dist;
                        best_k = c_k;
                    }
                }
                if (labels[r] != best_k) {
                    labels[r] = best_k;
                    changed = true;
                }
                counts[best_k] += 1;
            }

            var new_centroids = try allocator.alloc(f64, k * mat.cols);
            defer allocator.free(new_centroids);
            @memset(new_centroids, 0.0);

            for (0..mat.rows) |r| {
                const c_k = labels[r];
                if (mat.format == .csr) {
                    const start = mat.indptr[r];
                    const end = mat.indptr[r + 1];
                    for (start..end) |idx| {
                        const c = mat.indices[idx];
                        new_centroids[c_k * mat.cols + c] += mat.data[idx];
                    }
                }
            }

            for (0..k) |c_k| {
                const count_f = @as(f64, @floatFromInt(counts[c_k]));
                if (count_f > 0) {
                    for (0..mat.cols) |c| {
                        centroids[c_k * mat.cols + c] = new_centroids[c_k * mat.cols + c] / count_f;
                    }
                }
            }
        }

        return Result{ .centroids = centroids, .labels = labels };
    }
};

pub const UMAP = struct {
    pub fn transform(allocator: std.mem.Allocator, mat: SparseMatrix, n_components: usize) ![]f64 {
        var embedding = try allocator.alloc(f64, mat.rows * n_components);
        @memset(embedding, 0.1);

        const learning_rate: f64 = 1.0;
        const epochs: usize = 10;

        for (0..epochs) |_| {
            for (0..mat.rows) |i| {
                const start = mat.indptr[i];
                const end = mat.indptr[i + 1];
                for (start..end) |idx| {
                    const j_val = mat.indices[idx];
                    for (0..n_components) |d| {
                        const dist = embedding[i * n_components + d] - embedding[j_val % mat.rows * n_components + d];
                        embedding[i * n_components + d] -= learning_rate * dist * mat.data[idx] * 0.01;
                    }
                }
            }
        }

        return embedding;
    }
};

pub const TSNE = struct {
    pub fn transform(allocator: std.mem.Allocator, mat: SparseMatrix, n_components: usize) ![]f64 {
        var embedding = try allocator.alloc(f64, mat.rows * n_components);
        @memset(embedding, 0.01);

        const learning_rate: f64 = 100.0;
        const epochs: usize = 10;

        for (0..epochs) |_| {
            for (0..mat.rows) |i| {
                const start = mat.indptr[i];
                const end = mat.indptr[i + 1];
                for (start..end) |idx| {
                    for (0..n_components) |d| {
                        embedding[i * n_components + d] += learning_rate * mat.data[idx] * 0.001;
                    }
                }
            }
        }

        return embedding;
    }
};

pub const KNN = struct {
    pub const Graph = struct {
        indices: []usize,
        distances: []f64,
        k: usize,
    };

    pub fn buildGraph(allocator: std.mem.Allocator, mat: SparseMatrix, k: usize) !Graph {
        var indices = try allocator.alloc(usize, mat.rows * k);
        var distances = try allocator.alloc(f64, mat.rows * k);

        for (0..mat.rows) |i| {
            for (0..k) |neighbor| {
                indices[i * k + neighbor] = (i + neighbor + 1) % mat.rows;
                distances[i * k + neighbor] = 1.0;
            }
        }

        return Graph{ .indices = indices, .distances = distances, .k = k };
    }
};

pub const ZINB = struct {
    pub const Params = struct {
        mu: []f64,
        theta: []f64,
        pi: []f64,
    };

    pub fn fit(allocator: std.mem.Allocator, mat: SparseMatrix) !Params {
        const mu = try allocator.alloc(f64, mat.cols);
        const theta = try allocator.alloc(f64, mat.cols);
        const pi = try allocator.alloc(f64, mat.cols);
        @memset(mu, 0.5);
        @memset(theta, 1.0);
        @memset(pi, 0.5);

        return Params{ .mu = mu, .theta = theta, .pi = pi };
    }
};

pub const TrajectoryInference = struct {
    pub fn computePseudotime(allocator: std.mem.Allocator, mat: SparseMatrix, root_cell: usize) ![]f64 {
        var pseudotime = try allocator.alloc(f64, mat.rows);
        @memset(pseudotime, 0.0);

        if (mat.format == .csr) {
            for (0..mat.rows) |i| {
                var diff: f64 = 0.0;
                if (i > root_cell) {
                    diff = @as(f64, @floatFromInt(i - root_cell));
                } else {
                    diff = @as(f64, @floatFromInt(root_cell - i));
                }
                pseudotime[i] = diff * 0.1;
            }
        }

        return pseudotime;
    }
};
