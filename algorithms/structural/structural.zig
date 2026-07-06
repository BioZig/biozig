const std = @import("std");

/// 3D Coordinate
pub const Vec3 = [3]f64;

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

/// Computes the Euclidean distance between two 3D coordinates.
pub fn distance(a: Vec3, b: Vec3) f64 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Generates a pairwise distance matrix between all points.
pub fn computeDistanceMatrix(allocator: std.mem.Allocator, points: CoordinateSet) ![]f64 {
    const n = points.x.len;
    var matrix = try allocator.alloc(f64, n * n);
    
    for (0..n) |i| {
        matrix[i * n + i] = 0.0;
        var j: usize = i + 1;
        
        while (j + 4 <= n) : (j += 4) {
            const px = @as(@Vector(4, f64), @splat(points.x[i]));
            const py = @as(@Vector(4, f64), @splat(points.y[i]));
            const pz = @as(@Vector(4, f64), @splat(points.z[i]));

            const bx: @Vector(4, f64) = points.x[j .. j + 4][0..4].*;
            const by: @Vector(4, f64) = points.y[j .. j + 4][0..4].*;
            const bz: @Vector(4, f64) = points.z[j .. j + 4][0..4].*;

            const dx = px - bx;
            const dy = py - by;
            const dz = pz - bz;

            const dist2 = dx * dx + dy * dy + dz * dz;
            const dists = @sqrt(dist2);

            matrix[i * n + j] = dists[0];
            matrix[i * n + j + 1] = dists[1];
            matrix[i * n + j + 2] = dists[2];
            matrix[i * n + j + 3] = dists[3];

            matrix[j * n + i] = dists[0];
            matrix[(j + 1) * n + i] = dists[1];
            matrix[(j + 2) * n + i] = dists[2];
            matrix[(j + 3) * n + i] = dists[3];
        }
        
        while (j < n) : (j += 1) {
            const dist = distance(.{points.x[i], points.y[i], points.z[i]}, .{points.x[j], points.y[j], points.z[j]});
            matrix[i * n + j] = dist;
            matrix[j * n + i] = dist;
        }
    }
    return matrix;
}

pub fn computeDistanceMatrixBlock(allocator: std.mem.Allocator, points_i: []const Vec3, points_j: []const Vec3) ![]f64 {
    const ni = points_i.len;
    const nj = points_j.len;
    var matrix = try allocator.alloc(f64, ni * nj);
    
    for (0..ni) |i| {
        for (0..nj) |j| {
            matrix[i * nj + j] = distance(points_i[i], points_j[j]);
        }
    }
    return matrix;
}

