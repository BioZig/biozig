const std = @import("std");
const ParsedArgs = @import("args.zig").ParsedArgs;
const structural = @import("structural");
const MMapReader = @import("core").io.mmap.MMapReader;
const output = @import("output.zig");
const algorithms = @import("algorithms");
const ingestion = @import("ingestion");

fn dummyComputeForces(pos: []const algorithms.structural.Vec3, f: []algorithms.structural.Vec3) void {
    _ = pos;
    for (f, 0..) |_, i| f[i] = .{0.0, 0.0, 0.0};
}

fn dummyComputeEnergy(s: []const algorithms.structural.Vec3) f64 {
    _ = s;
    return 0.0;
}

fn dummyPerturbState(s: []algorithms.structural.Vec3, temp: f64, random: std.Random) void {
    _ = s; _ = temp; _ = random;
}

fn dummyRotamerEnergy(res_idx: usize, rot_idx: usize, current_assignments: []const usize) f64 {
    _ = res_idx; _ = rot_idx; _ = current_assignments;
    return 0.0;
}

pub fn execute(args: ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig structural - 3D protein structures and interactions
            \\
            \\Usage:
            \\  biozig structural <command> [options]
            \\
            \\Commands:
            \\  geometry     Structural geometry and RMSD analysis
            \\  contacts     Contact maps and hydrogen bonds
            \\  surfaces     Surface area metrics
            \\  pockets      Pocket statistics and identification
            \\  dynamics     Molecular dynamics (Verlet, Simulated Annealing)
            \\  anm          Elastic Network Models (ANM Hessian)
            \\  threading    Fold recognition / Threading DP
            \\  rotamers     Sidechain packing / Rotamers
            \\  ingestion    Structure parsing (PDB, mmCIF, mol2, sdf, pqr)
            \\
            \\Options:
            \\  -h, --help   Show this help message and exit
            \\  -i, --input  Input structure file (PDB format)
            \\
            , .{}
        );
        return;
    }
    
    if (args.run) |cmd| {
        const in_path = args.input orelse {
            std.debug.print("Error: Command requires an --input file (-i).\n", .{});
            return error.MissingInput;
        };
        
        var reader = try MMapReader.init(std.heap.page_allocator, in_path);
        defer reader.deinit();
        
        var out_writer = output.OutputWriter.init(.text);
        
        // Always parse coordinates for structural tasks to be robust
        const raw_coords = try ingestion.structural.pdb.parsePdbCoords(std.heap.page_allocator, reader.data);
        defer std.heap.page_allocator.free(raw_coords);
        
        var coords_mut = try algorithms.structural.CoordinateSetMut.init(std.heap.page_allocator, raw_coords.len);
        defer coords_mut.deinit(std.heap.page_allocator);
        
        const vec_coords = try std.heap.page_allocator.alloc(algorithms.structural.Vec3, raw_coords.len);
        defer std.heap.page_allocator.free(vec_coords);
        
        for (raw_coords, 0..) |c, i| {
            coords_mut.x[i] = c.x;
            coords_mut.y[i] = c.y;
            coords_mut.z[i] = c.z;
            vec_coords[i] = .{c.x, c.y, c.z};
        }
        const coords = algorithms.structural.CoordinateSet{ .x = coords_mut.x, .y = coords_mut.y, .z = coords_mut.z };

        if (std.mem.eql(u8, cmd, "geometry")) {
            const center = algorithms.structural.computeCentroid(coords);
            const rg = algorithms.structural.computeRadiusOfGyration(coords);
            try out_writer.writeText("Centroid: {d:.4}, {d:.4}, {d:.4}\n", .{center[0], center[1], center[2]});
            try out_writer.writeText("Radius of Gyration: {d:.4}\n", .{rg});
        } else if (std.mem.eql(u8, cmd, "contacts")) {
            const cmap = try algorithms.structural.computeContactMap(std.heap.page_allocator, vec_coords, 8.0);
            defer std.heap.page_allocator.free(cmap);
            
            const hbonds = try algorithms.structural.detectHydrogenBonds(std.heap.page_allocator, vec_coords, vec_coords, 3.5);
            defer std.heap.page_allocator.free(hbonds);
            
            try out_writer.writeText("Computed contact map (size: {}). Found {} potential hydrogen bonds.\n", .{cmap.len, hbonds.len});
        } else if (std.mem.eql(u8, cmd, "surfaces")) {
            const sa = algorithms.structural.computeSurfaceMetrics(vec_coords);
            try out_writer.writeText("Estimated Surface Metrics: {d:.4}\n", .{sa});
        } else if (std.mem.eql(u8, cmd, "pockets")) {
            const hyb = try std.heap.page_allocator.alloc(f64, vec_coords.len);
            defer std.heap.page_allocator.free(hyb);
            @memset(hyb, 0.5); // Dummy hydrophobicity
            const pocket = try algorithms.structural.computePocketStatistics(std.heap.page_allocator, vec_coords, hyb);
            try out_writer.writeText("Pocket - Volume: {d:.4}, SA: {d:.4}, Hydrophobicity: {d:.4}\n", .{pocket.volume, pocket.surface_area, pocket.hydrophobicity});
        } else if (std.mem.eql(u8, cmd, "dynamics")) {
            // Verlet MD
            var vels = try std.heap.page_allocator.alloc(algorithms.structural.Vec3, vec_coords.len);
            defer std.heap.page_allocator.free(vels);
            for (vels, 0..) |_, i| vels[i] = .{0.0, 0.0, 0.0};
            
            var forces = try std.heap.page_allocator.alloc(algorithms.structural.Vec3, vec_coords.len);
            defer std.heap.page_allocator.free(forces);
            for (forces, 0..) |_, i| forces[i] = .{0.0, 0.0, 0.0};
            
            // Just run 1 step
            algorithms.structural.simulateVerletMD(vec_coords, vels, forces, 0.001, 1, 12.0, dummyComputeForces);
            try out_writer.writeText("Completed 1 step of Verlet MD simulation.\n", .{});
            
            // Simulated Annealing
            try algorithms.structural.simulatedAnnealing(
                std.heap.page_allocator, 
                vec_coords, 
                1.0, 0.9, 0.1, 10, 
                dummyComputeEnergy, 
                dummyPerturbState, 
                0
            );
            try out_writer.writeText("Completed Simulated Annealing.\n", .{});
        } else if (std.mem.eql(u8, cmd, "anm")) {
            const hessian = try algorithms.structural.computeANMHessian(std.heap.page_allocator, vec_coords, 15.0, 1.0);
            defer std.heap.page_allocator.free(hessian);
            try out_writer.writeText("Computed ANM Hessian of size {d}.\n", .{hessian.len});
        } else if (std.mem.eql(u8, cmd, "threading")) {
            const scores = try std.heap.page_allocator.alloc(f64, vec_coords.len * vec_coords.len);
            defer std.heap.page_allocator.free(scores);
            @memset(scores, -1.0);
            const score = try algorithms.structural.threadingDynamicProgramming(std.heap.page_allocator, vec_coords.len, vec_coords.len, scores, 10.0, 1.0);
            try out_writer.writeText("Threading alignment score: {d:.4}\n", .{score});
        } else if (std.mem.eql(u8, cmd, "rotamers")) {
            const rot_lib = try std.heap.page_allocator.alloc([]const algorithms.structural.Rotamer, vec_coords.len);
            defer std.heap.page_allocator.free(rot_lib);
            for (rot_lib, 0..) |_, i| {
                const single_rot = try std.heap.page_allocator.alloc(algorithms.structural.Rotamer, 1);
                single_rot[0] = .{ .chi_angles = &[_]f64{}, .probability = 1.0 };
                rot_lib[i] = single_rot;
            }
            
            const selection = try algorithms.structural.greedySidechainPacking(std.heap.page_allocator, vec_coords.len, rot_lib, dummyRotamerEnergy);
            defer std.heap.page_allocator.free(selection);
            
            try out_writer.writeText("Greedy sidechain packing completed for {} residues.\n", .{selection.len});
        } else if (std.mem.eql(u8, cmd, "ingestion")) {
            try out_writer.writeText("Ingested {d} atoms from {s}\n", .{vec_coords.len, in_path});
        } else {
            std.debug.print("Error: Unknown structural command '{s}'\n", .{cmd});
        }
    } else {
        std.debug.print("Error: No command provided for structural.\n", .{});
        std.process.exit(1);
    }
}
