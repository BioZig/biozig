const std = @import("std");
const clustering = @import("clustering.zig");
const timsa = @import("algorithms").molecular.timsa;

pub const ConsensusEngine = struct {
    allocator: std.mem.Allocator,
    memory_budget: usize,

    pub fn init(allocator: std.mem.Allocator, memory_budget: usize) ConsensusEngine {
        return .{
            .allocator = allocator,
            .memory_budget = memory_budget, // Strict SRF bound
        };
    }

    pub const ClusterProfile = struct {
        cluster_id: usize,
        consensus_sequence: []const u8,
        aligned_sequences: [][]const u8,
    };

    /// Aligns sequences within each cluster using the SRF engine.
    pub fn buildProfiles(
        self: *ConsensusEngine,
        clusters: []const clustering.Cluster,
        raw_sequences: [][]const u8,
    ) ![]ClusterProfile {
        var profiles = try self.allocator.alloc(ClusterProfile, clusters.len);
        errdefer self.allocator.free(profiles);

        // We use BioZig's SRF MSA orchestrator per-cluster.
        // TODO: Parallelize via std.Thread.Pool
        for (clusters, 0..) |cluster, i| {
            var cluster_seqs = try self.allocator.alloc([]const u8, cluster.sequence_indices.len);
            defer self.allocator.free(cluster_seqs);
            
            for (cluster.sequence_indices, 0..) |seq_idx, j| {
                cluster_seqs[j] = raw_sequences[seq_idx];
            }

            // Init the TiMSA SRF alignment core
            var srf_msa = timsa.TiMSA.init(self.allocator, self.memory_budget);
            const res = try srf_msa.executeAlignment(cluster_seqs);

            profiles[i] = ClusterProfile{
                .cluster_id = cluster.id,
                .consensus_sequence = res.consensus,
                .aligned_sequences = res.aligned_sequences,
            };
        }

        return profiles;
    }
};
