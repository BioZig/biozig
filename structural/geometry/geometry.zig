const std = @import("std");

pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn init(x: f64, y: f64, z: f64) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vec3, s: f64) Vec3 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn dot(self: Vec3, other: Vec3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn norm2(self: Vec3) f64 {
        return self.dot(self);
    }

    pub fn norm(self: Vec3) f64 {
        return @sqrt(self.norm2());
    }

    pub fn normalize(self: Vec3) Vec3 {
        const n = self.norm();
        if (n == 0.0) return self;
        return self.scale(1.0 / n);
    }
};

pub const BoundingBox = struct {
    min: Vec3,
    max: Vec3,

    pub fn contains(self: BoundingBox, p: Vec3) bool {
        return p.x >= self.min.x and p.x <= self.max.x and
            p.y >= self.min.y and p.y <= self.max.y and
            p.z >= self.min.z and p.z <= self.max.z;
    }
};

pub const CoordinateSet = struct {
    x: []const f64,
    y: []const f64,
    z: []const f64,
};

pub const CoordinateSetMut = struct {
    x: []f64,
    y: []f64,
    z: []f64,

    pub fn init(allocator: std.mem.Allocator, len: usize) !CoordinateSetMut {
        const x = try allocator.alloc(f64, len);
        errdefer allocator.free(x);
        const y = try allocator.alloc(f64, len);
        errdefer allocator.free(y);
        const z = try allocator.alloc(f64, len);
        return CoordinateSetMut{ .x = x, .y = y, .z = z };
    }

    pub fn deinit(self: *CoordinateSetMut, allocator: std.mem.Allocator) void {
        allocator.free(self.x);
        allocator.free(self.y);
        allocator.free(self.z);
    }
};

pub fn distance2(a: Vec3, b: Vec3) f64 {
    return a.sub(b).norm2();
}

pub fn distance(a: Vec3, b: Vec3) f64 {
    return @sqrt(distance2(a, b));
}

pub fn centroid(points: CoordinateSet) Vec3 {
    if (points.x.len == 0) return Vec3.init(0, 0, 0);

    var sum_x_vec: @Vector(4, f64) = @splat(0.0);
    var sum_y_vec: @Vector(4, f64) = @splat(0.0);
    var sum_z_vec: @Vector(4, f64) = @splat(0.0);

    var idx: usize = 0;
    while (idx + 4 <= points.x.len) : (idx += 4) {
        sum_x_vec += points.x[idx .. idx + 4][0..4].*;
        sum_y_vec += points.y[idx .. idx + 4][0..4].*;
        sum_z_vec += points.z[idx .. idx + 4][0..4].*;
    }

    var sum_x = @reduce(.Add, sum_x_vec);
    var sum_y = @reduce(.Add, sum_y_vec);
    var sum_z = @reduce(.Add, sum_z_vec);

    while (idx < points.x.len) : (idx += 1) {
        sum_x += points.x[idx];
        sum_y += points.y[idx];
        sum_z += points.z[idx];
    }

    const scale = 1.0 / @as(f64, @floatFromInt(points.x.len));
    return Vec3.init(sum_x * scale, sum_y * scale, sum_z * scale);
}

pub fn boundingBox(points: CoordinateSet) BoundingBox {
    if (points.x.len == 0) {
        return .{ .min = Vec3.init(0, 0, 0), .max = Vec3.init(0, 0, 0) };
    }
    var min = Vec3.init(points.x[0], points.y[0], points.z[0]);
    var max = min;
    for (points.x[1..], points.y[1..], points.z[1..]) |px, py, pz| {
        min.x = @min(min.x, px);
        min.y = @min(min.y, py);
        min.z = @min(min.z, pz);
        max.x = @max(max.x, px);
        max.y = @max(max.y, py);
        max.z = @max(max.z, pz);
    }
    return .{ .min = min, .max = max };
}

