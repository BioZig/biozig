const std = @import("std");
const dna_module = @import("molecular").dna;
const DNA2View = dna_module.DNA2View;

/// A simple directed graph representing a De Bruijn graph.
pub const DeBruijnGraph = struct {
    allocator: std.mem.Allocator,
    k: usize,
    edges: std.StringHashMap(std.ArrayList([]const u8)),

    pub fn init(allocator: std.mem.Allocator, k: usize) DeBruijnGraph {
        return DeBruijnGraph{
            .allocator = allocator,
            .k = k,
            .edges = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
        };
    }

    pub fn deinit(self: *DeBruijnGraph) void {
        var it = self.edges.iterator();
        while (it.next()) |entry| {
            // values were allocated, need to free them
            for (entry.value_ptr.*.items) |v| {
                self.allocator.free(v);
            }
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.edges.deinit();
    }

    pub fn addSequence(self: *DeBruijnGraph, seq: []const u8) !void {
        if (seq.len < self.k) return;
        var i: usize = 0;
        while (i <= seq.len - self.k) : (i += 1) {
            const kmer = seq[i .. i + self.k];
            const u = kmer[0 .. self.k - 1];
            const v = kmer[1 .. self.k];
            
            const u_dup = try self.allocator.dupe(u8, u);
            const v_dup = try self.allocator.dupe(u8, v);
            
            var res = try self.edges.getOrPut(u_dup);
            if (!res.found_existing) {
                res.value_ptr.* = std.ArrayList([]const u8).empty;
            } else {
                self.allocator.free(u_dup); // already had the key
            }
            try res.value_ptr.append(self.allocator, v_dup);
        }
    }
};

test "De Bruijn Graph basic" {
    const alloc = std.testing.allocator;
    var graph = DeBruijnGraph.init(alloc, 3);
    defer graph.deinit();

    try graph.addSequence("AATATG");
    // kmers: AAT, ATA, TAT, ATG
    // edges: AA -> AT, AT -> TA, TA -> AT, AT -> TG
    
    const at_edges = graph.edges.get("AT").?;
    try std.testing.expectEqual(@as(usize, 2), at_edges.items.len);
}
