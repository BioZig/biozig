const std = @import("std");
const profile = @import("profile.zig");
const upgma_tree = @import("upgma_tree.zig");
const upgma_align = @import("upgma_align.zig");
const alignment = @import("alignment.zig");

pub fn runAlignmentPhases(
    allocator: std.mem.Allocator,
    scheduler: anytype,
    sequences: [][]const u8,
    topo_clusters: anytype,
    seq_graph: anytype,
    config: anytype,
    sub_matrix: ?*const alignment.SubstitutionMatrix,
) !profile.Profile {
    var cluster_profiles = std.ArrayListUnmanaged(profile.Profile).empty;
    defer {
        for (cluster_profiles.items) |*p| p.deinit();
        cluster_profiles.deinit(allocator);
    }

    for (topo_clusters.clusters) |c| {
        if (c.sequence_indices.len == 1) {
            var single_arr = [_][]const u8{ sequences[c.sequence_indices[0]] };
            const p = try profile.Profile.fromAlignment(allocator, &single_arr);
            try cluster_profiles.append(allocator, p);
        } else {
            const p = try upgma_tree.alignClusterUPGMA(
                allocator,
                sequences,
                c.sequence_indices,
                seq_graph.distances,
                sequences.len,
                scheduler,
            );
            try cluster_profiles.append(allocator, p);
        }
    }

    
}