/// Calculates the angle (in radians) between three points A - B - C (angle at B).
pub fn angle(a: Vec3, b: Vec3, c: Vec3) f64 {
    const ba = a.sub(b);
    const bc = c.sub(b);
    const dot_val = ba.dot(bc);
    const norm_product = ba.norm() * bc.norm();
    if (norm_product == 0.0) return 0.0;
    const cos_theta = @min(1.0, @max(-1.0, dot_val / norm_product));
    return std.math.acos(cos_theta);
}

/// Calculates the dihedral (torsion) angle (in radians) between four points A - B - C - D.
pub fn dihedral(a: Vec3, b: Vec3, c: Vec3, d: Vec3) f64 {
    const b1 = b.sub(a);
    const b2 = c.sub(b);
    const b3 = d.sub(c);

    const n1 = b1.cross(b2);
    const n2 = b2.cross(b3);

    const m1 = n1.cross(b2.normalize());

    const x = n1.dot(n2);
    const y = m1.dot(n2);

    return std.math.atan2(y, x);
}

/// Performs Jacobi rotation diagonalization on a symmetric 3x3 matrix.
/// Finds eigenvalues (d) and eigenvectors (V).
pub fn jacobiSymmetric3(a: [3][3]f64, V: *[3][3]f64, d: *[3]f64) void {
    V.* = .{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    };
    var A = a;
    d.* = .{ A[0][0], A[1][1], A[2][2] };

    const max_rotations = 50;
    var ip: usize = 0;
    while (ip < max_rotations) : (ip += 1) {
        var sm: f64 = 0.0;
        inline for (0..2) |i| {
            inline for (i + 1..3) |j| {
                sm += @abs(A[i][j]);
            }
        }
        if (sm == 0.0) break; // Converged

        inline for (0..2) |g| {
            inline for (g + 1..3) |h| {
                const thresh = 1e-15;
                const g_diff = @abs(A[g][h]);
                if (g_diff >= thresh) {
                    const h_val = d[h] - d[g];
                    var t: f64 = 0.0;
                    if (@abs(h_val) + 100.0 * g_diff == @abs(h_val)) {
                        t = A[g][h] / h_val;
                    } else {
                        const theta = 0.5 * h_val / A[g][h];
                        t = 1.0 / (@abs(theta) + @sqrt(1.0 + theta * theta));
                        if (theta < 0.0) t = -t;
                    }

                    const c = 1.0 / @sqrt(1.0 + t * t);
                    const s = t * c;
                    const tau = s / (1.0 + c);
                    const h_rot = t * A[g][h];

                    d[g] -= h_rot;
                    d[h] += h_rot;
                    A[g][h] = 0.0;

                    // Rotation of off-diagonal elements
                    inline for (0..g) |j| {
                        const g_old = A[j][g];
                        const h_old = A[j][h];
                        A[j][g] = g_old - s * (h_old + g_old * tau);
                        A[j][h] = h_old + s * (g_old - h_old * tau);
                    }
                    inline for (g + 1..h) |j| {
                        const g_old = A[g][j];
                        const h_old = A[j][h];
                        A[g][j] = g_old - s * (h_old + g_old * tau);
                        A[j][h] = h_old + s * (g_old - h_old * tau);
                    }
                    inline for (h + 1..3) |j| {
                        const g_old = A[g][j];
                        const h_old = A[h][j];
                        A[g][j] = g_old - s * (h_old + g_old * tau);
                        A[h][j] = h_old + s * (g_old - h_old * tau);
                    }

                    // Update V eigenvectors
                    inline for (0..3) |j| {
                        const g_old = V[j][g];
                        const h_old = V[j][h];
                        V[j][g] = g_old - s * (h_old + g_old * tau);
                        V[j][h] = h_old + s * (g_old - h_old * tau);
                    }
                }
            }
        }
    }
}

