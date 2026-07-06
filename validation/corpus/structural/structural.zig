const std = @import("std");

pub fn generatePdb(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    // 3 residues of poly-ALA
    try out.appendSlice(allocator, "ATOM      1  N   ALA A   1       0.000   0.000   0.000  1.00 20.00           N  \n");
    try out.appendSlice(allocator, "ATOM      2  CA  ALA A   1       1.458   0.000   0.000  1.00 20.00           C  \n");
    try out.appendSlice(allocator, "ATOM      3  C   ALA A   1       2.009   1.424   0.000  1.00 20.00           C  \n");
    try out.appendSlice(allocator, "ATOM      4  O   ALA A   1       1.285   2.424   0.000  1.00 20.00           O  \n");
    try out.appendSlice(allocator, "ATOM      5  CB  ALA A   1       2.009  -0.774  -1.200  1.00 20.00           C  \n");
    try out.appendSlice(allocator, "TER       6      ALA A   1\n");
    try out.appendSlice(allocator, "END\n");
    return out.toOwnedSlice(allocator);
}

pub fn generatePqr(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator, "ATOM      1  N   ALA A   1       0.000   0.000   0.000 -0.4157 1.8240\n");
    try out.appendSlice(allocator, "ATOM      2  CA  ALA A   1       1.458   0.000   0.000  0.0337 1.9080\n");
    try out.appendSlice(allocator, "ATOM      3  C   ALA A   1       2.009   1.424   0.000  0.5973 1.9080\n");
    try out.appendSlice(allocator, "ATOM      4  O   ALA A   1       1.285   2.424   0.000 -0.5679 1.6612\n");
    try out.appendSlice(allocator, "TER       5      ALA A   1\n");
    try out.appendSlice(allocator, "END\n");
    return out.toOwnedSlice(allocator);
}
