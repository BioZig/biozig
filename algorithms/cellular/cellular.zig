const std = @import("std");

/// Computes the mean expression of a gene across a set of cells.
pub fn meanExpression(expression_values: []const f64) f64 {
    if (expression_values.len == 0) return 0.0;
    var sum: f64 = 0.0;
    for (expression_values) |v| sum += v;
    return sum / @as(f64, @floatFromInt(expression_values.len));
}

/// Computes the variance of expression of a gene.
pub fn varianceExpression(expression_values: []const f64) f64 {
    if (expression_values.len < 2) return 0.0;
    const mean = meanExpression(expression_values);
    var sum_sq_diff: f64 = 0.0;
    for (expression_values) |v| {
        const diff = v - mean;
        sum_sq_diff += diff * diff;
    }
    return sum_sq_diff / @as(f64, @floatFromInt(expression_values.len - 1));
}

/// 2D Coordinate for spatial transcriptomics
pub const Vec2 = [2]f64;

pub const CoordinateSet2D = struct {
    x: []const f64,
    y: []const f64,
};

/// Euclidean distance in 2D space.
pub fn spatialDistance(ax: f64, ay: f64, bx: f64, by: f64) f64 {
    const dx = ax - bx;
    const dy = ay - by;
    return @sqrt(dx * dx + dy * dy);
}

pub const SpatialNeighbor = struct {
    index: usize,
    distance: f64,
};

pub const KdNode = struct {
    x: f64,
    y: f64,
    index: usize,
    left: ?*KdNode,
    right: ?*KdNode,
};

pub const KdTree = struct {
    allocator: std.mem.Allocator,
    root: ?*KdNode,

    const Item = struct { x: f64, y: f64, idx: usize };

    pub fn init(allocator: std.mem.Allocator, points: CoordinateSet2D) !KdTree {
        var tree = KdTree{ .allocator = allocator, .root = null };
        if (points.x.len == 0) return tree;

        var items = try allocator.alloc(Item, points.x.len);
        defer allocator.free(items);
        for (points.x, points.y, 0..) |px, py, i| {
            items[i] = .{ .x = px, .y = py, .idx = i };
        }

        tree.root = try buildTree(allocator, items, 0);
        return tree;
    }

    fn buildTree(allocator: std.mem.Allocator, items: []Item, depth: usize) !?*KdNode {
        if (items.len == 0) return null;

        const axis = depth % 2;

        if (axis == 0) {
            std.sort.block(Item, items, {}, struct {
                fn lessThan(_: void, a: Item, b: Item) bool {
                    return a.x < b.x;
                }
            }.lessThan);
        } else {
            std.sort.block(Item, items, {}, struct {
                fn lessThan(_: void, a: Item, b: Item) bool {
                    return a.y < b.y;
                }
            }.lessThan);
        }

        const mid = items.len / 2;
        var node = try allocator.create(KdNode);
        node.x = items[mid].x;
        node.y = items[mid].y;
        node.index = items[mid].idx;
        node.left = try buildTree(allocator, items[0..mid], depth + 1);
        node.right = try buildTree(allocator, items[mid + 1 ..], depth + 1);
        return node;
    }

    pub fn deinit(self: *KdTree) void {
        freeNode(self.allocator, self.root);
    }

    fn freeNode(allocator: std.mem.Allocator, node: ?*KdNode) void {
        if (node) |n| {
            freeNode(allocator, n.left);
            freeNode(allocator, n.right);
            allocator.destroy(n);
        }
    }

    pub fn radiusSearch(self: *KdTree, allocator: std.mem.Allocator, tx: f64, ty: f64, radius: f64, neighbors: *std.ArrayList(SpatialNeighbor)) !void {
        try searchNode(allocator, self.root, tx, ty, radius, 0, neighbors);
    }

    fn searchNode(allocator: std.mem.Allocator, node: ?*KdNode, tx: f64, ty: f64, radius: f64, depth: usize, neighbors: *std.ArrayList(SpatialNeighbor)) !void {
        const n = node orelse return;

        const dist = spatialDistance(tx, ty, n.x, n.y);
        if (dist <= radius and dist > 0.0) {
            try neighbors.append(allocator, .{ .index = n.index, .distance = dist });
        }

        const axis = depth % 2;
        const diff = if (axis == 0) tx - n.x else ty - n.y;

        var first = n.left;
        var second = n.right;
        if (diff > 0) {
            first = n.right;
            second = n.left;
        }

        try searchNode(allocator, first, tx, ty, radius, depth + 1, neighbors);

        if (@abs(diff) <= radius) {
            try searchNode(allocator, second, tx, ty, radius, depth + 1, neighbors);
        }
    }
};

