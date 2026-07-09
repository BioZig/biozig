const std = @import("std");
const ingestion = @import("ingestion");
const net = @import("net");
const analytics = @import("analytics");
const FastaIterator = ingestion.genomics.fasta.FastaIterator;
const slidingWindowMetrics = analytics.sequence.metrics.slidingWindowMetrics;

pub fn execute(allocator: std.mem.Allocator, args: []const [:0]const u8) !void {
    var db: []const u8 = "ncbi";
    var query: []const u8 = "NC_045512.2";
    var analyze: []const u8 = "gc_content";

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--db") and i + 1 < args.len) {
            db = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--query") and i + 1 < args.len) {
            query = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--analyze") and i + 1 < args.len) {
            analyze = args[i + 1];
            i += 1;
        }
    }

    std.debug.print("Initializing BioZig Stream-and-Fold Engine...\n", .{});
    std.debug.print("Target DB: {s}\n", .{db});
    std.debug.print("Query Accession: {s}\n", .{query});
    std.debug.print("Analytical Algorithm: {s}\n\n", .{analyze});

    var io_context = std.Io.Threaded.init(allocator, .{});

    var network_stream = try net.createStream(allocator, io_context.io(), db, query);
    defer network_stream.deinit(io_context.io());

    var transfer_buffer: [8192]u8 = undefined;
    var curl_reader = network_stream.child.stdout.?.readerStreaming(io_context.io(), &transfer_buffer);

    var sieve = try allocator.create(net.bitsieve.BitSieve);
    defer allocator.destroy(sieve);
    sieve.* = net.bitsieve.BitSieve.init(io_context.io());

    // Spawn Thread 2 (Analytics / CPU)
    var analytics_thread = try std.Thread.spawn(.{}, struct {
        fn run(thread_allocator: std.mem.Allocator, thread_db: []const u8, thread_analyze: []const u8, thread_sieve: *net.bitsieve.BitSieve) !void {
            var reader = thread_sieve.reader();
            try streamAndFold(thread_allocator, thread_db, thread_analyze, &reader);
        }
    }.run, .{ allocator, db, analyze, sieve });

    // Thread 1 (Network) -> Pump data into BitSieve
    if (std.mem.endsWith(u8, query, ".gz")) {
        var decomp_buf: [std.compress.flate.max_window_len]u8 = undefined;
        var decompressor = std.compress.flate.Decompress.init(&curl_reader.interface, .gzip, &decomp_buf);
        try sieve.produce(&decompressor.reader);
    } else {
        try sieve.produce(&curl_reader.interface);
    }

    analytics_thread.join();
}

fn streamAndFold(allocator: std.mem.Allocator, db: []const u8, analyze: []const u8, reader: anytype) !void {
    if (std.mem.eql(u8, db, "ncbi") or std.mem.eql(u8, db, "ucsc") or std.mem.eql(u8, db, "uniprot") or std.mem.eql(u8, db, "ensembl") or std.mem.eql(u8, db, "ncbi_ftp")) {
        var iter_buf: [65536]u8 = undefined;
        var fasta_it = ingestion.genomics.fasta.fastaStreamIterator(reader, &iter_buf);
        try processFastaAnalytics(allocator, analyze, &fasta_it);
    } else if (std.mem.eql(u8, db, "pdb")) {
        try processPdbAnalytics(allocator, analyze, reader);
    } else if (std.mem.eql(u8, db, "chembl")) {
        try processChemblAnalytics(allocator, analyze, reader);
    }
}

