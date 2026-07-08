const std = @import("std");

pub const EnsemblClient = struct {
    primary_url: []const u8 = "http://rest.ensembl.org/",
    fallback_url: []const u8 = "https://api.genome.ucsc.edu/",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://rest.ensembl.org/sequence/id/{s}?content-type=text/x-fasta&type=genomic", .{query});
    }
};
