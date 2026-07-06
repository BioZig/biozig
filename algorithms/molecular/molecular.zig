const std = @import("std");

pub const distance = @import("distance.zig");
pub const alignment = @import("alignment.zig");
pub const kmer = @import("kmer.zig");
pub const motif = @import("motif.zig");
pub const information = @import("information.zig");
pub const coding = @import("coding.zig");
pub const indexing = @import("indexing.zig");
pub const search = @import("search.zig");
pub const assembly = @import("assembly.zig");
pub const hmm = @import("hmm.zig");
pub const msa = @import("msa.zig");
pub const gibbs = @import("gibbs.zig");
pub const suffix_tree = @import("suffix_tree.zig");

test "Sequence Algorithm Tests" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(distance);
    std.testing.refAllDecls(alignment);
    std.testing.refAllDecls(kmer);
    std.testing.refAllDecls(motif);
    std.testing.refAllDecls(information);
    std.testing.refAllDecls(coding);
    std.testing.refAllDecls(indexing);
    std.testing.refAllDecls(search);
    std.testing.refAllDecls(assembly);
    std.testing.refAllDecls(hmm);
    std.testing.refAllDecls(msa);
    std.testing.refAllDecls(gibbs);
    std.testing.refAllDecls(suffix_tree);
}
