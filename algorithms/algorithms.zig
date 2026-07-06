const std = @import("std");

pub const molecular = @import("molecular/molecular.zig");
pub const variant = @import("variant/variant.zig");
pub const structural = @import("structural/structural.zig");
pub const cellular = @import("cellular/cellular.zig");
pub const systems = @import("systems/systems.zig");
pub const organismal = @import("organismal/organismal.zig");
pub const population = @import("population/population.zig");
pub const evolutionary = @import("evolutionary/evolutionary.zig");

test "Algorithms Layer Core Validation" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(molecular);
    std.testing.refAllDecls(variant);
    std.testing.refAllDecls(structural);
    std.testing.refAllDecls(cellular);
    std.testing.refAllDecls(systems);
    std.testing.refAllDecls(organismal);
    std.testing.refAllDecls(population);
    // std.testing.refAllDecls(evolutionary);
}
