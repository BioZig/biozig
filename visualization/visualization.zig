pub const sequence = @import("sequence/sequence.zig");
pub const structure = @import("structure/structure.zig");
pub const network = @import("network/network.zig");
pub const omics = @import("omics/omics.zig");
pub const phylogeny = @import("phylogeny/phylogeny.zig");
pub const dashboards = @import("dashboards/dashboards.zig");
pub const publication = @import("publication/publication.zig");

test {
    _ = sequence;
    _ = structure;
    _ = network;
    _ = omics;
    _ = phylogeny;
    _ = dashboards;
    _ = publication;
}
