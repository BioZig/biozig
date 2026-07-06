const std = @import("std");

pub fn generatePopulationVcf(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator, "##fileformat=VCFv4.2\n");
    try out.appendSlice(allocator, "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n");
    try out.appendSlice(allocator, "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tPOP1_1\tPOP1_2\tPOP2_1\tPOP2_2\n");
    try out.appendSlice(allocator, "chr1\t1000\trs100\tA\tC\t99\tPASS\t.\tGT\t0/0\t0/0\t1/1\t0/1\n");
    try out.appendSlice(allocator, "chr1\t2000\trs200\tG\tT\t99\tPASS\t.\tGT\t0/1\t1/1\t0/0\t0/0\n");
    return out.toOwnedSlice(allocator);
}
