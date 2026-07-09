const std = @import("std");
const ParsedArgs = @import("args.zig").ParsedArgs;
const algorithms = @import("algorithms");
const ingestion = @import("ingestion");
const MMapReader = @import("core").io.mmap.MMapReader;
const DNA2 = @import("molecular").dna.DNA2;
const output = @import("output.zig");

const SliceReader = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn readByte(self: *SliceReader) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const c = self.buffer[self.pos];
        self.pos += 1;
        return c;
    }

    pub fn readAll(self: *SliceReader, dest: []u8) !usize {
        const remaining = self.buffer.len - self.pos;
        if (remaining == 0) return 0;
        const to_read = @min(dest.len, remaining);
        @memcpy(dest[0..to_read], self.buffer[self.pos..][0..to_read]);
        self.pos += to_read;
        return to_read;
    }

    pub fn readNoEof(self: *SliceReader, dest: []u8) !void {
        const bytes_read = try self.readAll(dest);
        if (bytes_read < dest.len) return error.EndOfStream;
    }
};

pub fn execute(args: ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig genomics - Genomic sequence alignment, mapping, and analysis
            \\
            \\Usage:
            \\  biozig genomics <command> [options]
            \\
            \\Commands:
            \\  align          Align sequencing reads to a reference
            \\  assemble       Assemble reads into contigs
            \\  code           Coding sequence algorithms
            \\  distance       Calculate genomic distances
            \\  gibbs          Gibbs sampling algorithms
            \\  hmm            Hidden Markov Model tools
            \\  index          Indexing algorithms
            \\  information    Information theory utilities
            \\  kmer           K-mer counting and manipulation
            \\  motif          Motif finding algorithms
            \\  msa            Multiple sequence alignment
            \\  search         Sequence search algorithms
            \\  suffix-tree    Suffix tree operations
            \\  organismal     Organismal and phenotype hierarchies
            \\  parse-bam      BAM parsing
            \\  parse-bcf      BCF parsing
            \\  parse-bed      BED parsing
            \\  parse-cram     CRAM parsing
            \\  parse-fasta    FASTA parsing
            \\  parse-fastq    FASTQ parsing
            \\  parse-gff3     GFF3 parsing
            \\  parse-gtf      GTF parsing
            \\  parse-sam      SAM parsing
            \\  parse-twobit   TwoBit parsing
            \\  parse-vcf      VCF parsing
            \\  genomic-index  Genomic index parsing
            \\
            \\Options:
            \\  -h, --help   Show this help message and exit
            \\  -f, --file   Input file path
            \\  -o, --output Output file path
            \\
        , .{});
        return;
    }
    if (args.run) |cmd| {
        _ = output;

        const file_path = args.file orelse args.input;
        var reader_opt: ?MMapReader = null;
        if (file_path) |p| {
            reader_opt = try MMapReader.init(std.heap.page_allocator, p);
        }
        defer if (reader_opt != null) reader_opt.?.deinit();

        if (std.mem.eql(u8, cmd, "align")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                var a: ?DNA2 = null;
                var b: ?DNA2 = null;
                if (try it.next()) |r| a = try DNA2.init(r.sequence, std.heap.page_allocator);
                if (try it.next()) |r| b = try DNA2.init(r.sequence, std.heap.page_allocator);
                if (a != null and b != null) {
                    defer a.?.deinit();
                    defer b.?.deinit();
                    const res = try algorithms.molecular.alignment.globalAlignment(std.heap.page_allocator, a.?.view(), b.?.view(), .{});
                    defer res.deinit(std.heap.page_allocator);
                    std.debug.print("{any}\n", .{res});
                } else {
                    std.debug.print("Error: align requires a FASTA file with at least 2 sequences.\n", .{});
                    std.process.exit(1);
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "assemble")) {
            if (reader_opt) |*reader| {
                var graph = algorithms.molecular.assembly.DeBruijnGraph.init(std.heap.page_allocator, 3);
                defer graph.deinit();
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                var count: usize = 0;
                while (try it.next()) |rec| {
                    try graph.addSequence(rec.sequence);
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "code")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                if (try it.next()) |rec| {
                    var dna = try DNA2.init(rec.sequence, std.heap.page_allocator);
                    defer dna.deinit();
                    const translated = try algorithms.molecular.coding.translateDNA(std.heap.page_allocator, dna.view());
                    defer std.heap.page_allocator.free(translated);
                    std.debug.print("{any}\n", .{translated});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "distance")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                var a: ?DNA2 = null;
                var b: ?DNA2 = null;
                if (try it.next()) |r| a = try DNA2.init(r.sequence, std.heap.page_allocator);
                if (try it.next()) |r| b = try DNA2.init(r.sequence, std.heap.page_allocator);
                if (a != null and b != null) {
                    defer a.?.deinit();
                    defer b.?.deinit();
                    const dist = try algorithms.molecular.distance.levenshteinDistance(std.heap.page_allocator, a.?.view(), b.?.view());
                    std.debug.print("{any}\n", .{dist});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "gibbs")) {
            if (reader_opt) |*reader| {
                var list = std.ArrayList([]const u8).empty;
                defer list.deinit(std.heap.page_allocator);
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                while (try it.next()) |rec| try list.append(std.heap.page_allocator, rec.sequence);
                if (list.items.len > 0) {
                    var sampler = algorithms.molecular.gibbs.GibbsSampler.init(std.heap.page_allocator, list.items, 5);
                    const motifs = try sampler.sample(10);
                    defer {
                        for (motifs) |m| std.heap.page_allocator.free(m);
                        std.heap.page_allocator.free(motifs);
                    }
                    std.debug.print("{any}\n", .{motifs});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "hmm")) {
            var hmm = try algorithms.molecular.hmm.HMM.init(std.heap.page_allocator, 2, 4);
            defer hmm.deinit();
            // std.debug.print("hmm\n", .{});
        } else if (std.mem.eql(u8, cmd, "index")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                if (try it.next()) |rec| {
                    var dna = try DNA2.init(rec.sequence, std.heap.page_allocator);
                    defer dna.deinit();
                    var fmi = try algorithms.molecular.indexing.FMIndex.init(std.heap.page_allocator, dna.view());
                    defer fmi.deinit();
                    // std.debug.print("fmindex\n", .{});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "information")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                if (try it.next()) |rec| {
                    var dna = try DNA2.init(rec.sequence, std.heap.page_allocator);
                    defer dna.deinit();
                    const entropy = algorithms.molecular.information.shannonEntropy(dna.view());
                    std.debug.print("{any}\n", .{entropy});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "kmer")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                if (try it.next()) |rec| {
                    var dna = try DNA2.init(rec.sequence, std.heap.page_allocator);
                    defer dna.deinit();
                    var counts = try algorithms.molecular.kmer.countKmers(std.heap.page_allocator, dna.view(), 3);
                    defer counts.deinit();
                    std.debug.print("{any}\n", .{counts});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "motif")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                var a: ?DNA2 = null;
                var b: ?DNA2 = null;
                if (try it.next()) |r| a = try DNA2.init(r.sequence, std.heap.page_allocator);
                if (try it.next()) |r| b = try DNA2.init(r.sequence, std.heap.page_allocator);
                if (a != null and b != null) {
                    defer a.?.deinit();
                    defer b.?.deinit();
                    const matches = try algorithms.molecular.motif.searchMotifExact(std.heap.page_allocator, a.?.view(), b.?.view());
                    defer std.heap.page_allocator.free(matches);
                    std.debug.print("{any}\n", .{matches});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "msa")) {
            if (reader_opt) |*reader| {
                var list = std.ArrayList([]const u8).empty;
                defer list.deinit(std.heap.page_allocator);
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                while (try it.next()) |rec| try list.append(std.heap.page_allocator, rec.sequence);
                if (list.items.len > 0) {
                    var ms = algorithms.molecular.msa.MSA.init(std.heap.page_allocator, list.items);
                    const aligned = try ms.alignProgressive(.{});
                    defer {
                        for (aligned) |x| std.heap.page_allocator.free(x);
                        std.heap.page_allocator.free(aligned);
                    }
                    std.debug.print("{any}\n", .{aligned});
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "search")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                if (try it.next()) |rec| {
                    var dna = try DNA2.init(rec.sequence, std.heap.page_allocator);
                    defer dna.deinit();
                    var fmi = try algorithms.molecular.indexing.FMIndex.init(std.heap.page_allocator, dna.view());
                    defer fmi.deinit();
                    const minimizers = try algorithms.molecular.indexing.computeMinimizers(std.heap.page_allocator, dna.view(), 10, 5);
                    defer std.heap.page_allocator.free(minimizers);
                    const layer = algorithms.molecular.search.SearchLayer.init(std.heap.page_allocator, &fmi, minimizers, dna.view());
                    _ = layer;
                    // search
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "suffix-tree")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                if (try it.next()) |rec| {
                    var tree = try algorithms.molecular.suffix_tree.SuffixTree.init(std.heap.page_allocator, rec.sequence);
                    defer tree.deinit();
                    try tree.build();
                    // suffix
                }
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "organismal")) {
            const hierarchy = algorithms.organismal.Hierarchy{ .nodes = &[_]algorithms.organismal.HierarchyNode{} };
            _ = hierarchy;
            // organismal
        } else if (std.mem.eql(u8, cmd, "parse-bed")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.bed.bedIterator(reader.data);
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-cram")) {
            if (reader_opt) |*reader| {
                var fbs = SliceReader{ .buffer = reader.data };
                var parser = ingestion.genomics.cram.CramParser.init(std.heap.page_allocator);
                var records = try parser.parseStream(&fbs);
                defer records.deinit(std.heap.page_allocator);
                std.debug.print("{any}\n", .{records.items});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-fasta")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fasta.fastaIterator(reader.data);
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.debug.print("Error: No input file provided for parse-fasta.\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-fastq")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.fastq.fastqIterator(reader.data);
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.debug.print("Error: No input file provided for parse-fastq.\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-gff3")) {
            if (reader_opt) |*reader| {
                var fbs = SliceReader{ .buffer = reader.data };
                var it = ingestion.genomics.gff3.gff3Iterator(std.heap.page_allocator, &fbs);
                defer it.deinit();
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-gtf")) {
            if (reader_opt) |*reader| {
                var fbs = SliceReader{ .buffer = reader.data };
                var it = ingestion.genomics.gtf.gtfIterator(std.heap.page_allocator, &fbs);
                defer it.deinit();
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-bam")) {
            if (reader_opt) |*reader| {
                var fbs = SliceReader{ .buffer = reader.data };
                var it = ingestion.genomics.bam.bamIterator(std.heap.page_allocator, &fbs);
                defer it.deinit();
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-twobit")) {
            if (reader_opt) |*reader| {
                var parser = try ingestion.genomics.twobit.TwoBitFile.init(std.heap.page_allocator, reader.data);
                defer parser.deinit();
                std.debug.print("{any}\n", .{parser});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-bcf")) {
            if (reader_opt) |*reader| {
                var fbs = SliceReader{ .buffer = reader.data };
                var parser = ingestion.genomics.bcf.BcfParser.init(std.heap.page_allocator);
                var records = try parser.parseStream(&fbs);
                defer records.deinit(std.heap.page_allocator);
                std.debug.print("{any}\n", .{records.items});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-sam")) {
            if (reader_opt) |*reader| {
                var fbs = SliceReader{ .buffer = reader.data };
                var it = ingestion.genomics.sam.samIterator(std.heap.page_allocator, &fbs);
                defer it.deinit();
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "parse-vcf")) {
            if (reader_opt) |*reader| {
                var it = ingestion.genomics.vcf.vcfIterator(reader.data);
                var count: usize = 0;
                while (try it.next()) |rec| {
                    _ = rec;
                    count += 1;
                }
                std.debug.print("{any}\n", .{count});
            } else {
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, cmd, "genomic-index")) {
            if (reader_opt) |*reader| {
                var idx = try ingestion.indices.genomic_index.parseTbi(std.heap.page_allocator, reader.data);
                defer idx.deinit();
                // index
            } else {
                std.process.exit(1);
            }
        } else {
            return error.UnknownSubcommand;
        }
    } else {
        std.debug.print("Error: No command provided for genomics.\n", .{});
        std.process.exit(1);
    }
}

test "genomics router test" {
    const args = ParsedArgs{ .run = "align" };
    try std.testing.expectEqualStrings("align", args.run.?);
}