/// Computes the Singular Value Decomposition H = U * S * V^T of a 3x3 matrix H.
pub fn svd3(H: [3][3]f64, U: *[3][3]f64, S: *[3]f64, V: *[3][3]f64) void {
    // 1. Compute H^T * H
    var HtH = [_][3]f64{[_]f64{0} ** 3} ** 3;
    inline for (0..3) |i| {
        inline for (0..3) |j| {
            var sum: f64 = 0.0;
            inline for (0..3) |k| {
                sum += H[k][i] * H[k][j];
            }
            HtH[i][j] = sum;
        }
    }

    // 2. Diagonalize H^T * H to find eigenvalues and V (eigenvectors of H^T * H)
    var V_eigen = [_][3]f64{[_]f64{0} ** 3} ** 3;
    var d = [_]f64{0} ** 3;
    jacobiSymmetric3(HtH, &V_eigen, &d);

    // Sort eigenvalues and corresponding eigenvectors in descending order
    var indices = [_]usize{ 0, 1, 2 };
    if (d[0] < d[1]) {
        std.mem.swap(usize, &indices[0], &indices[1]);
        std.mem.swap(f64, &d[0], &d[1]);
    }
    if (d[1] < d[2]) {
        std.mem.swap(usize, &indices[1], &indices[2]);
        std.mem.swap(f64, &d[1], &d[2]);
    }
    if (d[0] < d[1]) {
        std.mem.swap(usize, &indices[0], &indices[1]);
        std.mem.swap(f64, &d[0], &d[1]);
    }

    var V_sorted = [_][3]f64{[_]f64{0} ** 3} ** 3;
    inline for (0..3) |i| {
        inline for (0..3) |j| {
            V_sorted[i][j] = V_eigen[i][indices[j]];
        }
    }
    V.* = V_sorted;

    // Singular values
    S[0] = if (d[0] > 0.0) @sqrt(d[0]) else 0.0;
    S[1] = if (d[1] > 0.0) @sqrt(d[1]) else 0.0;
    S[2] = if (d[2] > 0.0) @sqrt(d[2]) else 0.0;

    // 3. Compute U columns: u_i = H * v_i / s_i
    inline for (0..3) |i| {
        const s = S[i];
        if (s > 1e-9) {
            inline for (0..3) |j| {
                var sum: f64 = 0.0;
                inline for (0..3) |k| {
                    sum += H[j][k] * V[k][i];
                }
                U[j][i] = sum / s;
            }
        } else {
            // Handle singular cases (orthogonalize with cross product)
            U[0][i] = 0.0;
            U[1][i] = 0.0;
            U[2][i] = 0.0;
        }
    }

    // Ensure U is orthogonal for rank-deficient matrices
    if (S[2] <= 1e-9) {
        // u_2 = u_0 x u_1
        const u_0 = Vec3.init(U[0][0], U[1][0], U[2][0]);
        const u_1 = Vec3.init(U[0][1], U[1][1], U[2][1]);
        const u_2 = u_0.cross(u_1).normalize();
        U[0][2] = u_2.x;
        U[1][2] = u_2.y;
        U[2][2] = u_2.z;
    }
}

pub const Transformation = struct {
    translation_x: Vec3, // Translation for X
    translation_y: Vec3, // Translation for Y
    rotation: [3][3]f64, // Rotation matrix
};

