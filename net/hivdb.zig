const std = @import("std");

pub const HivdbClient = struct {
    pub fn buildArgs(allocator: std.mem.Allocator, argv: *std.ArrayListUnmanaged([]const u8), query: []const u8) !void {
        try argv.appendSlice(allocator, &.{ "curl", "-sL", "-X", "POST", "-H", "Content-Type: application/json" });
        const body = if (std.mem.indexOf(u8, query, "\"query\"") != null) 
            try allocator.dupe(u8, query) 
        else 
            try std.fmt.allocPrint(allocator, "{{\"query\": \"{s}\"}}", .{query});
        try argv.appendSlice(allocator, &.{ "-d", body, "https://hivdb.stanford.edu/graphql" });
    }
};
