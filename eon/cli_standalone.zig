const std = @import("std");
const cmd_eon = @import("cmd_eon");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const raw_args = try init.minimal.args.toSlice(allocator);
    
    // cmd_eon.execute expects args like `biozig eon -i ...`
    // Standalone EON is called as `eon -i ...`
    // We pad the arguments to satisfy the router
    var padded_args = try allocator.alloc([:0]const u8, raw_args.len + 1);
    padded_args[0] = "biozig";
    padded_args[1] = "eon";
    for (raw_args[1..], 0..) |arg, i| {
        padded_args[i + 2] = arg;
    }
    
    try cmd_eon.execute(allocator, padded_args);
}
