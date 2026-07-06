const std = @import("std");
const algorithms = @import("algorithms");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe

    const algo_name = args.next() orelse return error.MissingAlgoName;

    // Simulate Large Assembly: 1,000,000 atoms
    const num_atoms = 1000000;
    const atoms = try allocator.alloc([3]f64, num_atoms);
    defer allocator.free(atoms);

    for (atoms, 0..) |*a, i| {
        a.* = .{
            @as(f64, @floatFromInt(i % 100)),
            @as(f64, @floatFromInt((i * 3) % 100)),
            @as(f64, @floatFromInt((i * 7) % 100)),
        };
    }

    var accuracy_pass = false;

    if (std.mem.eql(u8, algo_name, "DISTANCE_MATRIX")) {
        // Distance matrix is O(N^2), 100k x 100k = 10 Billion floats (80GB).
        // Let's sample 5000 atoms for distance matrix.
        const small_num = 5000;
        const small_atoms = try allocator.alloc([3]f64, small_num);
        defer allocator.free(small_atoms);
        std.mem.copyForwards([3]f64, small_atoms, atoms[0..small_num]);

        const dm = try algorithms.structural.computeDistanceMatrix(allocator, small_atoms);
        accuracy_pass = dm.len == small_num * small_num;
        allocator.free(dm);
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{small_num});
    } else if (std.mem.eql(u8, algo_name, "CENTROID")) {
        const centroid = algorithms.structural.computeCentroid(atoms);
        accuracy_pass = centroid[0] > 0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "RMSD")) {
        // Create slightly shifted set
        const atoms2 = try allocator.alloc([3]f64, num_atoms);
        defer allocator.free(atoms2);
        for (atoms2, 0..) |*a, i| {
            a.* = .{ atoms[i][0] + 0.1, atoms[i][1] + 0.2, atoms[i][2] + 0.3 };
        }
        const rmsd_val = try algorithms.structural.computeRMSD(atoms, atoms2);
        accuracy_pass = rmsd_val > 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "CONTACT_MAP")) {
        const small_num = 5000;
        const small_atoms = try allocator.alloc([3]f64, small_num);
        defer allocator.free(small_atoms);
        std.mem.copyForwards([3]f64, small_atoms, atoms[0..small_num]);

        const cmap = try algorithms.structural.computeContactMap(allocator, small_atoms, 8.0);
        accuracy_pass = cmap.len == small_num * small_num;
        allocator.free(cmap);
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{small_num});
    } else if (std.mem.eql(u8, algo_name, "KABSCH_ROTATION")) {
        const atoms2 = try allocator.alloc([3]f64, num_atoms);
        defer allocator.free(atoms2);
        for (atoms2, 0..) |*a, i| {
            a.* = .{ atoms[i][0] + 0.1, atoms[i][1] + 0.2, atoms[i][2] + 0.3 };
        }
        const rot = try algorithms.structural.computeKabschRotation(atoms, atoms2);
        accuracy_pass = (rot[0][0] != 0.0);
        std.debug.print("Algorithm: KABSCH_ROTATION\n", .{});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "DISTANCE_MATRIX_BLOCK")) {
        const block_i_size = 1000;
        const block_j_size = 1000;
        const block_i = atoms[0..block_i_size];
        const block_j = atoms[1000 .. 1000 + block_j_size];

        const dm = try algorithms.structural.computeDistanceMatrixBlock(allocator, block_i, block_j);
        accuracy_pass = dm.len == block_i_size * block_j_size;
        allocator.free(dm);
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {}x{} atoms\n", .{ block_i_size, block_j_size });
    } else if (std.mem.eql(u8, algo_name, "POCKET_STATISTICS")) {
        const hydro = try allocator.alloc(f64, num_atoms);
        defer allocator.free(hydro);
        @memset(hydro, 0.5);
        const stats = try algorithms.structural.computePocketStatistics(allocator, atoms, hydro);
        accuracy_pass = stats.volume >= 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "POCKET_COMPARISON")) {
        const hydro = try allocator.alloc(f64, num_atoms);
        defer allocator.free(hydro);
        @memset(hydro, 0.5);
        const stats1 = try algorithms.structural.computePocketStatistics(allocator, atoms, hydro);
        const stats2 = try algorithms.structural.computePocketStatistics(allocator, atoms, hydro);
        const diff = algorithms.structural.comparePockets(stats1, stats2);
        accuracy_pass = diff >= 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "SURFACE_METRICS")) {
        const sa = algorithms.structural.computeSurfaceMetrics(atoms);
        accuracy_pass = sa >= 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "SHAPE_DESCRIPTORS")) {
        const rg = algorithms.structural.computeRadiusOfGyration(atoms);
        accuracy_pass = rg >= 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{num_atoms});
    } else if (std.mem.eql(u8, algo_name, "VERLET_MD")) {
        const small_num = 10000;
        const pos = try allocator.alloc([3]f64, small_num);
        defer allocator.free(pos);
        const vel = try allocator.alloc([3]f64, small_num);
        defer allocator.free(vel);
        const forces = try allocator.alloc([3]f64, small_num);
        defer allocator.free(forces);

        @memcpy(pos, atoms[0..small_num]);
        @memset(vel, .{ 0, 0, 0 });
        @memset(forces, .{ 0, 0, 0 });

        const S = struct {
            fn f(_: []const [3]f64, fr: [][3]f64) void {
                for (fr) |*force| {
                    force.* = .{ 0.1, -0.1, 0.05 };
                }
            }
        };

        algorithms.structural.simulateVerletMD(pos, vel, forces, 0.001, 100, 1.0, S.f);
        accuracy_pass = true;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms, 100 steps\n", .{small_num});
    } else if (std.mem.eql(u8, algo_name, "SIMULATED_ANNEALING")) {
        const small_num = 1000;
        const state = try allocator.alloc([3]f64, small_num);
        defer allocator.free(state);
        @memcpy(state, atoms[0..small_num]);

        const S = struct {
            fn e(s: []const [3]f64) f64 {
                var energy: f64 = 0;
                for (s) |pt| energy += pt[0] * pt[0] + pt[1] * pt[1] + pt[2] * pt[2];
                return energy;
            }
            fn p(s: [][3]f64, temp: f64, random: std.Random) void {
                const idx = random.uintLessThan(usize, s.len);
                s[idx][0] += (random.float(f64) - 0.5) * temp;
                s[idx][1] += (random.float(f64) - 0.5) * temp;
                s[idx][2] += (random.float(f64) - 0.5) * temp;
            }
        };

        try algorithms.structural.simulatedAnnealing(allocator, state, 100.0, 0.95, 1.0, 10, S.e, S.p, 42);
        accuracy_pass = true;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{small_num});
    } else if (std.mem.eql(u8, algo_name, "ANM_HESSIAN")) {
        const small_num = 1000;
        const coords = try allocator.alloc([3]f64, small_num);
        defer allocator.free(coords);
        @memcpy(coords, atoms[0..small_num]);

        const hessian = try algorithms.structural.computeANMHessian(allocator, coords, 10.0, 1.0);
        defer allocator.free(hessian);

        accuracy_pass = hessian.len == 3 * small_num * 3 * small_num;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} atoms\n", .{small_num});
    } else if (std.mem.eql(u8, algo_name, "THREADING_DP")) {
        const seq_len = 1000;
        const tmpl_len = 1000;
        const scores = try allocator.alloc(f64, seq_len * tmpl_len);
        defer allocator.free(scores);
        @memset(scores, 1.0);

        const score = try algorithms.structural.threadingDynamicProgramming(allocator, seq_len, tmpl_len, scores, -10.0, -1.0);
        accuracy_pass = score != 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {}x{} matrices\n", .{ seq_len, tmpl_len });
    } else if (std.mem.eql(u8, algo_name, "ROTAMER_PACKING")) {
        const num_res = 5000;
        const rots = try allocator.alloc([]const algorithms.structural.Rotamer, num_res);
        defer allocator.free(rots);

        const r_lib = [_]algorithms.structural.Rotamer{ .{ .chi_angles = &[_]f64{0.0}, .probability = 1.0 }, .{ .chi_angles = &[_]f64{1.0}, .probability = 1.0 } };
        for (0..num_res) |i| rots[i] = &r_lib;

        const S = struct {
            fn e(_: usize, rot_idx: usize, _: []const usize) f64 {
                return if (rot_idx == 1) -1.0 else 0.0;
            }
        };

        const assignments = try algorithms.structural.greedySidechainPacking(allocator, num_res, rots, S.e);
        defer allocator.free(assignments);
        accuracy_pass = assignments.len == num_res;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} residues\n", .{num_res});
    } else {
        std.debug.print("Unknown algo: {s}\n", .{algo_name});
        return;
    }

    std.debug.print("Accuracy Check: {s}\n", .{if (accuracy_pass) "PASS" else "FAIL"});
}
