const std = @import("std");
const args_mod = @import("args.zig");
const output = @import("output.zig");
const core = @import("core");
const MMapReader = core.io.mmap.MMapReader;
const algorithms = @import("algorithms");
const evo_alg = algorithms.evolutionary;
const ingestion = @import("ingestion");
const visualization = @import("visualization");

fn parseDistanceMatrix(allocator: std.mem.Allocator, data: []const u8) !struct { matrix: [][]f64, labels: [][]const u8 } {
    var matrix: std.ArrayListUnmanaged([]f64) = .empty;
    var labels: std.ArrayListUnmanaged([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var it = std.mem.splitAny(u8, line, " \t,");
        const label = it.next() orelse continue;
        try labels.append(allocator, label);

        var row: std.ArrayListUnmanaged(f64) = .empty;
        while (it.next()) |val_str| {
            if (val_str.len == 0) continue;
            const val = try std.fmt.parseFloat(f64, val_str);
            try row.append(allocator, val);
        }
        try matrix.append(allocator, try row.toOwnedSlice(allocator));
    }
    return .{ .matrix = try matrix.toOwnedSlice(allocator), .labels = try labels.toOwnedSlice(allocator) };
}

pub fn execute(args: args_mod.ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig evolutionary <command> [options]
            \\
            \\Commands:
            \\  nj               Neighbor-Joining Tree Construction
            \\  upgma            UPGMA Tree Construction
            \\  mle              Maximum Likelihood Estimation (Felsenstein's pruning)
            \\  parsimony        Maximum Parsimony (Fitch's algorithm)
            \\  mcmc             Bayesian Inference of Phylogeny (MCMC)
            \\  bootstrap        Felsenstein Bootstrapping
            \\  nni              Nearest Neighbor Interchange (NNI)
            \\  spr              Subtree Pruning and Regrafting (SPR)
            \\  stats            Compute Tree Statistics
            \\  rf-distance      Robinson-Foulds Distance
            \\  parse-newick     Parse and Serialize Newick Trees
            \\  parse-nexus      Parse and Serialize Nexus Trees
            \\  parse-phyloxml   Parse and Serialize PhyloXML Trees
            \\
            \\Options:
            \\  -h, --help   Show this help message and exit
            \\  -i, --input  Input tree file (.newick) or distance matrix (.csv)
            \\
        , .{});
        return;
    }

    const cmd = args.run orelse {
        std.debug.print("Error: Evolutionary domain requires a command.\n", .{});
        return;
    };

    const in_path = args.input orelse {
        std.debug.print("Error: Command requires an --input file (-i).\n", .{});
        return error.MissingInput;
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var reader = try MMapReader.init(allocator, in_path);
    defer reader.deinit();

    var out_writer = output.OutputWriter.init(.text);

    if (std.mem.eql(u8, cmd, "nj")) {
        const parsed = try parseDistanceMatrix(allocator, reader.data);
        const const_matrix = try allocator.alloc([]const f64, parsed.matrix.len);
        for (parsed.matrix, 0..) |row, i| const_matrix[i] = row;

        const res = try evo_alg.neighborJoining(allocator, const_matrix, parsed.labels);
        std.debug.print("{any}\n", .{res});
    } else if (std.mem.eql(u8, cmd, "upgma")) {
        const parsed = try parseDistanceMatrix(allocator, reader.data);
        const const_matrix = try allocator.alloc([]const f64, parsed.matrix.len);
        for (parsed.matrix, 0..) |row, i| const_matrix[i] = row;

        const res = try evo_alg.upgma(allocator, const_matrix, parsed.labels);
        std.debug.print("{any}\n", .{res});
    } else if (std.mem.eql(u8, cmd, "nni")) {
        const tree = try ingestion.evolutionary.newick.parseNewick(allocator, reader.data);
        const trees = try evo_alg.nearestNeighborInterchange(allocator, tree);
        std.debug.print("{any}\n", .{trees});
    } else if (std.mem.eql(u8, cmd, "spr")) {
        const tree = try ingestion.evolutionary.newick.parseNewick(allocator, reader.data);
        const trees = try evo_alg.subtreePruningRegrafting(allocator, tree);
        std.debug.print("{any}\n", .{trees});
    } else if (std.mem.eql(u8, cmd, "stats")) {
        const tree = try ingestion.evolutionary.newick.parseNewick(allocator, reader.data);
        const stats = evo_alg.computeTreeStatistics(tree);
        std.debug.print("{any}\n", .{stats});
    } else if (std.mem.eql(u8, cmd, "parse-newick")) {
        const tree = try ingestion.evolutionary.newick.parseNewick(allocator, reader.data);
        std.debug.print("{any}\n", .{tree});
    } else if (std.mem.eql(u8, cmd, "parse-nexus")) {
        const tree = try ingestion.evolutionary.nexus.parseNexus(allocator, reader.data);
        std.debug.print("{any}\n", .{tree});
    } else if (std.mem.eql(u8, cmd, "parse-phyloxml")) {
        const tree = try ingestion.evolutionary.phyloxml.parsePhyloXml(allocator, reader.data);
        std.debug.print("{any}\n", .{tree});
    } else if (std.mem.eql(u8, cmd, "mle") or std.mem.eql(u8, cmd, "parsimony") or std.mem.eql(u8, cmd, "mcmc") or std.mem.eql(u8, cmd, "bootstrap") or std.mem.eql(u8, cmd, "rf-distance")) {
        try out_writer.writeText("Command '{s}' executed (requires multiple inputs, mocked response for now).\n", .{cmd});
    } else {
        std.debug.print("Error: Unknown evolutionary command '{s}'\n", .{cmd});
    }
}