/// Finds all cells within a certain spatial radius.
pub fn spatialNeighborhood(allocator: std.mem.Allocator, tx: f64, ty: f64, points: CoordinateSet2D, radius: f64) ![]SpatialNeighbor {
    var tree = try KdTree.init(allocator, points);
    defer tree.deinit();

    var neighbors = std.ArrayList(SpatialNeighbor).empty;
    errdefer neighbors.deinit(allocator);

    try tree.radiusSearch(allocator, tx, ty, radius, &neighbors);

    return neighbors.toOwnedSlice(allocator);
}

/// Calculates the average expression of a gene within a local neighborhood.
pub fn neighborhoodExpressionStats(neighbors: []const SpatialNeighbor, expression_matrix_column: []const f64) f64 {
    if (neighbors.len == 0) return 0.0;
    var sum: f64 = 0.0;
    for (neighbors) |n| {
        sum += expression_matrix_column[n.index];
    }
    return sum / @as(f64, @floatFromInt(neighbors.len));
}

pub const CellCycleScores = struct {
    g1_s: f64,
    g2_m: f64,
    phase: enum { G1, S, G2M },
};

/// Deterministically scores a cell's cycle phase based on mean expression of phase-specific marker genes.
/// Inputs are the cell's expression vector, and boolean masks indicating if a gene is a G1/S or G2/M marker.
pub fn scoreCellCycle(cell_expression: []const f64, g1_s_mask: []const bool, g2_m_mask: []const bool) !CellCycleScores {
    if (cell_expression.len != g1_s_mask.len or cell_expression.len != g2_m_mask.len) {
        return error.DimensionMismatch;
    }

    var g1_s_sum: f64 = 0;
    var g1_s_count: usize = 0;

    var g2_m_sum: f64 = 0;
    var g2_m_count: usize = 0;

    for (cell_expression, 0..) |expr, i| {
        if (g1_s_mask[i]) {
            g1_s_sum += expr;
            g1_s_count += 1;
        }
        if (g2_m_mask[i]) {
            g2_m_sum += expr;
            g2_m_count += 1;
        }
    }

    const g1_s_score = if (g1_s_count > 0) g1_s_sum / @as(f64, @floatFromInt(g1_s_count)) else 0.0;
    const g2_m_score = if (g2_m_count > 0) g2_m_sum / @as(f64, @floatFromInt(g2_m_count)) else 0.0;

    // Phase assignment logic based on standard Seurat-like heuristic thresholds (simplified to max score > 0)
    var phase: @TypeOf((CellCycleScores{ .g1_s = 0, .g2_m = 0, .phase = .G1 }).phase) = .G1;

    if (g1_s_score > 0 or g2_m_score > 0) {
        if (g1_s_score > g2_m_score) {
            phase = .S;
        } else {
            phase = .G2M;
        }
    }

    return CellCycleScores{
        .g1_s = g1_s_score,
        .g2_m = g2_m_score,
        .phase = phase,
    };
}

test "Cellular Algorithms - Expression Stats" {
    const expr = [_]f64{ 2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0 };
    const mean = meanExpression(&expr);
    try std.testing.expectEqual(@as(f64, 5.0), mean);

    const variance = varianceExpression(&expr);
    try std.testing.expect(variance > 4.5 and variance < 4.6); // 32 / 7 ≈ 4.57
}

test "Cellular Algorithms - Spatial Neighborhood" {
    const alloc = std.testing.allocator;
    const px = [_]f64{ 0, 1, 0, 10 };
    const py = [_]f64{ 0, 0, 2, 10 };
    const points = CoordinateSet2D{ .x = &px, .y = &py };

    const neighbors = try spatialNeighborhood(alloc, 0, 0, points, 1.5);
    defer alloc.free(neighbors);

    try std.testing.expectEqual(@as(usize, 1), neighbors.len);
    try std.testing.expectEqual(@as(usize, 1), neighbors[0].index); // {1,0} is inside
}

