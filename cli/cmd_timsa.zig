const std = @import("std");
const ParsedArgs = @import("args.zig").ParsedArgs;
const algorithms = @import("algorithms");
const timsa = algorithms.molecular.timsa;
const refinement = algorithms.molecular.refinement;
const MMapReader = @import("core").io.mmap.MMapReader;
const ingestion = @import("ingestion");

fn printHelp() void {
    const help_text =
        \\TiMSA - Topology-inspired Multiple Sequence Alignment
        \\
        \\Usage: biozig timsa <mode> [options]
        \\
        \\Modes:
        \\  align        Full topological alignment (TiMSA-Align)
        \\  cluster      Topological clustering only (early exit) (TiMSA-Cluster)
        \\  domain       Local topological domain isolation (TiMSA-Domain)
        \\  rigidity     Ablation gradient structural refinement (TiMSA-Rigidity)
        \\  recomb       Topological loop extraction (TiMSA-Recomb)
        \\  fast         Hierarchical chunked profile alignment (TiMSA-Fast)
        \\  consensus    Frequency-based structural summary (TiMSA-Consensus)
        \\
        \\Options:
        \\  -i, --input <path>     Input FASTA file containing sequences
        \\  -o, --output <path>    Output file for aligned sequences (default: stdout)
        \\  -h, --help             Show this help menu
        \\
        \\Examples:
        \\  biozig timsa align -i input.fasta
        \\  biozig timsa rigidity -i unaligned.fa -o refined.fa
        \\
    ;
    std.debug.print("{s}\n", .{help_text});
}

pub fn execute(allocator: std.mem.Allocator, parsed: ParsedArgs) !void {
    if (parsed.help) {
        printHelp();
        return;
    }

    const command = parsed.run orelse {
        std.debug.print("Error: Missing TiMSA mode.\n\n", .{});
        printHelp();
        std.process.exit(1);
    };

    var config = timsa.TiMSAConfig{
        .memory_budget_bytes = 512 * 1024 * 1024,
    };

    if (std.mem.eql(u8, command, "align")) {
        config.mode = .Align;
        config.recurrence_type = .Global;
        config.refinement_strategy = .Targeted;
    } else if (std.mem.eql(u8, command, "cluster")) {
        config.mode = .Cluster;
        config.refinement_strategy = .None;
    } else if (std.mem.eql(u8, command, "domain")) {
        config.mode = .Align;
        config.recurrence_type = .Local; // SWRecurrence integration
        config.refinement_strategy = .Targeted;
    } else if (std.mem.eql(u8, command, "rigidity")) {
        config.mode = .Rigidity;
        config.require_h1 = true;
    } else if (std.mem.eql(u8, command, "recomb")) {
        config.mode = .Recomb;
        config.require_h1 = true;
    } else if (std.mem.eql(u8, command, "fast")) {
        config.mode = .Fast;
        config.refinement_strategy = .None;
    } else if (std.mem.eql(u8, command, "consensus")) {
        config.mode = .Consensus;
    } else {
        std.debug.print("Error: Unknown TiMSA mode '{s}'.\n\n", .{command});
        printHelp();
        std.process.exit(1);
    }

    const input_path = parsed.input orelse {
        std.debug.print("Error: Input FASTA file is required (-i, --input).\n", .{});
        std.process.exit(1);
    };

    var mmap_reader = try MMapReader.init(allocator, input_path);
    defer mmap_reader.deinit();

    var sequences = std.ArrayList([]const u8).empty;
    defer {
        for (sequences.items) |s| allocator.free(s);
        sequences.deinit(allocator);
    }

    var it = ingestion.genomics.fasta.fastaIterator(mmap_reader.data);
    while (try it.next()) |rec| {
        try sequences.append(allocator, try allocator.dupe(u8, rec.sequence));
    }

    if (sequences.items.len == 0) {
        std.debug.print("Error: No sequences found in {s}\n", .{input_path});
        std.process.exit(1);
    }

    std.debug.print("Loaded {d} sequences. Executing TiMSA mode: {s}...\n", .{sequences.items.len, command});

    var ms = timsa.TiMSA.init(allocator, config);
    const result = try ms.executeAlignment(sequences.items);
    
    for (result.aligned_sequences, 0..) |seq, i| {
        std.debug.print(">Sequence_{d}\n{s}\n", .{i + 1, seq});
    }
    
    if (config.mode != .Cluster) {
        std.debug.print(">TiMSA_Consensus\n{s}\n", .{result.consensus});
    }
    
    if (result.rigidity_scores) |scores| {
        std.debug.print("\n=== TiMSA Rigidity Scores (Ablation Gradient) ===\n", .{});
        for (scores, 0..) |score, col| {
            if (score > 0.0) std.debug.print("Col {d}: +{d:.4}\n", .{col, score});
        }
    }
    
    if (result.recomb_pairs) |pairs| {
        std.debug.print("\n=== TiMSA Recombination Topological Loops (H1) ===\n", .{});
        var found = false;
        for (pairs) |p| {
            if (p.dimension == 1) {
                found = true;
                std.debug.print("Loop Birth: {d:.4}, Death: {d:.4}\n", .{p.birth_val, p.death_val});
            }
        }
        if (!found) std.debug.print("No H1 loops detected.\n", .{});
    }
}
