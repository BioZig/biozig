const std = @import("std");
const evolutionary = @import("algorithms").evolutionary;
const PhyloTree = @import("visualization").phylogeny.PhyloTree;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    std.debug.print("Running evolutionary benchmarks...\n", .{});

    var dist_matrix = try allocator.alloc([]const f64, 3);
    defer allocator.free(dist_matrix);
    var d0 = [_]f64{ 0.0, 0.2, 0.3 };
    var d1 = [_]f64{ 0.2, 0.0, 0.4 };
    var d2 = [_]f64{ 0.3, 0.4, 0.0 };
    dist_matrix[0] = &d0;
    dist_matrix[1] = &d1;
    dist_matrix[2] = &d2;

    var labels = try allocator.alloc([]const u8, 3);
    defer allocator.free(labels);
    labels[0] = "A";
    labels[1] = "B";
    labels[2] = "C";

    // Benchmark UPGMA
    for (0..1000) |_| {
        const t = try evolutionary.upgma(allocator, dist_matrix, labels);
        // would normally deinit
        _ = t;
    }
    std.debug.print("UPGMA (1000x): done\n", .{});

    // Benchmark NJ
    for (0..1000) |_| {
        const t = try evolutionary.neighborJoining(allocator, dist_matrix, labels);
        _ = t;
    }
    std.debug.print("NJ (1000x): done\n", .{});

    // Benchmark JC69 Distance
    var jc_sum: f64 = 0;
    for (0..10000) |_| {
        jc_sum += evolutionary.SubstitutionModels.JC69.distance(0.1);
    }
    std.debug.print("JC69 (10000x): done\n", .{});

    std.debug.print("Done.\n", .{});
}
