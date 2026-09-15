const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_file: []const u8 = "rigidity_out.txt";
    const output_file: []const u8 = "eon_report.json";

    std.debug.print("[EON] Starting EON Pipeline...\n", .{});
    
    // Phase 1: Fusion
    std.debug.print("[EON] Phase 1: Running Topological Fusion...\n", .{});
    _ = try std.process.Child.run(.{ .allocator = allocator, .argv = &[_][]const u8{ "eon/fuse_network_zig" } });

    // Phase 2: Hub Identification
    std.debug.print("[EON] Phase 2: Identifying BAIL Hubs...\n", .{});
    _ = try std.process.Child.run(.{ .allocator = allocator, .argv = &[_][]const u8{ "eon/hubs_network_zig" } });

    // Phase 3: Risk Scoring
    std.debug.print("[EON] Phase 3: Generating Risk Taxonomies...\n", .{});
    _ = try std.process.Child.run(.{ .allocator = allocator, .argv = &[_][]const u8{ "eon/risk_network_zig" } });

    // Phase 4: Reporting
    std.debug.print("[EON] Pipeline Complete. Final report: {s}\n", .{output_file});
    
    // (Optional: we could rename eon_report.json to output_file.? here if different)
}
