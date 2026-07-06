const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub const Matrix = struct {
    rows: usize,
    cols: usize,
    data: []f64,

    pub fn init(allocator: Allocator, rows: usize, cols: usize) !Matrix {
        const data = try allocator.alloc(f64, rows * cols);
        @memset(data, 0.0);
        return Matrix{ .rows = rows, .cols = cols, .data = data };
    }

    pub fn deinit(self: *Matrix, allocator: Allocator) void {
        allocator.free(self.data);
    }

    pub fn get(self: Matrix, r: usize, c: usize) f64 {
        return self.data[r * self.cols + c];
    }

    pub fn set(self: *Matrix, r: usize, c: usize, val: f64) void {
        self.data[r * self.cols + c] = val;
    }
};

pub fn matmul(allocator: Allocator, A: Matrix, B: Matrix) !Matrix {
    std.debug.assert(A.cols == B.rows);
    var C = try Matrix.init(allocator, A.rows, B.cols);
    for (0..A.rows) |i| {
        for (0..B.cols) |j| {
            var sum: f64 = 0;
            for (0..A.cols) |k| {
                sum += A.get(i, k) * B.get(k, j);
            }
            C.set(i, j, sum);
        }
    }
    return C;
}

pub fn transpose(allocator: Allocator, A: Matrix) !Matrix {
    var C = try Matrix.init(allocator, A.cols, A.rows);
    for (0..A.rows) |i| {
        for (0..A.cols) |j| {
            C.set(j, i, A.get(i, j));
        }
    }
    return C;
}

pub const NmfResult = struct {
    W: Matrix,
    H: Matrix,
};

/// Non-Negative Matrix Factorization using multiplicative update rules.
/// Factorizes V into W and H such that V ≈ W * H.
pub fn nmf(allocator: Allocator, V: Matrix, k: usize, iterations: usize) !NmfResult {
    var W = try Matrix.init(allocator, V.rows, k);
    var H = try Matrix.init(allocator, k, V.cols);

    // Initialize with some positive random values
    var prng = std.Random.Pcg.init(42);
    const random = prng.random();
    for (0..W.rows * W.cols) |i| W.data[i] = random.float(f64) + 0.1;
    for (0..H.rows * H.cols) |i| H.data[i] = random.float(f64) + 0.1;

    for (0..iterations) |_| {
        // H update: H = H * (W^T V) / (W^T W H)
        var W_t = try transpose(allocator, W);
        var WtV = try matmul(allocator, W_t, V);
        var WtW = try matmul(allocator, W_t, W);
        var WtWH = try matmul(allocator, WtW, H);

        for (0..H.rows * H.cols) |i| {
            H.data[i] = H.data[i] * WtV.data[i] / (WtWH.data[i] + 1e-9);
        }

        WtWH.deinit(allocator);
        WtW.deinit(allocator);
        WtV.deinit(allocator);
        W_t.deinit(allocator);

        // W update: W = W * (V H^T) / (W H H^T)
        var H_t = try transpose(allocator, H);
        var VHt = try matmul(allocator, V, H_t);
        var HHt = try matmul(allocator, H, H_t);
        var WHHt = try matmul(allocator, W, HHt);

        for (0..W.rows * W.cols) |i| {
            W.data[i] = W.data[i] * VHt.data[i] / (WHHt.data[i] + 1e-9);
        }

        WHHt.deinit(allocator);
        HHt.deinit(allocator);
        VHt.deinit(allocator);
        H_t.deinit(allocator);
    }

    return NmfResult{ .W = W, .H = H };
}

