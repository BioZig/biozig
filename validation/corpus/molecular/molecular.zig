const std = @import("std");

pub fn generateFastaDNA(allocator: std.mem.Allocator, len: usize) ![]u8 {
    const bases = "ACGT";

    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator, ">seq1 deterministic_dna\n");
    for (0..len) |i| {
        try out.append(allocator, bases[i % 4]);
    }
    try out.append(allocator, '\n');
    return out.toOwnedSlice(allocator);
}

pub fn generateFastqDNA(allocator: std.mem.Allocator, len: usize) ![]u8 {
    const bases = "ACGT";

    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator, "@seq1 deterministic_fastq\n");
    for (0..len) |i| {
        try out.append(allocator, bases[i % 4]);
    }
    try out.appendSlice(allocator, "\n+\n");
    for (0..len) |i| {
        const q: u8 = @intCast(20 + (i % 20));
        try out.append(allocator, q + 33);
    }
    try out.append(allocator, '\n');
    return out.toOwnedSlice(allocator);
}

pub fn generateVcf(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator, "##fileformat=VCFv4.2\n");
    try out.appendSlice(allocator, "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n");
    try out.appendSlice(allocator, "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tSAMP1\tSAMP2\n");
    try out.appendSlice(allocator, "chr1\t100\trs1\tA\tG\t50\tPASS\t.\tGT\t0/1\t1/1\n");
    try out.appendSlice(allocator, "chr1\t200\trs2\tC\tT\t60\tPASS\t.\tGT\t0/0\t0/1\n");
    return out.toOwnedSlice(allocator);
}
