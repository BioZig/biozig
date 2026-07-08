const std = @import("std");

pub const genomics = @import("genomics/genomics.zig");
pub const transcriptomics = @import("transcriptomics/transcriptomics.zig");
pub const structural = @import("structural/structural.zig");
pub const systems = @import("systems/systems.zig");
pub const indices = @import("indices/indices.zig");
pub const evolutionary = @import("evolutionary/evolutionary.zig");

test "ingestion tests" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(genomics);
    std.testing.refAllDecls(transcriptomics);
    std.testing.refAllDecls(structural);
    std.testing.refAllDecls(systems);
    std.testing.refAllDecls(evolutionary);
}
pub const cheminformatics = @import("cheminformatics/cheminformatics.zig");