/// Classical Multidimensional Scaling (MDS).
/// Given a symmetric distance matrix D, returns the k-dimensional coordinate matrix X.
pub fn mds(allocator: Allocator, D: Matrix, k: usize) !Matrix {
    const n = D.rows;
    std.debug.assert(n == D.cols);

    var B = try Matrix.init(allocator, n, n);
    defer B.deinit(allocator);

    var row_means = try allocator.alloc(f64, n);
    defer allocator.free(row_means);
    @memset(row_means, 0.0);

    var grand_mean: f64 = 0.0;

    for (0..n) |i| {
        for (0..n) |j| {
            const d2 = D.get(i, j) * D.get(i, j);
            row_means[i] += d2;
            grand_mean += d2;
        }
        row_means[i] /= @as(f64, @floatFromInt(n));
    }
    grand_mean /= @as(f64, @floatFromInt(n * n));

    for (0..n) |i| {
        for (0..n) |j| {
            const d2 = D.get(i, j) * D.get(i, j);
            const b_val = -0.5 * (d2 - row_means[i] - row_means[j] + grand_mean);
            B.set(i, j, b_val);
        }
    }

    // Jacobi eigenvalue algorithm
    var V_mat = try Matrix.init(allocator, n, n);
    defer V_mat.deinit(allocator);
    for (0..n) |i| {
        V_mat.set(i, i, 1.0);
    }

    var A = try Matrix.init(allocator, n, n);
    defer A.deinit(allocator);
    @memcpy(A.data, B.data);

    const max_iter = 100;
    for (0..max_iter) |_| {
        var max_val: f64 = 0.0;
        var p: usize = 0;
        var q: usize = 0;
        for (0..n) |i| {
            for (i + 1..n) |j| {
                const val = @abs(A.get(i, j));
                if (val > max_val) {
                    max_val = val;
                    p = i;
                    q = j;
                }
            }
        }

        if (max_val < 1e-9) break;

        const app = A.get(p, p);
        const aqq = A.get(q, q);
        const apq = A.get(p, q);

        var t: f64 = 0.0;
        const theta = (aqq - app) / (2.0 * apq);
        if (theta >= 0) {
            t = 1.0 / (theta + @sqrt(theta * theta + 1.0));
        } else {
            t = 1.0 / (theta - @sqrt(theta * theta + 1.0));
        }

        const c = 1.0 / @sqrt(t * t + 1.0);
        const s = t * c;

        for (0..n) |i| {
            if (i != p and i != q) {
                const aip = A.get(i, p);
                const aiq = A.get(i, q);
                A.set(i, p, c * aip - s * aiq);
                A.set(p, i, A.get(i, p));
                A.set(i, q, s * aip + c * aiq);
                A.set(q, i, A.get(i, q));
            }
        }
        A.set(p, p, c * c * app - 2.0 * s * c * apq + s * s * aqq);
        A.set(q, q, s * s * app + 2.0 * s * c * apq + c * c * aqq);
        A.set(p, q, 0.0);
        A.set(q, p, 0.0);

        for (0..n) |i| {
            const vip = V_mat.get(i, p);
            const viq = V_mat.get(i, q);
            V_mat.set(i, p, c * vip - s * viq);
            V_mat.set(i, q, s * vip + c * viq);
        }
    }

    var evals = try allocator.alloc(f64, n);
    defer allocator.free(evals);
    for (0..n) |i| evals[i] = A.get(i, i);

    var indices = try allocator.alloc(usize, n);
    defer allocator.free(indices);
    for (0..n) |i| indices[i] = i;

    for (0..n) |i| {
        for (i + 1..n) |j| {
            if (evals[indices[j]] > evals[indices[i]]) {
                const temp = indices[i];
                indices[i] = indices[j];
                indices[j] = temp;
            }
        }
    }

    var X = try Matrix.init(allocator, n, k);
    for (0..k) |j| {
        const idx = indices[j];
        var lambda = evals[idx];
        if (lambda < 0) lambda = 0;
        const sqrt_lambda = @sqrt(lambda);
        for (0..n) |i| {
            X.set(i, j, V_mat.get(i, idx) * sqrt_lambda);
        }
    }

    return X;
}

test "NMF functionality" {
    const allocator = std.testing.allocator;
    var V = try Matrix.init(allocator, 2, 2);
    defer V.deinit(allocator);
    V.set(0, 0, 1.0);
    V.set(0, 1, 2.0);
    V.set(1, 0, 3.0);
    V.set(1, 1, 4.0);

    var res = try nmf(allocator, V, 2, 50);
    defer res.W.deinit(allocator);
    defer res.H.deinit(allocator);

    var WH = try matmul(allocator, res.W, res.H);
    defer WH.deinit(allocator);

    try std.testing.expect(WH.rows == 2 and WH.cols == 2);
}

test "MDS functionality" {
    const allocator = std.testing.allocator;
    var D = try Matrix.init(allocator, 3, 3);
    defer D.deinit(allocator);

    D.set(0, 1, 5.0);
    D.set(1, 0, 5.0);
    D.set(0, 2, 3.0);
    D.set(2, 0, 3.0);
    D.set(1, 2, 4.0);
    D.set(2, 1, 4.0);

    var X = try mds(allocator, D, 2);
    defer X.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), X.rows);
    try std.testing.expectEqual(@as(usize, 2), X.cols);
}
