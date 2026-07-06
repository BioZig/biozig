pub const network = @import("network/network.zig");
pub const pathway = @import("pathway/pathway.zig");
pub const regulation = @import("regulation/regulation.zig");
pub const signaling = @import("signaling/signaling.zig");
pub const metabolism = @import("metabolism/metabolism.zig");
pub const ontology = @import("ontology/ontology.zig");
pub const knowledgegraph = @import("knowledgegraph/knowledgegraph.zig");

test {
    _ = network;
    _ = pathway;
    _ = regulation;
    _ = signaling;
    _ = metabolism;
    _ = ontology;
    _ = knowledgegraph;
}
