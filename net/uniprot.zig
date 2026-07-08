const std = @import("std");

pub const UniprotClient = struct {
    primary_url: []const u8 = "https://rest.uniprot.org/uniprotkb/",
    fallback_url: []const u8 = "https://www.ebi.ac.uk/proteins/api/",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "https://rest.uniprot.org/uniprotkb/{s}.fasta", .{query});
    }
};
