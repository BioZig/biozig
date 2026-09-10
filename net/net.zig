const std = @import("std");

pub const bitsieve = @import("bitsieve.zig");
pub const ftp = @import("ftp.zig");
pub const entrez = @import("entrez.zig");
pub const uniprot = @import("uniprot.zig");
pub const pdb = @import("pdb.zig");
pub const chembl = @import("chembl.zig");
pub const ensembl = @import("ensembl.zig");
pub const card = @import("card.zig");
pub const megares = @import("megares.zig");
pub const hivdb = @import("hivdb.zig");
pub const ndaro = @import("ndaro.zig");

pub const NetworkStream = struct {
    child: std.process.Child,
    
    pub fn deinit(self: *NetworkStream, io: std.Io) void {
        _ = self.child.wait(io) catch {};
    }
};

pub fn createStream(allocator: std.mem.Allocator, io: std.Io, db: []const u8, query: []const u8) !NetworkStream {
    var argv = std.ArrayListUnmanaged([]const u8).empty;
    defer argv.deinit(allocator);

    // Modules that require complex argument building (e.g. POST requests, custom headers)
    if (std.mem.eql(u8, db, "hivdb")) {
        try hivdb.HivdbClient.buildArgs(allocator, &argv, query);
    } else if (std.mem.eql(u8, db, "ndaro")) {
        try ndaro.NdaroClient.buildArgs(allocator, &argv, query);
    } else {
        // Modules that strictly return a URL string
        var url_str: []u8 = undefined;
        if (std.mem.eql(u8, db, "ncbi")) {
            url_str = try entrez.EntrezClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "uniprot")) {
            url_str = try uniprot.UniprotClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "uniprot_json")) {
            url_str = try uniprot.UniprotClient.buildUrlJson(allocator, query);
        } else if (std.mem.eql(u8, db, "pdb")) {
            url_str = try pdb.PdbClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "ensembl")) {
            url_str = try ensembl.EnsemblClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "chembl")) {
            url_str = try chembl.ChemblClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "card")) {
            url_str = try card.CardClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "megares")) {
            url_str = try megares.MegaresClient.buildUrl(allocator, query);
        } else if (std.mem.eql(u8, db, "ucsc")) {
            url_str = try std.fmt.allocPrint(allocator, "https://hgdownload.cse.ucsc.edu/{s}", .{query});
        } else if (std.mem.eql(u8, db, "ncbi_ftp")) {
            url_str = try std.fmt.allocPrint(allocator, "https://ftp.ncbi.nlm.nih.gov/{s}", .{query});
        } else {
            return error.UnsupportedDb;
        }
        try argv.appendSlice(allocator, &.{ "curl", "-sL", url_str });
    }

    const child = try std.process.spawn(io, .{
        .argv = argv.items,
        .stdout = .pipe,
    });
    
    return NetworkStream{ .child = child };
}
