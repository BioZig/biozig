const std = @import("std");

pub const EntrezClient = struct {
    primary_url: []const u8 = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/",
    fallback_url: []const u8 = "https://www.ebi.ac.uk/ena/browser/api/",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id={s}&rettype=fasta&retmode=text", .{query});
    }
};
