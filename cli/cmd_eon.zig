const std = @import("std");
const args_parser = @import("args.zig");

const eon = @import("eon");
const fuse = eon.fuse;
const hubs = eon.hubs;
const risk = eon.risk;

pub fn execute(allocator: std.mem.Allocator, args: []const [:0]const u8) !void {
    const parsed = args_parser.parseSlice(args[2..]);
    
    if (parsed.help) {
        printHelp();
        return;
    }
    
    const input_file = parsed.input orelse "rigidity_out.txt";
    const output_file = parsed.output orelse "eon_report.json";

    std.debug.print("[EON] Starting EON Pipeline (Evolutionary Overwatch Network)...\n", .{});
    std.debug.print("[EON] Input: {s}\n", .{input_file});
    std.debug.print("[EON] Output: {s}\n", .{output_file});
    
    const fusion_csv = "eon_fusion.csv";
    const hubs_csv = "eon_hubs.csv";

    // Phase 1: Fusion
    std.debug.print("[EON] Phase 1: Running Topological Fusion...\n", .{});
    try fuse.runFuse(allocator, input_file, fusion_csv);

    // Phase 2: Hub Identification
    std.debug.print("[EON] Phase 2: Identifying BAIL Hubs...\n", .{});
    try hubs.calculateHubs(allocator, fusion_csv, hubs_csv);

    // Phase 3: Risk Scoring
    std.debug.print("[EON] Phase 3: Generating Risk Taxonomies...\n", .{});
    try risk.generateRiskReport(allocator, input_file, hubs_csv, output_file);

    std.debug.print("[EON] Pipeline Complete. Final report generated at: {s}\n", .{output_file});
}

fn printHelp() void {
    const help_text =
        \\BioZig EON (Evolutionary Overwatch Network)
        \\
        \\EON structurally discovers Epistatic and Allosteric hubs representing
        \\Antimicrobial Resistance (AMR) or viral pathogenesis vulnerabilities 
        \\directly from sequence manifold topology without training data.
        \\
        \\Usage: biozig eon [options]
        \\
        \\Options:
        \\  -i, --input <path>     Input rigidity scores / MSA (default: rigidity_out.txt)
        \\  -o, --output <path>    Output EON risk report (default: eon_report.json)
        \\  -h, --help             Show this help menu
        \\
        \\Example:
        \\  biozig eon -i hiv_pr_rigidity.txt -o hiv_risk_report.json
    ;
    std.debug.print("{s}\n", .{help_text});
}
