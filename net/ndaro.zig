const std = @import("std");

pub const NdaroClient = struct {
    pub fn buildArgs(allocator: std.mem.Allocator, argv: *std.ArrayListUnmanaged([]const u8), query: []const u8) !void {
        // NCBI Pathogen Detection (NDARO) does not have a simple sequence REST API.
        // It provides data via Google BigQuery, FTP, and the Datasets API.
        // To fetch sequence metadata robustly from the CLI without BigQuery auth,
        // we use the official NCBI Datasets API (v2alpha) for genomes/genes.
        
        const url = try std.fmt.allocPrint(allocator, "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/genome/accession/{s}/dataset_report", .{query});
        
        try argv.appendSlice(allocator, &.{
            "curl",
            "-sL",
            "--header",
            "Accept: application/json",
            url,
        });
    }
};
