const std = @import("std");

pub const bitsieve = @import("bitsieve.zig");
pub const ftp = @import("ftp.zig");
pub const entrez = @import("entrez.zig");
pub const uniprot = @import("uniprot.zig");
pub const pdb = @import("pdb.zig");
pub const chembl = @import("chembl.zig");
pub const ensembl = @import("ensembl.zig");

pub const NetworkStream = struct {
    child: std.process.Child,
    
    pub fn deinit(self: *NetworkStream, io: std.Io) void {
        _ = self.child.wait(io) catch {};
    }
};

pub fn createStream(allocator: std.mem.Allocator, io: std.Io, db: []const u8, query: []const u8) !NetworkStream {
    var url_str: []u8 = undefined;
    
    if (std.mem.eql(u8, db, "ncbi")) {
        url_str = try entrez.EntrezClient.buildUrl(allocator, query);
    } else if (std.mem.eql(u8, db, "uniprot")) {
        url_str = try uniprot.UniprotClient.buildUrl(allocator, query);
    } else if (std.mem.eql(u8, db, "pdb")) {
        url_str = try pdb.PdbClient.buildUrl(allocator, query);
    } else if (std.mem.eql(u8, db, "ensembl")) {
        url_str = try ensembl.EnsemblClient.buildUrl(allocator, query);
    } else if (std.mem.eql(u8, db, "chembl")) {
        url_str = try chembl.ChemblClient.buildUrl(allocator, query);
    } else if (std.mem.eql(u8, db, "ncbi_ftp")) {
        url_str = try std.fmt.allocPrint(allocator, "https://ftp.ncbi.nlm.nih.gov/{s}", .{query});
    } else {
        return error.UnsupportedDb;
    }
    defer allocator.free(url_str);

    const child = try std.process.spawn(io, .{
        .argv = &.{ "curl", "-sL", url_str },
        .stdout = .pipe,
    });
    
    return NetworkStream{ .child = child };
}
