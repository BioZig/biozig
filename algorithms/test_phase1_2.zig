const std = @import("std");
const graph = @import("graph.zig");
const cluster = @import("cluster.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var seqs = [_][]const u8{
        "MKTIIALSYIFCLVFADYKDDDDK", // cluster 1
        "MKTIIALSYIFCLVFADYKDDDDQ", // cluster 1
        "MPRRRRRRAAAAVVVVVVVVVVVV", // cluster 2
        "MPRRRRRRAAAAVVVVVVVVVVVA", // cluster 2
    };

    std.debug.print("Building Graph (Phase 1)...\n", .{});
    const g = try graph.buildGraph(alloc, &seqs, 6);
    
    std.debug.print("Computing Clusters (Phase 2)...\n", .{});
    var clusters = try cluster.computeClusters(alloc, g.distances, seqs.len);
    defer clusters.deinit();

    std.debug.print("Clusters found: {d}\n", .{clusters.clusters.len});
    for (clusters.clusters, 0..) |c, i| {
        std.debug.print(" Cluster {d}:\n", .{i});
        for (c.sequence_indices) |idx| {
            std.debug.print("   -> Seq {d}\n", .{idx});
        }
    }
}
