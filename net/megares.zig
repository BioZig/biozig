const std = @import("std");

pub const MegaresClient = struct {
    primary_url: []const u8 = "https://megares.meglab.org/",
    fallback_url: []const u8 = "",

    pub fn buildUrl(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
        // Example query: "v3.00"
        // Follows the robust format: https://megares.meglab.org/download/megares_v3.00/megares_database_v3.00.fasta
        return std.fmt.allocPrint(allocator, "https://megares.meglab.org/download/megares_{s}/megares_database_{s}.fasta", .{ query, query });
    }
};
