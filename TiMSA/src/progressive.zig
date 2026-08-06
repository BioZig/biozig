const std = @import("std");
const srf = @import("core").scheduling.srf;
const alignment_profile = @import("algorithms").molecular.alignment_profile;
const consensus = @import("consensus.zig");

pub const ProgressiveEngine = struct {
    allocator: std.mem.Allocator,
    memory_budget: usize,

    pub fn init(allocator: std.mem.Allocator, memory_budget: usize) ProgressiveEngine {
        return .{
            .allocator = allocator,
            .memory_budget = memory_budget,
        };
    }

    /// Aligns cluster consensus profiles guided by H1 loops / H0 tree.
    pub fn mergeClusters(self: *ProgressiveEngine, cluster_profiles: []consensus.ConsensusEngine.ClusterProfile) ![]const u8 {
        if (cluster_profiles.len == 0) return "";
        if (cluster_profiles.len == 1) return cluster_profiles[0].consensus_sequence;

        // In a full H1-guided implementation, we would extract the H1 loops from the ATLAZ output
        // and resolve reticulate edges first. 
        // For the deterministic sequence tree, we align progressively down the cluster array.
        
        var current_global_profile = try self.allocator.dupe(u8, cluster_profiles[0].consensus_sequence);

        const rec = alignment_profile.ProfileRecurrence{
            .gap_open = -2,
            .gap_extend = -1,
        };

        var scheduler = srf.SRFScheduler(alignment_profile.ProfileRecurrence).init(self.allocator, rec, self.memory_budget);

        for (1..cluster_profiles.len) |i| {
            const next_profile = cluster_profiles[i].consensus_sequence;
            
            // Invoke the SRF memory-bounded engine on the mathematical profile recurrence.
            const srf_res = try scheduler.execute(current_global_profile, next_profile);
            
            self.allocator.free(current_global_profile);
            
            // For now, we resolve the traceback back into a flat string. 
            // A fully implemented profile-profile aligner would merge the PSSMs directly.
            // We use align_a as the new global backbone.
            current_global_profile = srf_res.align_a;
            self.allocator.free(srf_res.align_b); 
        }

        return current_global_profile;
    }
};
