const std = @import("std");
const args_parser = @import("args.zig");
const cmd_genomics = @import("cmd_genomics.zig");
const cmd_structural = @import("cmd_structural.zig");
const cmd_cellular = @import("cmd_cellular.zig");
const cmd_analytics = @import("cmd_analytics.zig");
const cmd_systems = @import("cmd_systems.zig");
const cmd_evolutionary = @import("cmd_evolutionary.zig");
const cmd_population = @import("cmd_population.zig");
const cmd_reporting = @import("cmd_reporting.zig");
const cmd_visualize = @import("cmd_visualize.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const process_args = try init.minimal.args.toSlice(allocator);

    if (process_args.len < 2) {
        printHelp();
        return;
    }

    const domain = process_args[1];

    if (std.mem.eql(u8, domain, "-h") or std.mem.eql(u8, domain, "--help")) {
        printHelp();
        return;
    }

    const parsed = args_parser.parseSlice(process_args[2..]);

    if (std.mem.eql(u8, domain, "genomics")) {
        try cmd_genomics.execute(parsed);
    } else if (std.mem.eql(u8, domain, "structural")) {
        try cmd_structural.execute(parsed);
    } else if (std.mem.eql(u8, domain, "cellular")) {
        try cmd_cellular.execute(parsed);
    } else if (std.mem.eql(u8, domain, "analytics")) {
        try cmd_analytics.execute(parsed);
    } else if (std.mem.eql(u8, domain, "systems")) {
        try cmd_systems.execute(parsed);
    } else if (std.mem.eql(u8, domain, "evolutionary")) {
        try cmd_evolutionary.execute(parsed);
    } else if (std.mem.eql(u8, domain, "population")) {
        try cmd_population.execute(parsed);
    } else if (std.mem.eql(u8, domain, "reporting")) {
        try cmd_reporting.execute(parsed);
    } else if (std.mem.eql(u8, domain, "visualize")) {
        try cmd_visualize.execute(parsed);
    } else {
        std.debug.print("Error: Unknown domain '{s}'.\n\n", .{domain});
        printHelp();
        std.process.exit(1);
    }
}

fn printHelp() void {
    const help_text =
        \\BioZig CLI - High-Performance Zero-Copy Bioinformatics
        \\
        \\Usage: biozig <domain> <command> [options]
        \\
        \\Domains:
        \\  genomics       Sequence alignment, mapping, and analysis
        \\  structural     3D protein structures and interactions
        \\  cellular       Single-cell tools for dimensionality reduction
        \\  systems        Systems biology and network analysis
        \\  population     Population genetics analysis
        \\  evolutionary   Phylogenetics and evolutionary models
        \\  analytics      Statistical models, matrix decompositions, clustering
        \\  reporting      Automated reporting and publication exports
        \\  visualize      Render biological data and plots
        \\
        \\Global Options:
        \\  -i, --input <path>     Input file path
        \\  -o, --output <path>    Output file path (default: stdout)
        \\  -f, --format <type>    Output format (text, json)
        \\  -t, --threads <num>    Number of CPU threads
        \\  -h, --help             Show help menu
        \\
        \\Examples:
        \\  biozig genomics align -i reads.fastq --ref genome.fa
        \\  biozig analytics pca -i cells.mtx -f json
        \\  biozig structural contacts -i envelope.mmcif -p
        \\
    ;
    std.debug.print("{s}\n", .{help_text});
}