/// Computes the optimal translation and rotation to superimpose points X onto Y
/// (minimizes RMSD). Returns optimal Transformation and minimum RMSD.
pub fn kabsch(x: CoordinateSet, y: CoordinateSet) !struct { Transformation, f64 } {
    std.debug.assert(x.x.len == y.x.len);
    std.debug.assert(x.x.len >= 3);

    // 1. Calculate centroids
    const centroid_x = centroid(x);
    const centroid_y = centroid(y);

    // 2. Compute covariance matrix H
    var H = [_][3]f64{[_]f64{0} ** 3} ** 3;
    var H00: @Vector(4, f64) = @splat(0.0);
    var H01: @Vector(4, f64) = @splat(0.0);
    var H02: @Vector(4, f64) = @splat(0.0);
    var H10: @Vector(4, f64) = @splat(0.0);
    var H11: @Vector(4, f64) = @splat(0.0);
    var H12: @Vector(4, f64) = @splat(0.0);
    var H20: @Vector(4, f64) = @splat(0.0);
    var H21: @Vector(4, f64) = @splat(0.0);
    var H22: @Vector(4, f64) = @splat(0.0);

    var cov_idx: usize = 0;
    while (cov_idx + 4 <= x.x.len) : (cov_idx += 4) {
        const dx_x = x.x[cov_idx .. cov_idx + 4][0..4].* - @as(@Vector(4, f64), @splat(centroid_x.x));
        const dx_y = x.y[cov_idx .. cov_idx + 4][0..4].* - @as(@Vector(4, f64), @splat(centroid_x.y));
        const dx_z = x.z[cov_idx .. cov_idx + 4][0..4].* - @as(@Vector(4, f64), @splat(centroid_x.z));

        const dy_x = y.x[cov_idx .. cov_idx + 4][0..4].* - @as(@Vector(4, f64), @splat(centroid_y.x));
        const dy_y = y.y[cov_idx .. cov_idx + 4][0..4].* - @as(@Vector(4, f64), @splat(centroid_y.y));
        const dy_z = y.z[cov_idx .. cov_idx + 4][0..4].* - @as(@Vector(4, f64), @splat(centroid_y.z));

        H00 += dx_x * dy_x;
        H01 += dx_x * dy_y;
        H02 += dx_x * dy_z;
        H10 += dx_y * dy_x;
        H11 += dx_y * dy_y;
        H12 += dx_y * dy_z;
        H20 += dx_z * dy_x;
        H21 += dx_z * dy_y;
        H22 += dx_z * dy_z;
    }

    H[0][0] = @reduce(.Add, H00);
    H[0][1] = @reduce(.Add, H01);
    H[0][2] = @reduce(.Add, H02);
    H[1][0] = @reduce(.Add, H10);
    H[1][1] = @reduce(.Add, H11);
    H[1][2] = @reduce(.Add, H12);
    H[2][0] = @reduce(.Add, H20);
    H[2][1] = @reduce(.Add, H21);
    H[2][2] = @reduce(.Add, H22);

    while (cov_idx < x.x.len) : (cov_idx += 1) {
        const dx = Vec3.init(x.x[cov_idx], x.y[cov_idx], x.z[cov_idx]).sub(centroid_x);
        const dy = Vec3.init(y.x[cov_idx], y.y[cov_idx], y.z[cov_idx]).sub(centroid_y);

        H[0][0] += dx.x * dy.x;
        H[0][1] += dx.x * dy.y;
        H[0][2] += dx.x * dy.z;
        H[1][0] += dx.y * dy.x;
        H[1][1] += dx.y * dy.y;
        H[1][2] += dx.y * dy.z;
        H[2][0] += dx.z * dy.x;
        H[2][1] += dx.z * dy.y;
        H[2][2] += dx.z * dy.z;
    }

    // 3. Compute SVD of H
    var U = [_][3]f64{[_]f64{0} ** 3} ** 3;
    var S = [_]f64{0} ** 3;
    var V = [_][3]f64{[_]f64{0} ** 3} ** 3;
    svd3(H, &U, &S, &V);

    // 4. Calculate determinant of V * U^T to check for reflection
    // V_det * U_det
    const V_det: f64 = V[0][0] * (V[1][1] * V[2][2] - V[1][2] * V[2][1]) -
        V[0][1] * (V[1][0] * V[2][2] - V[1][2] * V[2][0]) +
        V[0][2] * (V[1][0] * V[2][1] - V[1][1] * V[2][0]);
    var U_det: f64 = U[0][0] * (U[1][1] * U[2][2] - U[1][2] * U[2][1]) -
        U[0][1] * (U[1][0] * U[2][2] - U[1][2] * U[2][0]) +
        U[0][2] * (U[1][0] * V[2][1] - U[1][1] * U[2][0]); // wait, minor typo in determinant formula?
    // Let's write the correct det formula for U:
    U_det = U[0][0] * (U[1][1] * U[2][2] - U[1][2] * U[2][1]) -
        U[0][1] * (U[1][0] * U[2][2] - U[1][2] * U[2][0]) +
        U[0][2] * (U[1][0] * U[2][1] - U[1][1] * U[2][0]);

    const det_sign = V_det * U_det;

    // 5. Rotation matrix R = V * D * U^T
    var D = [_]f64{ 1.0, 1.0, 1.0 };
    if (det_sign < 0.0) {
        D[2] = -1.0;
    }

    var R = [_][3]f64{[_]f64{0} ** 3} ** 3;
    inline for (0..3) |i| {
        inline for (0..3) |j| {
            var sum: f64 = 0.0;
            inline for (0..3) |k| {
                sum += V[i][k] * D[k] * U[j][k]; // V * D * U^T
            }
            R[i][j] = sum;
        }
    }

    const transform = Transformation{
        .translation_x = centroid_x,
        .translation_y = centroid_y,
        .rotation = R,
    };

    // 6. Calculate RMSD
    var rmsd_sum_vec: @Vector(4, f64) = @splat(0.0);
    var idx: usize = 0;
    while (idx + 4 <= x.x.len) : (idx += 4) {
        const xx = x.x[idx .. idx + 4][0..4].*;
        const xy = x.y[idx .. idx + 4][0..4].*;
        const xz = x.z[idx .. idx + 4][0..4].*;

        const yx = y.x[idx .. idx + 4][0..4].*;
        const yy = y.y[idx .. idx + 4][0..4].*;
        const yz = y.z[idx .. idx + 4][0..4].*;

        const dx_x = xx - @as(@Vector(4, f64), @splat(centroid_x.x));
        const dx_y = xy - @as(@Vector(4, f64), @splat(centroid_x.y));
        const dx_z = xz - @as(@Vector(4, f64), @splat(centroid_x.z));

        const dy_x = yx - @as(@Vector(4, f64), @splat(centroid_y.x));
        const dy_y = yy - @as(@Vector(4, f64), @splat(centroid_y.y));
        const dy_z = yz - @as(@Vector(4, f64), @splat(centroid_y.z));

        const rx = @as(@Vector(4, f64), @splat(R[0][0])) * dx_x + @as(@Vector(4, f64), @splat(R[0][1])) * dx_y + @as(@Vector(4, f64), @splat(R[0][2])) * dx_z;
        const ry = @as(@Vector(4, f64), @splat(R[1][0])) * dx_x + @as(@Vector(4, f64), @splat(R[1][1])) * dx_y + @as(@Vector(4, f64), @splat(R[1][2])) * dx_z;
        const rz = @as(@Vector(4, f64), @splat(R[2][0])) * dx_x + @as(@Vector(4, f64), @splat(R[2][1])) * dx_y + @as(@Vector(4, f64), @splat(R[2][2])) * dx_z;

        const diff_x = rx - dy_x;
        const diff_y = ry - dy_y;
        const diff_z = rz - dy_z;

        rmsd_sum_vec += diff_x * diff_x + diff_y * diff_y + diff_z * diff_z;
    }

    var rmsd_sum = @reduce(.Add, rmsd_sum_vec);
    while (idx < x.x.len) : (idx += 1) {
        const dx = Vec3.init(x.x[idx], x.y[idx], x.z[idx]).sub(centroid_x);
        const dy = Vec3.init(y.x[idx], y.y[idx], y.z[idx]).sub(centroid_y);

        const rx = Vec3.init(
            R[0][0] * dx.x + R[0][1] * dx.y + R[0][2] * dx.z,
            R[1][0] * dx.x + R[1][1] * dx.y + R[1][2] * dx.z,
            R[2][0] * dx.x + R[2][1] * dx.y + R[2][2] * dx.z,
        );

        rmsd_sum += distance2(rx, dy);
    }

    const rmsd_val = @sqrt(rmsd_sum / @as(f64, @floatFromInt(x.x.len)));
    return .{ transform, rmsd_val };
}

