pub const fasta = @import("fasta.zig");
pub const fastq = @import("fastq.zig");
pub const sam = @import("sam.zig");
pub const bam = @import("bam.zig");
pub const cram = @import("cram.zig");
pub const vcf = @import("vcf.zig");
pub const bcf = @import("bcf.zig");
pub const bed = @import("bed.zig");
pub const gff3 = @import("gff3.zig");
pub const gtf = @import("gtf.zig");
pub const twobit = @import("twobit.zig");

test {
    _ = fasta;
    _ = fastq;
    _ = sam;
    _ = bam;
    _ = cram;
    _ = vcf;
    _ = bcf;
    _ = bed;
    _ = gff3;
    _ = gtf;
}