test "Cellular Algorithms - Cell Cycle" {
    const expr = [_]f64{ 1.0, 5.0, 0.5, 8.0 }; // Genes 0-3
    const g1_s = [_]bool{ true, true, false, false };
    const g2_m = [_]bool{ false, false, true, true };

    const score = try scoreCellCycle(&expr, &g1_s, &g2_m);
    try std.testing.expectEqual(@as(f64, 3.0), score.g1_s);
    try std.testing.expectEqual(@as(f64, 4.25), score.g2_m);
    try std.testing.expectEqual(.G2M, score.phase);
}

const cellular_mod = @import("cellular");
const SparseMatrix = cellular_mod.expression.SparseMatrix;

// 1. Sparse Matrix Ops
pub const SparseMatrixOps = struct {
    /// Computes the sum of each column
    pub fn colSums(allocator: std.mem.Allocator, mat: SparseMatrix) ![]f64 {
        const sums = try allocator.alloc(f64, mat.cols);
        @memset(sums, 0.0);
        if (mat.format == .csr) {
            for (0..mat.rows) |r| {
                const start = mat.indptr[r];
                const end = mat.indptr[r + 1];
                for (start..end) |idx| {
                    const c = mat.indices[idx];
                    sums[c] += mat.data[idx];
                }
            }
        } else {
            for (0..mat.cols) |c| {
                const start = mat.indptr[c];
                const end = mat.indptr[c + 1];
                for (start..end) |idx| {
                    sums[c] += mat.data[idx];
                }
            }
        }
        return sums;
    }

    /// Computes the sum of each row
    pub fn rowSums(allocator: std.mem.Allocator, mat: SparseMatrix) ![]f64 {
        const sums = try allocator.alloc(f64, mat.rows);
        @memset(sums, 0.0);
        if (mat.format == .csr) {
            for (0..mat.rows) |r| {
                const start = mat.indptr[r];
                const end = mat.indptr[r + 1];
                for (start..end) |idx| {
                    sums[r] += mat.data[idx];
                }
            }
        } else {
            for (0..mat.cols) |c| {
                const start = mat.indptr[c];
                const end = mat.indptr[c + 1];
                for (start..end) |idx| {
                    const r = mat.indices[idx];
                    sums[r] += mat.data[idx];
                }
            }
        }
        return sums;
    }

    /// Multiplies sparse matrix by a dense vector (y = A * x)
    pub fn multiplyVector(allocator: std.mem.Allocator, mat: SparseMatrix, x: []const f64) ![]f64 {
        std.debug.assert(x.len == mat.cols);
        const y = try allocator.alloc(f64, mat.rows);
        @memset(y, 0.0);

        if (mat.format == .csr) {
            for (0..mat.rows) |r| {
                const start = mat.indptr[r];
                const end = mat.indptr[r + 1];
                var sum: f64 = 0.0;
                for (start..end) |idx| {
                    const c = mat.indices[idx];
                    sum += mat.data[idx] * x[c];
                }
                y[r] = sum;
            }
        } else {
            for (0..mat.cols) |c| {
                const start = mat.indptr[c];
                const end = mat.indptr[c + 1];
                for (start..end) |idx| {
                    const r = mat.indices[idx];
                    y[r] += mat.data[idx] * x[c];
                }
            }
        }
        return y;
    }
};

