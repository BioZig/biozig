const std = @import("std");

pub const PdbClient = struct {
    primary_url: []const u8 = "http://files.rcsb.org/download/",
    fallback_url: []const u8 = "https://www.ebi.ac.uk/pdbe/entry-files/download/",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://files.rcsb.org/download/{s}.pdb", .{query});
    }
};
