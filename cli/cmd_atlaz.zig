const std = @import("std");
const atlaz = @import("ATLAZ");
const simplex = atlaz.simplex;
const ingestion = @import("ingestion");
const core = @import("core");

fn loadDistanceMatrixCsv(allocator: std.mem.Allocator, path: []const u8) ![]f64 {
    var mmap = try core.io.mmap.MMapReader.init(allocator, path);
    defer mmap.deinit();

    var values = std.ArrayList(f64).empty;
    var lines = std.mem.splitScalar(u8, mmap.data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.splitScalar(u8, line, ',');
        while (tokens.next()) |token| {
            if (token.len == 0) continue;
            const val = std.fmt.parseFloat(f64, token) catch 0.0;
            try values.append(allocator, val);
        }
    }
    return try values.toOwnedSlice(allocator);
}

fn computeDistanceMatrixFasta(allocator: std.mem.Allocator, path: []const u8, out_N: *usize) ![]f64 {
    var mmap = try core.io.mmap.MMapReader.init(allocator, path);
    defer mmap.deinit();

    var it = ingestion.genomics.fasta.fastaIterator(mmap.data);
    var sequences = std.ArrayList([]const u8).empty;
    defer {
        for (sequences.items) |seq| allocator.free(seq);
        sequences.deinit(allocator);
    }

    while (try it.next()) |record| {
        const cleaned = try record.cleanSequence(allocator);
        try sequences.append(allocator, cleaned);
    }

    const N = sequences.items.len;
    out_N.* = N;
    
    const n_tri = (N * (N - 1)) / 2;
    var dist_matrix = try allocator.alloc(f64, n_tri);
    
    for (0..N) |i| {
        for (i + 1..N) |j| {
            const seq1 = sequences.items[i];
            const seq2 = sequences.items[j];
            
            var mismatches: usize = 0;
            var valid_len: usize = 0;
            const min_len = @min(seq1.len, seq2.len);
            
            for (0..min_len) |k| {
                const c1 = seq1[k];
                const c2 = seq2[k];
                if (c1 != 'N' and c2 != 'N') {
                    valid_len += 1;
                    if (c1 != c2) mismatches += 1;
                }
            }
            
            const dist = if (valid_len == 0) 1.0 else @as(f64, @floatFromInt(mismatches)) / @as(f64, @floatFromInt(valid_len));
            
            // ATLAZ expects scipy.spatial.distance.pdist layout (strict upper triangle)
            const index = N * i - i * (i + 1) / 2 + j - i - 1;
            dist_matrix[index] = dist;
        }
    }
    
    var min_dist: f64 = std.math.inf(f64);
    var max_dist: f64 = -std.math.inf(f64);
    for (0..n_tri) |idx| {
        const d = dist_matrix[idx];
        if (d < min_dist) min_dist = d;
        if (d > max_dist) max_dist = d;
    }
    std.debug.print("Distance matrix computed. Min: {d:.6}, Max: {d:.6}\n", .{min_dist, max_dist});
    
    return dist_matrix;
}