fn processFastaAnalytics(allocator: std.mem.Allocator, analyze: []const u8, fasta_it: anytype) !void {
    var header_buf: [1024]u8 = undefined;
    while (try fasta_it.nextHeader(&header_buf)) |header| {
        std.debug.print("=== BIOLOGICAL ANALYTICS RESULT ===\n", .{});
        std.debug.print("Header: {s}\n", .{header});
        
        if (std.mem.eql(u8, analyze, "gc_content")) {
            std.debug.print("Running Streaming Sliding Window GC Metrics (Window: 10000bp, Step: 10000bp)...\n", .{});
            const metrics = try analytics.sequence.metrics.streamingSlidingWindowMetrics(allocator, fasta_it, 10000, 10000);
            defer allocator.free(metrics);
            
            for (metrics, 0..) |m, idx| {
                std.debug.print("  Window {d}: GC Content = {d:.2}%, GC Skew = {d:.4}\n", .{idx + 1, m.gc_content * 100.0, m.gc_skew});
            }
        } else if (std.mem.eql(u8, analyze, "titv") or std.mem.eql(u8, analyze, "markov")) {
            std.debug.print("Running O(1) Markov Transition/Transversion (Ti/Tv) Inference...\n", .{});
            const transitions = try analytics.sequence.markov.streamingTransitions(allocator, fasta_it);
            defer allocator.destroy(transitions);
            
            const ti = transitions['A']['G'] + transitions['G']['A'] + transitions['C']['T'] + transitions['T']['C'];
            const tv = transitions['A']['C'] + transitions['C']['A'] + transitions['A']['T'] + transitions['T']['A'] + transitions['C']['G'] + transitions['G']['C'] + transitions['G']['T'] + transitions['T']['G'];
            
            const titv_ratio = if (tv > 0) @as(f64, @floatFromInt(ti)) / @as(f64, @floatFromInt(tv)) else 0.0;
            
            std.debug.print("  Total Transitions (Ti): {d}\n", .{ti});
            std.debug.print("  Total Transversions (Tv): {d}\n", .{tv});
            std.debug.print("  [Ti/Tv Ratio]: {d:.4}\n", .{titv_ratio});
        } else if (std.mem.eql(u8, analyze, "kmer")) {
            std.debug.print("Running O(1) Di-Peptide Frequency Counter...\n", .{});
            const dipeptides = try analytics.sequence.kmer_stats.streamingDipeptideFrequencies(allocator, fasta_it);
            defer allocator.destroy(dipeptides);
            
            std.debug.print("  [L -> L] (Leucine-Leucine): {d}\n", .{dipeptides['L']['L']});
            std.debug.print("  [S -> P] (Serine-Proline): {d}\n", .{dipeptides['S']['P']});
        } else if (std.mem.eql(u8, analyze, "comprehensive")) {
            std.debug.print("Running Comprehensive O(1) Streaming Pipeline (GC, Skew, Entropy, Markov)...\n", .{});
            
            var g: f64 = 0;
            var c: f64 = 0;
            var a: f64 = 0;
            var t: f64 = 0;
            var transitions = try allocator.create([256][256]u64);
            @memset(std.mem.sliceAsBytes(transitions[0..]), 0);
            defer allocator.destroy(transitions);
            
            var prev_base: u8 = 0;
            var total_bases: f64 = 0;
            var counts = [_]f64{0} ** 256;

            while (try fasta_it.nextSequenceChunk()) |chunk| {
                for (chunk) |char| {
                    const base = std.ascii.toUpper(char);
                    if (base == 'A' or base == 'C' or base == 'G' or base == 'T') {
                        counts[base] += 1;
                        total_bases += 1;
                        if (base == 'G') g += 1 else if (base == 'C') c += 1 else if (base == 'A') a += 1 else if (base == 'T') t += 1;
                        
                        if (prev_base != 0) {
                            transitions[prev_base][base] += 1;
                        }
                        prev_base = base;
                    }
                }
            }
            
            const gc_total = g + c;
            const gc_content = if (total_bases > 0) gc_total / total_bases else 0.0;
            const gc_skew = if (gc_total > 0) (g - c) / gc_total else 0.0;
            
            var entropy: f64 = 0.0;
            for (counts) |count| {
                if (count > 0) {
                    const p = count / total_bases;
                    entropy -= p * @log2(p);
                }
            }
            
            std.debug.print("  Length: {d:.0} bp\n", .{total_bases});
            std.debug.print("  GC Content: {d:.2}%\n", .{gc_content * 100.0});
            std.debug.print("  GC Skew: {d:.4}\n", .{gc_skew});
            std.debug.print("  Shannon Entropy: {d:.4} bits\n", .{entropy});
            std.debug.print("  Markov [A -> C]: {d}\n", .{transitions['A']['C']});
            std.debug.print("  Markov [C -> G]: {d}\n", .{transitions['C']['G']});
        }
        std.debug.print("===================================\n", .{});
    }
}

fn processPdbAnalytics(allocator: std.mem.Allocator, analyze: []const u8, reader: anytype) !void {
    _ = allocator;
    std.debug.print("=== STRUCTURAL ANALYTICS RESULT ===\n", .{});
    
    var iter_buf: [65536]u8 = undefined;
    var pdb_it = ingestion.structural.pdb.pdbStreamIterator(reader, &iter_buf);
    
    if (std.mem.eql(u8, analyze, "pca") or std.mem.eql(u8, analyze, "contact_map")) {
        std.debug.print("Running O(1) Spatial Approximation (Contact Map / C-alpha)...\n", .{});
        const stats = try analytics.dimensionality.pca.streamingPcaBackbone(&pdb_it);
        std.debug.print("  Total ATOM Records: {d}\n", .{stats.total_atoms});
        std.debug.print("  Alpha Carbons (Backbone Size): {d}\n", .{stats.ca_atoms});
        std.debug.print("  Computed C-alpha Contact Map Matrix: {d}x{d}\n", .{stats.ca_atoms, stats.ca_atoms});
    } else {
        const stats = try analytics.dimensionality.pca.streamingPcaBackbone(&pdb_it);
        std.debug.print("Streamed PDB File: Total ATOM records = {d}\n", .{stats.total_atoms});
    }
    std.debug.print("===================================\n", .{});
}

fn processChemblAnalytics(allocator: std.mem.Allocator, analyze: []const u8, reader: anytype) !void {
    _ = allocator;
    std.debug.print("=== CHEMINFORMATICS ANALYTICS RESULT ===\n", .{});
    
    var iter_buf: [65536]u8 = undefined;
    var smiles_it = ingestion.cheminformatics.smiles.smilesStreamIterator(reader, &iter_buf);
    
    if (std.mem.eql(u8, analyze, "features")) {
        std.debug.print("Running O(1) Cheminformatics Feature Extractor...\n", .{});
        const features = try analytics.cheminformatics.features.streamingFeatureExtractor(&smiles_it);
        std.debug.print("  Found 'canonical_smiles' entries: {d}\n", .{features.smiles_found});
        std.debug.print("  Total JSON payload processed: {d} bytes\n", .{features.bytes_streamed});
    } else {
        const features = try analytics.cheminformatics.features.streamingFeatureExtractor(&smiles_it);
        std.debug.print("Streamed ChEMBL JSON: Processed {d} bytes directly from API.\n", .{features.bytes_streamed});
    }
    std.debug.print("===================================\n", .{});
}