pub fn rmsd(x: CoordinateSet, y: CoordinateSet) f64 {
    std.debug.assert(x.x.len == y.x.len);
    var rmsd_sum_vec: @Vector(4, f64) = @splat(0.0);
    var idx: usize = 0;
    while (idx + 4 <= x.x.len) : (idx += 4) {
        const dx = x.x[idx .. idx + 4][0..4].* - y.x[idx .. idx + 4][0..4].*;
        const dy = x.y[idx .. idx + 4][0..4].* - y.y[idx .. idx + 4][0..4].*;
        const dz = x.z[idx .. idx + 4][0..4].* - y.z[idx .. idx + 4][0..4].*;
        rmsd_sum_vec += dx * dx + dy * dy + dz * dz;
    }

    var sum = @reduce(.Add, rmsd_sum_vec);
    while (idx < x.x.len) : (idx += 1) {
        const dx = x.x[idx] - y.x[idx];
        const dy = x.y[idx] - y.y[idx];
        const dz = x.z[idx] - y.z[idx];
        sum += dx * dx + dy * dy + dz * dz;
    }
    return @sqrt(sum / @as(f64, @floatFromInt(x.x.len)));
}

pub fn distances(x: CoordinateSet, y: CoordinateSet, out: []f64) void {
    std.debug.assert(x.x.len == y.x.len);
    std.debug.assert(out.len == x.x.len);
    var idx: usize = 0;
    while (idx + 4 <= x.x.len) : (idx += 4) {
        const dx = x.x[idx .. idx + 4][0..4].* - y.x[idx .. idx + 4][0..4].*;
        const dy = x.y[idx .. idx + 4][0..4].* - y.y[idx .. idx + 4][0..4].*;
        const dz = x.z[idx .. idx + 4][0..4].* - y.z[idx .. idx + 4][0..4].*;
        const dist2 = dx * dx + dy * dy + dz * dz;
        const dist = @sqrt(dist2);
        out[idx .. idx + 4][0..4].* = dist;
    }
    while (idx < x.x.len) : (idx += 1) {
        const dx = x.x[idx] - y.x[idx];
        const dy = x.y[idx] - y.y[idx];
        const dz = x.z[idx] - y.z[idx];
        out[idx] = @sqrt(dx * dx + dy * dy + dz * dz);
    }
}

