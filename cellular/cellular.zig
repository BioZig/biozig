pub const expression = @import("expression/expression.zig");
pub const singlecell = @import("singlecell/singlecell.zig");
pub const spatial = @import("spatial/spatial.zig");
pub const lineage = @import("lineage/lineage.zig");
pub const cellcycle = @import("cellcycle/cellcycle.zig");
pub const communication = @import("communication/communication.zig");

test {
    _ = expression;
    _ = singlecell;
    _ = spatial;
    _ = lineage;
    _ = cellcycle;
    _ = communication;
}
