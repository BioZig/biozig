const std = @import("std");

pub const CardClient = struct {
    primary_url: []const u8 = "https://card.mcmaster.ca/",
    fallback_url: []const u8 = "",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        // If query is "latest", downloads the latest data archive.
        // The URL follows the robust format: https://card.mcmaster.ca/[query]/data
        return std.fmt.allocPrint(allocator, "https://card.mcmaster.ca/{s}/data", .{query});
    }
};
