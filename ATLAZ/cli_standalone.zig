const std = @import("std");
const cmd_atlaz = @import("cmd_atlaz");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const raw_args = try init.minimal.args.toSlice(allocator);
    
    // cmd_atlaz.execute expects args like `biozig atlaz run --input ...`
    // Standalone ATLAZ is called as `atlaz run --input ...`
    // We pad the arguments to satisfy the router
    var padded_args = try allocator.alloc([]const u8, raw_args.len + 1);
    padded_args[0] = "biozig";
    padded_args[1] = "atlaz";
    for (raw_args[1..], 0..) |arg, i| {
        padded_args[i + 2] = arg;
    }
    
    try cmd_atlaz.execute(allocator, padded_args);
}
