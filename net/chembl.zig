const std = @import("std");

pub const ChemblClient = struct {
    primary_url: []const u8 = "https://www.ebi.ac.uk/chembl/api/data/",
    fallback_url: []const u8 = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "https://www.ebi.ac.uk/chembl/api/data/molecule/{s}?format=json", .{query});
    }
};