// 2. Differential Expression
pub const DifferentialExpression = struct {
    pub const TestResult = struct {
        log2fc: f64,
        p_value: f64,
    };

    pub fn simpleDiffExp(allocator: std.mem.Allocator, mat: SparseMatrix, group1: []const usize, group2: []const usize) ![]TestResult {
        const hypothesis = @import("analytics").statistics.hypothesis;
        const multiple_testing = @import("analytics").statistics.multiple_testing;

        const results = try allocator.alloc(TestResult, mat.cols);

        var p_values = try allocator.alloc(f64, mat.cols);
        defer allocator.free(p_values);

        const group1_vals = try allocator.alloc(f64, group1.len);
        defer allocator.free(group1_vals);
        const group2_vals = try allocator.alloc(f64, group2.len);
        defer allocator.free(group2_vals);

        const len1 = @as(f64, @floatFromInt(group1.len));
        const len2 = @as(f64, @floatFromInt(group2.len));

        for (0..mat.cols) |c| {
            var sum1: f64 = 0.0;
            var sum2: f64 = 0.0;

            for (group1, 0..) |r, i| {
                const val = mat.get(r, c);
                group1_vals[i] = val;
                sum1 += val;
            }
            for (group2, 0..) |r, i| {
                const val = mat.get(r, c);
                group2_vals[i] = val;
                sum2 += val;
            }

            const mean1 = if (len1 > 0) sum1 / len1 else 0;
            const mean2 = if (len2 > 0) sum2 / len2 else 0;

            const pseudo_count = 1e-4;
            const log2fc = @log2((mean1 + pseudo_count) / (mean2 + pseudo_count));

            var p_val: f64 = 1.0;
            if (len1 > 1 and len2 > 1) {
                var var1: f64 = 0;
                var var2: f64 = 0;
                for (group1_vals) |v| {
                    const d = v - mean1;
                    var1 += d * d;
                }
                for (group2_vals) |v| {
                    const d = v - mean2;
                    var2 += d * d;
                }

                if (var1 > 0 or var2 > 0) {
                    const test_res = hypothesis.welchTTest(group1_vals, group2_vals);
                    p_val = test_res.p_value;
                }
            }

            results[c] = .{
                .log2fc = log2fc,
                .p_value = p_val,
            };
            p_values[c] = p_val;
        }

        const adj_p_values = try multiple_testing.benjaminiHochberg(p_values, allocator);
        defer allocator.free(adj_p_values);

        for (0..mat.cols) |c| {
            results[c].p_value = adj_p_values[c];
        }

        return results;
    }
};

// 3. PCA
pub const PCA = struct {
    pub fn topComponent(allocator: std.mem.Allocator, mat: SparseMatrix, iterations: usize) ![]f64 {
        var v = try allocator.alloc(f64, mat.cols);
        for (v, 0..) |_, i| v[i] = 1.0;

        for (0..iterations) |_| {
            const Av = try SparseMatrixOps.multiplyVector(allocator, mat, v);
            defer allocator.free(Av);

            var new_v = try allocator.alloc(f64, mat.cols);
            @memset(new_v, 0.0);

            if (mat.format == .csr) {
                for (0..mat.rows) |r| {
                    const start = mat.indptr[r];
                    const end = mat.indptr[r + 1];
                    for (start..end) |idx| {
                        const c = mat.indices[idx];
                        new_v[c] += mat.data[idx] * Av[r];
                    }
                }
            } else {
                for (0..mat.cols) |c| {
                    const start = mat.indptr[c];
                    const end = mat.indptr[c + 1];
                    var sum: f64 = 0.0;
                    for (start..end) |idx| {
                        sum += mat.data[idx] * Av[mat.indices[idx]];
                    }
                    new_v[c] = sum;
                }
            }

            var norm: f64 = 0.0;
            for (new_v) |val| norm += val * val;
            norm = @sqrt(norm);

            if (norm > 0) {
                for (new_v, 0..) |val, i| v[i] = val / norm;
            }
            allocator.free(new_v);
        }
        return v;
    }
};

// 4. Incremental PCA
pub const IncrementalPCA = struct {
    pub fn onlineTopComponent(allocator: std.mem.Allocator, mat: SparseMatrix, learning_rate: f64) ![]f64 {
        var w = try allocator.alloc(f64, mat.cols);
        for (w, 0..) |_, i| w[i] = 1.0 / @sqrt(@as(f64, @floatFromInt(mat.cols)));

        if (mat.format == .csr) {
            for (0..mat.rows) |r| {
                const start = mat.indptr[r];
                const end = mat.indptr[r + 1];

                var y: f64 = 0.0;
                for (start..end) |idx| {
                    y += mat.data[idx] * w[mat.indices[idx]];
                }

                for (start..end) |idx| {
                    const c = mat.indices[idx];
                    w[c] += learning_rate * y * (mat.data[idx] - y * w[c]);
                }
            }
        }

        var norm: f64 = 0.0;
        for (w) |val| norm += val * val;
        norm = @sqrt(norm);
        if (norm > 0) {
            for (w, 0..) |val, i| w[i] = val / norm;
        }

        return w;
    }
};
const advanced = @import("advanced.zig");
pub const KMeans = advanced.KMeans;
pub const UMAP = advanced.UMAP;
pub const TSNE = advanced.TSNE;
pub const KNN = advanced.KNN;
pub const ZINB = advanced.ZINB;
pub const TrajectoryInference = advanced.TrajectoryInference;
