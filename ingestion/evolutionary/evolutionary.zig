pub const newick = @import("newick.zig");
pub const nexus = @import("nexus.zig");
pub const phyloxml = @import("phyloxml.zig");

test "evolutionary tests" {
    const std = @import("std");
    std.testing.refAllDecls(newick);
    std.testing.refAllDecls(nexus);
    std.testing.refAllDecls(phyloxml);
}