pub fn execute(allocator: std.mem.Allocator, process_args: []const []const u8) !void {
    if (process_args.len < 3 or std.mem.eql(u8, process_args[2], "-h") or std.mem.eql(u8, process_args[2], "--help")) {
        printHelp();
        return;
    }

    if (!std.mem.eql(u8, process_args[2], "run")) {
        std.debug.print("Error: Unknown atlaz subcommand '{s}'\n\n", .{process_args[2]});
        printHelp();
        return;
    }

    var filepath: []const u8 = "";
    var mode_str: []const u8 = "reticulate";
    var override_max_dist: ?f64 = null;

    var arg_idx: usize = 3;
    while (arg_idx < process_args.len) {
        const arg = process_args[arg_idx];
        if (std.mem.eql(u8, arg, "--mode")) {
            arg_idx += 1;
            if (arg_idx < process_args.len) mode_str = process_args[arg_idx];
        } else if (std.mem.eql(u8, arg, "--input")) {
            arg_idx += 1;
            if (arg_idx < process_args.len) filepath = process_args[arg_idx];
        } else if (std.mem.eql(u8, arg, "--max_distance")) {
            arg_idx += 1;
            if (arg_idx < process_args.len) override_max_dist = std.fmt.parseFloat(f64, process_args[arg_idx]) catch null;
        } else if (filepath.len == 0 and !std.mem.startsWith(u8, arg, "--")) {
            // Legacy fallback for positional input
            filepath = arg;
        }
        arg_idx += 1;
    }

    if (filepath.len == 0) {
        std.debug.print("Usage: {s} --mode <clonal|reticulate> --input <dataset.fasta|csv> [--max_distance <val>]\n", .{process_args[0]});
        return;
    }

    const is_clonal = std.mem.eql(u8, mode_str, "clonal");
    
    std.debug.print("\nMode: {s} ({s})\n", .{
        if (is_clonal) "S-ATLAZ" else "R-ATLAZ",
        if (is_clonal) "Clonal/Tree-like" else "Reticulate/Recombination"
    });

    var N: usize = 0;
    var dist_matrix_vals: []f64 = &[_]f64{};

    if (std.mem.endsWith(u8, filepath, ".fasta") or std.mem.endsWith(u8, filepath, ".fa")) {
        std.debug.print("Computing distance matrix from FASTA {s}...\n", .{filepath});
        dist_matrix_vals = try computeDistanceMatrixFasta(allocator, filepath, &N);
    } else {
        std.debug.print("Loading distance matrix from {s}...\n", .{filepath});
        dist_matrix_vals = try loadDistanceMatrixCsv(allocator, filepath);
        
        const len_f: f64 = @floatFromInt(dist_matrix_vals.len);
        if (len_f > 0) {
            const n_f = @sqrt(len_f);
            if (n_f == @trunc(n_f)) N = @intFromFloat(n_f) else N = @intFromFloat((1.0 + @sqrt(1.0 + 8.0 * len_f)) / 2.0);
        }
    }
    std.debug.print("Processing {d} sequences...\n", .{N});

    const default_max_dist: f64 = if (is_clonal) 0.15 else 0.05;
    const final_max_dist = override_max_dist orelse default_max_dist;
    
    const knn_k: usize = if (is_clonal) @min(15, N) else @min(10, N);

    const config = atlaz.Config{
        .max_distance = final_max_dist,
        .knn_k = knn_k,
    };

    const pairs = try simplex.buildAndReduceRips(allocator, dist_matrix_vals, N, config.max_distance, config.knn_k);
    
    var h1_count: usize = 0;
    var max_persistence: f64 = 0.0;
    
    for (pairs) |p| {
        if (p.dimension == 1 and p.death != std.math.maxInt(usize)) {
            const lifetime = p.death_val - p.birth_val;
            if (lifetime > 0.01) { 
                h1_count += 1;
                if (lifetime > max_persistence) max_persistence = lifetime;
            }
        }
    }
    
    if (h1_count > 0) {
        std.debug.print("Topology: NONTRIVIAL (Recombination detected)\n", .{});
        std.debug.print("H1 Breakpoints:\n", .{});
        for (pairs) |p| {
            if (p.dimension == 1 and p.death != std.math.maxInt(usize)) {
                const lifetime = p.death_val - p.birth_val;
                if (lifetime > 0.01) { 
                    std.debug.print("  Loop Origin [{d}]: Persistence {d:.4}\n", .{p.birth, lifetime});
                }
            }
        }
        std.debug.print("Interpretation: Reticulate evolution detected. Network-based phylogenetics recommended. Avoid IQ-TREE.\n", .{});
    } else {
        std.debug.print("Topology: TRIVIAL (No recombination detected)\n", .{});
        std.debug.print("Interpretation: Strong purifying selection detected or purely clonal expansion. Tree-based phylogenetics (IQ-TREE) recommended.\n", .{});
    }
}

fn printHelp() void {
    const help_text =
        \\ATLAZ: Alignment, Topology, and Lineage Analysis in Zig
        \\
        \\Usage: biozig atlaz <command> [options]
        \\
        \\Commands:
        \\  run            Execute the core ATLAZ topological reduction pipeline
        \\
        \\Run Options:
        \\  --input <path>         Input file path (.fasta or .csv distance matrix)
        \\  --mode <type>          Evolutionary mode: 'clonal' or 'reticulate'
        \\                         - clonal:     Optimized for point mutations (e.g. Ebola, SARS-CoV-2)
        \\                         - reticulate: Optimized for recombination/reassortment (e.g. HIV, Influenza)
        \\  --max_distance <val>   (Optional) Override default simplex filtration threshold
        \\                         (Defaults: clonal=0.15, reticulate=0.05)
        \\  -h, --help             Show this help menu
        \\
        \\Examples:
        \\  biozig atlaz run --input ebola.fasta --mode clonal
        \\  biozig atlaz run --input hiv.fasta --mode reticulate --max_distance 0.10
        \\
    ;
    std.debug.print("{s}", .{help_text});
}