/// Computes the pairwise distance matrix between sets x and y.
/// out should be a flat slice of length x.len * y.len.
/// It is computed row-by-row, i.e., out[i * y.len + j] = distance(x[i], y[j]).
pub fn pairwiseDistances(x: CoordinateSet, y: CoordinateSet, out: []f64) void {
    std.debug.assert(out.len == x.x.len * y.x.len);
    for (0..x.x.len) |i| {
        const px = @as(@Vector(4, f64), @splat(x.x[i]));
        const py = @as(@Vector(4, f64), @splat(x.y[i]));
        const pz = @as(@Vector(4, f64), @splat(x.z[i]));

        var j: usize = 0;
        const out_row = out[i * y.x.len .. (i + 1) * y.x.len];
        while (j + 4 <= y.x.len) : (j += 4) {
            const dx = px - y.x[j .. j + 4][0..4].*;
            const dy = py - y.y[j .. j + 4][0..4].*;
            const dz = pz - y.z[j .. j + 4][0..4].*;
            const dist2 = dx * dx + dy * dy + dz * dz;
            const dist = @sqrt(dist2);
            out_row[j .. j + 4][0..4].* = dist;
        }
        while (j < y.x.len) : (j += 1) {
            const dx = x.x[i] - y.x[j];
            const dy = x.y[i] - y.y[j];
            const dz = x.z[i] - y.z[j];
            out_row[j] = @sqrt(dx * dx + dy * dy + dz * dz);
        }
    }
}