/// A boolean contact map using a Uniform Spatial Grid (Cell Grid) to avoid O(N^2) distance checks.
pub fn computeContactMap(allocator: std.mem.Allocator, points: []const Vec3, threshold: f64) ![]bool {
    const n = points.len;
    var matrix = try allocator.alloc(bool, n * n);
    @memset(matrix, false);

    const Cell = struct { x: i32, y: i32, z: i32 };
    
    var map = std.AutoHashMap(Cell, std.ArrayList(usize)).init(allocator);
    defer {
        var it = map.valueIterator();
        while (it.next()) |list| {
            list.deinit(allocator);
        }
        map.deinit();
    }

    const cell_size = if (threshold > 0) threshold else 1.0;
    for (points, 0..) |p, i| {
        const c = Cell{
            .x = @as(i32, @intFromFloat(@floor(p[0] / cell_size))),
            .y = @as(i32, @intFromFloat(@floor(p[1] / cell_size))),
            .z = @as(i32, @intFromFloat(@floor(p[2] / cell_size))),
        };
        const entry = try map.getOrPut(c);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(usize).empty;
        }
        try entry.value_ptr.append(allocator, i);
    }

    for (0..n) |i| {
        matrix[i * n + i] = true;
    }

    var it = map.iterator();
    while (it.next()) |entry| {
        const c = entry.key_ptr.*;
        const indices = entry.value_ptr.items;

        var dx: i32 = -1;
        while (dx <= 1) : (dx += 1) {
            var dy: i32 = -1;
            while (dy <= 1) : (dy += 1) {
                var dz: i32 = -1;
                while (dz <= 1) : (dz += 1) {
                    const nc = Cell{ .x = c.x + dx, .y = c.y + dy, .z = c.z + dz };
                    if (map.getPtr(nc)) |n_indices| {
                        for (indices) |i| {
                            for (n_indices.items) |j| {
                                if (i < j) {
                                    if (distance(points[i], points[j]) <= threshold) {
                                        matrix[i * n + j] = true;
                                        matrix[j * n + i] = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return matrix;
}

pub fn computeRMSD(a: CoordinateSet, b: CoordinateSet) !f64 {
    if (a.x.len != b.x.len) return error.LengthMismatch;
    if (a.x.len == 0) return 0.0;

    var sum_sq_vec: @Vector(4, f64) = @splat(0.0);
    var i: usize = 0;
    while (i + 4 <= a.x.len) : (i += 4) {
        const ax: @Vector(4, f64) = a.x[i .. i + 4][0..4].*;
        const ay: @Vector(4, f64) = a.y[i .. i + 4][0..4].*;
        const az: @Vector(4, f64) = a.z[i .. i + 4][0..4].*;

        const bx: @Vector(4, f64) = b.x[i .. i + 4][0..4].*;
        const by: @Vector(4, f64) = b.y[i .. i + 4][0..4].*;
        const bz: @Vector(4, f64) = b.z[i .. i + 4][0..4].*;

        const dx = ax - bx;
        const dy = ay - by;
        const dz = az - bz;

        sum_sq_vec += dx * dx + dy * dy + dz * dz;
    }

    var sum_sq = @reduce(.Add, sum_sq_vec);
    while (i < a.x.len) : (i += 1) {
        const dx = a.x[i] - b.x[i];
        const dy = a.y[i] - b.y[i];
        const dz = a.z[i] - b.z[i];
        sum_sq += (dx * dx + dy * dy + dz * dz);
    }

    return @sqrt(sum_sq / @as(f64, @floatFromInt(a.x.len)));
}

pub fn computeCentroid(points: CoordinateSet) Vec3 {
    if (points.x.len == 0) return .{ 0, 0, 0 };
    
    var sum_x_vec: @Vector(4, f64) = @splat(0.0);
    var sum_y_vec: @Vector(4, f64) = @splat(0.0);
    var sum_z_vec: @Vector(4, f64) = @splat(0.0);
    
    var i: usize = 0;
    while (i + 4 <= points.x.len) : (i += 4) {
        sum_x_vec += points.x[i .. i + 4][0..4].*;
        sum_y_vec += points.y[i .. i + 4][0..4].*;
        sum_z_vec += points.z[i .. i + 4][0..4].*;
    }
    
    var cx = @reduce(.Add, sum_x_vec);
    var cy = @reduce(.Add, sum_y_vec);
    var cz = @reduce(.Add, sum_z_vec);
    
    while (i < points.x.len) : (i += 1) {
        cx += points.x[i];
        cy += points.y[i];
        cz += points.z[i];
    }
    
    const n = @as(f64, @floatFromInt(points.x.len));
    return .{ cx / n, cy / n, cz / n };
}

pub fn centerPoints(points: CoordinateSetMut) void {
    const c = computeCentroid(.{ .x = points.x, .y = points.y, .z = points.z });
    for (0..points.x.len) |i| {
        points.x[i] -= c[0];
        points.y[i] -= c[1];
        points.z[i] -= c[2];
    }
}

pub const RotationMatrix = [3][3]f64;

/// Quaternion Kabsch algorithm for exact rigid alignment.
pub fn computeKabschRotation(a: CoordinateSet, b: CoordinateSet) !RotationMatrix {
    if (a.x.len != b.x.len) return error.LengthMismatch;

    var cov = [_][3]f64{
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    };

    var cov_idx: usize = 0;
    while (cov_idx + 4 <= a.x.len) : (cov_idx += 4) {
        const ax: @Vector(4, f64) = a.x[cov_idx .. cov_idx + 4][0..4].*;
        const ay: @Vector(4, f64) = a.y[cov_idx .. cov_idx + 4][0..4].*;
        const az: @Vector(4, f64) = a.z[cov_idx .. cov_idx + 4][0..4].*;
        const bx: @Vector(4, f64) = b.x[cov_idx .. cov_idx + 4][0..4].*;
        const by: @Vector(4, f64) = b.y[cov_idx .. cov_idx + 4][0..4].*;
        const bz: @Vector(4, f64) = b.z[cov_idx .. cov_idx + 4][0..4].*;
        
        cov[0][0] += @reduce(.Add, ax * bx);
        cov[0][1] += @reduce(.Add, ax * by);
        cov[0][2] += @reduce(.Add, ax * bz);
        cov[1][0] += @reduce(.Add, ay * bx);
        cov[1][1] += @reduce(.Add, ay * by);
        cov[1][2] += @reduce(.Add, ay * bz);
        cov[2][0] += @reduce(.Add, az * bx);
        cov[2][1] += @reduce(.Add, az * by);
        cov[2][2] += @reduce(.Add, az * bz);
    }
    
    while (cov_idx < a.x.len) : (cov_idx += 1) {
        cov[0][0] += a.x[cov_idx] * b.x[cov_idx];
        cov[0][1] += a.x[cov_idx] * b.y[cov_idx];
        cov[0][2] += a.x[cov_idx] * b.z[cov_idx];
        cov[1][0] += a.y[cov_idx] * b.x[cov_idx];
        cov[1][1] += a.y[cov_idx] * b.y[cov_idx];
        cov[1][2] += a.y[cov_idx] * b.z[cov_idx];
        cov[2][0] += a.z[cov_idx] * b.x[cov_idx];
        cov[2][1] += a.z[cov_idx] * b.y[cov_idx];
        cov[2][2] += a.z[cov_idx] * b.z[cov_idx];
    }

    const K = [_][4]f64{
        .{ cov[0][0] + cov[1][1] + cov[2][2] + 10.0, cov[1][2] - cov[2][1], cov[2][0] - cov[0][2], cov[0][1] - cov[1][0] },
        .{ cov[1][2] - cov[2][1], cov[0][0] - cov[1][1] - cov[2][2] + 10.0, cov[0][1] + cov[1][0], cov[2][0] + cov[0][2] },
        .{ cov[2][0] - cov[0][2], cov[0][1] + cov[1][0], cov[1][1] - cov[0][0] - cov[2][2] + 10.0, cov[1][2] + cov[2][1] },
        .{ cov[0][1] - cov[1][0], cov[2][0] + cov[0][2], cov[1][2] + cov[2][1], cov[2][2] - cov[0][0] - cov[1][1] + 10.0 },
    };

    var q = [_]f64{ 1.0, 0.0, 0.0, 0.0 };
    for (0..50) |_| {
        var next_q = [_]f64{ 0.0, 0.0, 0.0, 0.0 };
        for (0..4) |i| {
            for (0..4) |j| {
                next_q[i] += K[i][j] * q[j];
            }
        }
        var norm: f64 = 0;
        for (0..4) |i| norm += next_q[i] * next_q[i];
        norm = @sqrt(norm);
        if (norm > 1e-12) {
            for (0..4) |i| next_q[i] /= norm;
        }
        q = next_q;
    }

    const q0 = q[0];
    const q1 = q[1];
    const q2 = q[2];
    const q3 = q[3];

    return [_][3]f64{
        .{ q0*q0 + q1*q1 - q2*q2 - q3*q3, 2*(q1*q2 - q0*q3), 2*(q1*q3 + q0*q2) },
        .{ 2*(q1*q2 + q0*q3), q0*q0 - q1*q1 + q2*q2 - q3*q3, 2*(q2*q3 - q0*q1) },
        .{ 2*(q1*q3 - q0*q2), 2*(q2*q3 + q0*q1), q0*q0 - q1*q1 - q2*q2 + q3*q3 },
    };
}

/// Computes the optimal RMSD after superposition using Kabsch
pub fn computeOptimalRMSD(allocator: std.mem.Allocator, a: CoordinateSet, b: CoordinateSet) !f64 {
    if (a.x.len != b.x.len) return error.LengthMismatch;
    if (a.x.len == 0) return 0.0;

    var a_centered = try CoordinateSetMut.init(allocator, a.x.len);
    defer a_centered.deinit(allocator);
    @memcpy(a_centered.x, a.x);
    @memcpy(a_centered.y, a.y);
    @memcpy(a_centered.z, a.z);
    centerPoints(a_centered);

    var b_centered = try CoordinateSetMut.init(allocator, b.x.len);
    defer b_centered.deinit(allocator);
    @memcpy(b_centered.x, b.x);
    @memcpy(b_centered.y, b.y);
    @memcpy(b_centered.z, b.z);
    centerPoints(b_centered);

    const R = try computeKabschRotation(.{ .x = a_centered.x, .y = a_centered.y, .z = a_centered.z }, .{ .x = b_centered.x, .y = b_centered.y, .z = b_centered.z });

    var sum_sq: f64 = 0;
    for (0..a.x.len) |i| {
        const p1x = a_centered.x[i];
        const p1y = a_centered.y[i];
        const p1z = a_centered.z[i];
        
        const rx = R[0][0]*p1x + R[0][1]*p1y + R[0][2]*p1z;
        const ry = R[1][0]*p1x + R[1][1]*p1y + R[1][2]*p1z;
        const rz = R[2][0]*p1x + R[2][1]*p1y + R[2][2]*p1z;

        const dx = rx - b_centered.x[i];
        const dy = ry - b_centered.y[i];
        const dz = rz - b_centered.z[i];
        
        sum_sq += (dx*dx + dy*dy + dz*dz);
    }

    return @sqrt(sum_sq / @as(f64, @floatFromInt(a.x.len)));
}

pub const HydrogenBond = struct {
    donor_idx: usize,
    acceptor_idx: usize,
    distance: f64,
};

pub fn detectHydrogenBonds(allocator: std.mem.Allocator, donors: []const Vec3, acceptors: []const Vec3, max_dist: f64) ![]HydrogenBond {
    var hbonds = std.ArrayList(HydrogenBond).empty;
    errdefer hbonds.deinit(allocator);

    for (donors, 0..) |d, i| {
        for (acceptors, 0..) |a, j| {
            const dist = distance(d, a);
            if (dist <= max_dist) {
                try hbonds.append(allocator, .{ .donor_idx = i, .acceptor_idx = j, .distance = dist });
            }
        }
    }

    return hbonds.toOwnedSlice(allocator);
}

pub const PocketStatistics = struct {
    volume: f64,
    surface_area: f64,
    hydrophobicity: f64,
};

/// Voronoi-based (Grid approximation) pocket volume and residue-derived hydrophobicity.
pub fn computePocketStatistics(allocator: std.mem.Allocator, points: []const Vec3, atom_hydrophobicities: []const f64) !PocketStatistics {
    if (points.len == 0) return .{ .volume = 0, .surface_area = 0, .hydrophobicity = 0 };
    if (points.len != atom_hydrophobicities.len) return error.LengthMismatch;

    var min_p = points[0];
    var max_p = points[0];
    for (points) |p| {
        for (0..3) |i| {
            if (p[i] < min_p[i]) min_p[i] = p[i];
            if (p[i] > max_p[i]) max_p[i] = p[i];
        }
    }

    const padding = 2.0;
    min_p[0] -= padding; min_p[1] -= padding; min_p[2] -= padding;
    max_p[0] += padding; max_p[1] += padding; max_p[2] += padding;

    const grid_spacing = 0.5;
    const grid_vol = grid_spacing * grid_spacing * grid_spacing;

    const nx = @as(usize, @intFromFloat((max_p[0] - min_p[0]) / grid_spacing)) + 1;
    const ny = @as(usize, @intFromFloat((max_p[1] - min_p[1]) / grid_spacing)) + 1;
    const nz = @as(usize, @intFromFloat((max_p[2] - min_p[2]) / grid_spacing)) + 1;

    var vol: f64 = 0;
    var total_hydro: f64 = 0;
    var surface_area_approx: f64 = 0;

    var atom_volumes = try allocator.alloc(f64, points.len);
    defer allocator.free(atom_volumes);
    @memset(atom_volumes, 0.0);

    const radius = 2.0;

    for (0..nx) |ix| {
        const x = min_p[0] + @as(f64, @floatFromInt(ix)) * grid_spacing;
        for (0..ny) |iy| {
            const y = min_p[1] + @as(f64, @floatFromInt(iy)) * grid_spacing;
            for (0..nz) |iz| {
                const z = min_p[2] + @as(f64, @floatFromInt(iz)) * grid_spacing;

                var min_dist_sq: f64 = std.math.floatMax(f64);
                var nearest_idx: usize = 0;

                for (points, 0..) |p, idx| {
                    const dx = p[0] - x;
                    const dy = p[1] - y;
                    const dz = p[2] - z;
                    const d_sq = dx*dx + dy*dy + dz*dz;
                    if (d_sq < min_dist_sq) {
                        min_dist_sq = d_sq;
                        nearest_idx = idx;
                    }
                }

                if (min_dist_sq <= radius * radius) {
                    atom_volumes[nearest_idx] += grid_vol;
                    vol += grid_vol;
                    
                    const dist = @sqrt(min_dist_sq);
                    if (dist > radius - grid_spacing) {
                        surface_area_approx += grid_spacing * grid_spacing;
                    }
                }
            }
        }
    }

    for (0..points.len) |i| {
        total_hydro += atom_volumes[i] * atom_hydrophobicities[i];
    }

    var avg_hydro: f64 = 0;
    if (vol > 0) {
        avg_hydro = total_hydro / vol;
    }

    return .{
        .volume = vol,
        .surface_area = surface_area_approx,
        .hydrophobicity = avg_hydro,
    };
}

pub fn comparePockets(a: PocketStatistics, b: PocketStatistics) f64 {
    const d_vol = a.volume - b.volume;
    const d_sa = a.surface_area - b.surface_area;
    const d_hyd = a.hydrophobicity - b.hydrophobicity;
    return @sqrt(d_vol * d_vol + d_sa * d_sa + d_hyd * d_hyd);
}

pub fn computeSurfaceMetrics(points: []const Vec3) f64 {
    if (points.len == 0) return 0.0;
    var min_p = points[0];
    var max_p = points[0];

    for (points) |p| {
        for (0..3) |i| {
            if (p[i] < min_p[i]) min_p[i] = p[i];
            if (p[i] > max_p[i]) max_p[i] = p[i];
        }
    }

    const dx = max_p[0] - min_p[0];
    const dy = max_p[1] - min_p[1];
    const dz = max_p[2] - min_p[2];
    
    return 2.0 * (dx * dy + dy * dz + dz * dx);
}

pub fn computeRadiusOfGyration(points: CoordinateSet) f64 {
    if (points.x.len == 0) return 0.0;
    const centroid = computeCentroid(points);
    var sum_sq: f64 = 0.0;
    for (0..points.x.len) |i| {
        const dx = points.x[i] - centroid[0];
        const dy = points.y[i] - centroid[1];
        const dz = points.z[i] - centroid[2];
        sum_sq += (dx * dx + dy * dy + dz * dz);
    }
    return @sqrt(sum_sq / @as(f64, @floatFromInt(points.x.len)));
}

// ============================================================================
// Molecular Dynamics (Verlet integration)
// ============================================================================

pub fn simulateVerletMD(
    positions: []Vec3,
    velocities: []Vec3,
    forces: []Vec3,
    dt: f64,
    num_steps: usize,
    mass: f64,
    computeForces: *const fn (pos: []const Vec3, f: []Vec3) void,
) void {
    const dt_sq_over_2m = (dt * dt) / (2.0 * mass);
    const dt_over_2m = dt / (2.0 * mass);

    computeForces(positions, forces);

    for (0..num_steps) |_| {
        for (positions, 0..) |*p, i| {
            p.*[0] += velocities[i][0] * dt + forces[i][0] * dt_sq_over_2m;
            p.*[1] += velocities[i][1] * dt + forces[i][1] * dt_sq_over_2m;
            p.*[2] += velocities[i][2] * dt + forces[i][2] * dt_sq_over_2m;
            
            velocities[i][0] += forces[i][0] * dt_over_2m;
            velocities[i][1] += forces[i][1] * dt_over_2m;
            velocities[i][2] += forces[i][2] * dt_over_2m;
        }

        computeForces(positions, forces);

        for (velocities, 0..) |*v, i| {
            v.*[0] += forces[i][0] * dt_over_2m;
            v.*[1] += forces[i][1] * dt_over_2m;
            v.*[2] += forces[i][2] * dt_over_2m;
        }
    }
}

// ============================================================================
// Monte Carlo / Simulated Annealing
// ============================================================================

pub fn simulatedAnnealing(
    allocator: std.mem.Allocator,
    state: []Vec3,
    initial_temp: f64,
    cooling_rate: f64,
    min_temp: f64,
    steps_per_temp: usize,
    computeEnergy: *const fn (s: []const Vec3) f64,
    perturbState: *const fn (s: []Vec3, temp: f64, random: std.Random) void,
    seed: u64,
) !void {
    var prng = std.Random.Pcg.init(seed);
    const random = prng.random();

    var temp = initial_temp;
    var current_energy = computeEnergy(state);
    
    const backup_state = try allocator.alloc(Vec3, state.len);
    defer allocator.free(backup_state);

    while (temp > min_temp) {
        for (0..steps_per_temp) |_| {
            @memcpy(backup_state, state);
            perturbState(state, temp, random);
            const new_energy = computeEnergy(state);
            
            const delta_e = new_energy - current_energy;
            if (delta_e < 0.0) {
                current_energy = new_energy;
            } else {
                const p = std.math.exp(-delta_e / temp);
                if (random.float(f64) < p) {
                    current_energy = new_energy;
                } else {
                    @memcpy(state, backup_state);
                }
            }
        }
        temp *= cooling_rate;
    }
}

// ============================================================================
// Elastic Network Models (Normal Mode Analysis)
// ============================================================================

pub fn computeANMHessian(allocator: std.mem.Allocator, coords: []const Vec3, cutoff: f64, gamma: f64) ![]f64 {
    const n = coords.len;
    var hessian = try allocator.alloc(f64, 3 * n * 3 * n);
    @memset(hessian, 0.0);

    for (0..n) |i| {
        for (i + 1..n) |j| {
            const dx = coords[j][0] - coords[i][0];
            const dy = coords[j][1] - coords[i][1];
            const dz = coords[j][2] - coords[i][2];
            const dist_sq = dx*dx + dy*dy + dz*dz;
            
            if (dist_sq <= cutoff * cutoff and dist_sq > 0.0) {
                const H_ij = [_][3]f64{
                    .{ -gamma * dx * dx / dist_sq, -gamma * dx * dy / dist_sq, -gamma * dx * dz / dist_sq },
                    .{ -gamma * dy * dx / dist_sq, -gamma * dy * dy / dist_sq, -gamma * dy * dz / dist_sq },
                    .{ -gamma * dz * dx / dist_sq, -gamma * dz * dy / dist_sq, -gamma * dz * dz / dist_sq },
                };
                
                for (0..3) |d1| {
                    for (0..3) |d2| {
                        hessian[(3*i + d1) * (3*n) + (3*j + d2)] = H_ij[d1][d2];
                        hessian[(3*j + d1) * (3*n) + (3*i + d2)] = H_ij[d1][d2];
                        
                        hessian[(3*i + d1) * (3*n) + (3*i + d2)] -= H_ij[d1][d2];
                        hessian[(3*j + d1) * (3*n) + (3*j + d2)] -= H_ij[d1][d2];
                    }
                }
            }
        }
    }
    return hessian;
}

// ============================================================================
// Threading / Fold Recognition (Dynamic Programming on structures)
// ============================================================================

pub fn threadingDynamicProgramming(allocator: std.mem.Allocator, seq_len: usize, template_len: usize, structural_scores: []const f64, gap_open: f64, gap_extend: f64) !f64 {
    var dp_M = try allocator.alloc(f64, (seq_len + 1) * (template_len + 1));
    defer allocator.free(dp_M);
    var dp_X = try allocator.alloc(f64, (seq_len + 1) * (template_len + 1));
    defer allocator.free(dp_X);
    var dp_Y = try allocator.alloc(f64, (seq_len + 1) * (template_len + 1));
    defer allocator.free(dp_Y);

    const MIN_SCORE = -1e9;
    @memset(dp_M, MIN_SCORE);
    @memset(dp_X, MIN_SCORE);
    @memset(dp_Y, MIN_SCORE);

    dp_M[0] = 0.0;
    
    for (1..seq_len + 1) |i| {
        dp_X[i * (template_len + 1)] = gap_open + @as(f64, @floatFromInt(i - 1)) * gap_extend;
    }
    for (1..template_len + 1) |j| {
        dp_Y[j] = gap_open + @as(f64, @floatFromInt(j - 1)) * gap_extend;
    }

    for (1..seq_len + 1) |i| {
        for (1..template_len + 1) |j| {
            const score_idx = (i - 1) * template_len + (j - 1);
            const s = structural_scores[score_idx];
            
            const M_idx = i * (template_len + 1) + j;
            const M_prev = (i - 1) * (template_len + 1) + (j - 1);
            
            dp_M[M_idx] = s + @max(dp_M[M_prev], @max(dp_X[M_prev], dp_Y[M_prev]));
            
            const X_prev = (i - 1) * (template_len + 1) + j;
            dp_X[M_idx] = @max(dp_M[X_prev] + gap_open, dp_X[X_prev] + gap_extend);
            
            const Y_prev = i * (template_len + 1) + (j - 1);
            dp_Y[M_idx] = @max(dp_M[Y_prev] + gap_open, dp_Y[Y_prev] + gap_extend);
        }
    }
    
    const final_idx = seq_len * (template_len + 1) + template_len;
    return @max(dp_M[final_idx], @max(dp_X[final_idx], dp_Y[final_idx]));
}

// ============================================================================
// Rotamer Library Search (Sidechain packing)
// ============================================================================

pub const Rotamer = struct {
    chi_angles: []const f64,
    probability: f64,
};

pub fn greedySidechainPacking(
    allocator: std.mem.Allocator,
    num_residues: usize,
    rotamer_libraries: [][]const Rotamer,
    computeEnergy: *const fn(res_idx: usize, rot_idx: usize, current_assignments: []const usize) f64,
) ![]usize {
    var assignments = try allocator.alloc(usize, num_residues);
    @memset(assignments, 0);

    var improved = true;
    while (improved) {
        improved = false;
        for (0..num_residues) |i| {
            if (rotamer_libraries[i].len == 0) continue;
            var best_rot_idx = assignments[i];
            var best_energy = computeEnergy(i, best_rot_idx, assignments);

            for (0..rotamer_libraries[i].len) |r| {
                if (r == assignments[i]) continue;
                
                const e = computeEnergy(i, r, assignments);
                if (e < best_energy) {
                    best_energy = e;
                    best_rot_idx = r;
                    improved = true;
                }
            }
            assignments[i] = best_rot_idx;
        }
    }
    return assignments;
}

test "Structural Algorithms - Molecular Dynamics" {
    const alloc = std.testing.allocator;
    var pos = try alloc.alloc(Vec3, 2);
    defer alloc.free(pos);
    pos[0] = .{0, 0, 0};
    pos[1] = .{1, 0, 0};
    
    const vel = try alloc.alloc(Vec3, 2);
    defer alloc.free(vel);
    @memset(vel, .{0, 0, 0});
    
    const forces = try alloc.alloc(Vec3, 2);
    defer alloc.free(forces);
    @memset(forces, .{0, 0, 0});

    const S = struct {
        fn f(p: []const Vec3, fr: []Vec3) void {
            // Harmonic spring
            const dx = p[1][0] - p[0][0];
            fr[0][0] = dx;
            fr[1][0] = -dx;
        }
    };

    simulateVerletMD(pos, vel, forces, 0.01, 10, 1.0, S.f);
    try std.testing.expect(pos[0][0] != 0.0);
}

test "Structural Algorithms - Simulated Annealing" {
    const alloc = std.testing.allocator;
    var state = try alloc.alloc(Vec3, 1);
    defer alloc.free(state);
    state[0] = .{10, 0, 0};
    
    const S = struct {
        fn e(s: []const Vec3) f64 {
            return s[0][0]*s[0][0] + s[0][1]*s[0][1] + s[0][2]*s[0][2];
        }
        fn p(s: []Vec3, temp: f64, random: std.Random) void {
            s[0][0] += (random.float(f64) - 0.5) * temp;
            s[0][1] += (random.float(f64) - 0.5) * temp;
            s[0][2] += (random.float(f64) - 0.5) * temp;
        }
    };

    try simulatedAnnealing(alloc, state, 10.0, 0.9, 0.1, 10, S.e, S.p, 42);
    try std.testing.expect(S.e(state) < 100.0);
}

test "Structural Algorithms - ANM Hessian" {
    const alloc = std.testing.allocator;
    const coords = [_]Vec3{ .{0,0,0}, .{1,0,0}, .{0,1,0} };
    const H = try computeANMHessian(alloc, &coords, 1.5, 1.0);
    defer alloc.free(H);
    
    try std.testing.expectEqual(@as(usize, 9 * 9), H.len);
    try std.testing.expect(H[0] != 0.0);
}

test "Structural Algorithms - Threading DP" {
    const alloc = std.testing.allocator;
    const scores = [_]f64{ 1.0, -1.0, -1.0, 1.0 }; // 2x2 identity-like
    const score = try threadingDynamicProgramming(alloc, 2, 2, &scores, -2.0, -0.5);
    try std.testing.expectEqual(@as(f64, 2.0), score);
}

test "Structural Algorithms - Rotamer Packing" {
    const alloc = std.testing.allocator;
    var rots = try alloc.alloc([]const Rotamer, 2);
    defer alloc.free(rots);
    const r_lib = [_]Rotamer{ .{ .chi_angles = &[_]f64{0.0}, .probability = 1.0 }, .{ .chi_angles = &[_]f64{1.0}, .probability = 1.0 } };
    rots[0] = &r_lib;
    rots[1] = &r_lib;

    const S = struct {
        fn e(res_idx: usize, rot_idx: usize, curr: []const usize) f64 {
            _ = res_idx;
            _ = curr;
            return if (rot_idx == 1) -10.0 else 0.0;
        }
    };

    const assigned = try greedySidechainPacking(alloc, 2, rots, S.e);
    defer alloc.free(assigned);
    try std.testing.expectEqual(@as(usize, 1), assigned[0]);
    try std.testing.expectEqual(@as(usize, 1), assigned[1]);
}

test "Structural Algorithms - Shape and Surface" {
    const alloc = std.testing.allocator;
    const points = [_]Vec3{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 0, 1 } };
    const hydro = [_]f64{ 0.5, -0.5, 0.2, 0.8 };
    
    var px = [_]f64{ 0, 1, 0, 0 };
    var py = [_]f64{ 0, 0, 1, 0 };
    var pz = [_]f64{ 0, 0, 0, 1 };
    const soa_points = CoordinateSet{ .x = &px, .y = &py, .z = &pz };
    const rg = computeRadiusOfGyration(soa_points);
    try std.testing.expect(rg > 0.0);
    
    const sa = computeSurfaceMetrics(&points);
    try std.testing.expectEqual(@as(f64, 6.0), sa);
    
    const p1 = try computePocketStatistics(alloc, &points, &hydro);
    const p2 = try computePocketStatistics(alloc, &points, &hydro);
    const diff = comparePockets(p1, p2);
    try std.testing.expectEqual(@as(f64, 0.0), diff);
}

test "Structural Algorithms - RMSD and Distance" {
    var ax align(32) = [_]f64{ 0.0, 1.0 };
    var ay align(32) = [_]f64{ 0.0, 0.0 };
    var az align(32) = [_]f64{ 0.0, 0.0 };
    const a = CoordinateSet{ .x = &ax, .y = &ay, .z = &az };

    var bx align(32) = [_]f64{ 0.0, 0.0 };
    var by align(32) = [_]f64{ 0.0, 1.0 };
    var bz align(32) = [_]f64{ 0.0, 0.0 };
    const b = CoordinateSet{ .x = &bx, .y = &by, .z = &bz };

    const rmsd = try computeRMSD(a, b);
    try std.testing.expectEqual(@as(f64, 1.0), rmsd);

    const alloc = std.testing.allocator;
    const dist_mat = try computeDistanceMatrix(alloc, a);
    defer alloc.free(dist_mat);

    try std.testing.expectEqual(@as(f64, 0.0), dist_mat[0]); // 0,0
    try std.testing.expectEqual(@as(f64, 1.0), dist_mat[1]); // 0,1
}

test "Structural Algorithms - Centroid" {
    var x align(32) = [_]f64{ -1, 1, 0 };
    var y align(32) = [_]f64{ 0, 0, 2 };
    var z align(32) = [_]f64{ 0, 0, 0 };
    const points = CoordinateSet{ .x = &x, .y = &y, .z = &z };
    const c = computeCentroid(points);
    try std.testing.expectEqual(@as(f64, 0.0), c[0]);
    try std.testing.expect(c[1] > 0.6 and c[1] < 0.7); // 2/3
}

test "Structural Algorithms - Kabsch Optimal RMSD" {
    
    var ax align(32) = [_]f64{ 0.0, 1.0, 0.0 };
    var ay align(32) = [_]f64{ 0.0, 0.0, 1.0 };
    var az align(32) = [_]f64{ 0.0, 0.0, 0.0 };
    const a = CoordinateSet{ .x = &ax, .y = &ay, .z = &az };

    var bx align(32) = [_]f64{ 0.0, 0.0, -1.0 };
    var by align(32) = [_]f64{ 0.0, 1.0, 0.0 };
    var bz align(32) = [_]f64{ 0.0, 0.0, 0.0 };
    const b = CoordinateSet{ .x = &bx, .y = &by, .z = &bz };

    // Raw RMSD will be non-zero
    const raw_rmsd = try computeRMSD(a, b);
    try std.testing.expect(raw_rmsd > 0.5);

    // Optimal RMSD should be essentially 0
    const alloc = std.testing.allocator;
    const opt_rmsd = try computeOptimalRMSD(alloc, a, b);
    try std.testing.expect(opt_rmsd < 1e-5);
}

test "Structural Algorithms - Contact Map" {
    const alloc = std.testing.allocator;
    const points = [_]Vec3{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 5, 0, 0 } };
    
    const cmap = try computeContactMap(alloc, &points, 2.0);
    defer alloc.free(cmap);
    
    try std.testing.expect(cmap[0*3 + 1] == true); // dist 1 <= 2.0
    try std.testing.expect(cmap[0*3 + 2] == false); // dist 5 > 2.0
}
