const std = @import("std");
const algorithms = @import("algorithms");
const timsa = algorithms.molecular.timsa;
const fasta = @import("ingestion").genomics.fasta;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const raw_args = try init.minimal.args.toSlice(allocator);

    var input_path: ?[]const u8 = null;
    var output_format: enum { fasta, json, clustal, stockholm } = .fasta;
    var memory_budget_bytes: usize = 100 * 1024 * 1024;
    var mode: timsa.TiMSAMode = .Align;
    
    var i: usize = 1;
    while (i < raw_args.len) : (i += 1) {
        const arg = raw_args[i];
        if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input")) {
            i += 1;
            if (i < raw_args.len) input_path = raw_args[i];
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--format")) {
            i += 1;
            if (i < raw_args.len) {
                const fmt = raw_args[i];
                if (std.mem.eql(u8, fmt, "json")) {
                    output_format = .json;
                } else if (std.mem.eql(u8, fmt, "clustal")) {
                    output_format = .clustal;
                } else if (std.mem.eql(u8, fmt, "stockholm")) {
                    output_format = .stockholm;
                } else {
                    output_format = .fasta;
                }
            }
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--memory")) {
            i += 1;
            if (i < raw_args.len) {
                memory_budget_bytes = std.fmt.parseInt(usize, raw_args[i], 10) catch (100 * 1024 * 1024);
                memory_budget_bytes *= 1024 * 1024;
            }
        } else if (std.mem.eql(u8, arg, "--mode")) {
            i += 1;
            if (i < raw_args.len) {
                if (std.mem.eql(u8, raw_args[i], "cluster")) {
                    mode = .Cluster;
                } else if (std.mem.eql(u8, raw_args[i], "align")) {
                    mode = .Align;
                } else if (std.mem.eql(u8, raw_args[i], "recomb")) {
                    mode = .Recomb;
                } else if (std.mem.eql(u8, raw_args[i], "rigidity")) {
                    mode = .Rigidity;
                } else if (std.mem.eql(u8, raw_args[i], "fast")) {
                    mode = .Fast;
                } else if (std.mem.eql(u8, raw_args[i], "domain")) {
                    mode = .Domain;
                } else if (std.mem.eql(u8, raw_args[i], "consensus")) {
                    mode = .Consensus;
                }
            }
        }
    }

    if (input_path == null) {
        std.debug.print("Usage: timsa -i <input.fasta> [-f fasta|json|clustal|stockholm]\n", .{});
        return;
    }

    const mmap = @import("core").io.mmap;
    
    var reader = try mmap.MMapReader.init(allocator, input_path.?);
    defer reader.deinit();
    
    var iter = fasta.FastaIterator.init(reader.data);
    
    var headers = std.ArrayListUnmanaged([]const u8).empty;
    defer headers.deinit(allocator);
    
    var raw_sequences = std.ArrayListUnmanaged([]const u8).empty;
    defer {
        for (raw_sequences.items) |s| allocator.free(s);
        raw_sequences.deinit(allocator);
    }
    
    while (try iter.next()) |record| {
        try headers.append(allocator, record.header);
        const clean = try record.cleanSequence(allocator);
        try raw_sequences.append(allocator, clean);
    }
    
    if (raw_sequences.items.len == 0) {
        std.debug.print("Error: No sequences found in input FASTA.\n", .{});
        return;
    }

    var engine = timsa.TiMSA.init(allocator, .{ 
        .mode = mode,
        .memory_budget_bytes = memory_budget_bytes 
    });
    const result = try engine.executeAlignment(raw_sequences.items);
    defer {
        for (result.aligned_sequences) |s| allocator.free(s);
        allocator.free(result.aligned_sequences);
        allocator.free(result.consensus);
    }

    switch (output_format) {
        .fasta => {
            if (mode == .Recomb and result.recomb_pairs != null) {
                var h1_count: usize = 0;
                for (result.recomb_pairs.?) |pair| {
                    if (pair.dimension == 1) {
                        h1_count += 1;
                    }
                }
                std.debug.print("TiMSA Recombination Detection: Found {} H1 cycles (recombination breakpoints)\n", .{h1_count});
            }
            if (mode == .Rigidity and result.rigidity_scores != null) {
                var rigid_columns: usize = 0;
                var max_rigidity: f64 = 0.0;
                for (result.rigidity_scores.?) |score| {
                    if (score > 0.05) rigid_columns += 1;
                    if (score > max_rigidity) max_rigidity = score;
                }
                std.debug.print("TiMSA Rigidity (Ablation) Analysis: Found {} highly rigid structural sentinels (Max dWp: {d:.4})\n", .{rigid_columns, max_rigidity});
            }
            
            for (result.aligned_sequences, 0..) |aligned_seq, seq_idx| {
                std.debug.print(">{s}\n", .{headers.items[seq_idx]});
                
                var pos: usize = 0;
                while (pos < aligned_seq.len) {
                    const end = @min(pos + 80, aligned_seq.len);
                    std.debug.print("{s}\n", .{aligned_seq[pos..end]});
                    pos = end;
                }
            }
            
            std.debug.print(">TiMSA_Consensus\n", .{});
            var pos: usize = 0;
            while (pos < result.consensus.len) {
                const end = @min(pos + 80, result.consensus.len);
                std.debug.print("{s}\n", .{result.consensus[pos..end]});
                pos = end;
            }
        },
        .json => {
            std.debug.print("{{\n", .{});
            std.debug.print("  \"consensus\": \"{s}\",\n", .{result.consensus});
            std.debug.print("  \"alignments\": [\n", .{});
            
            for (result.aligned_sequences, 0..) |aligned_seq, seq_idx| {
                std.debug.print("    {{\"id\": \"{s}\", \"seq\": \"{s}\"}}", .{headers.items[seq_idx], aligned_seq});
                if (seq_idx < result.aligned_sequences.len - 1) {
                    std.debug.print(",\n", .{});
                } else {
                    std.debug.print("\n", .{});
                }
            }
            std.debug.print("  ]\n", .{});
            std.debug.print("}}\n", .{});
        },
        .clustal => {
            std.debug.print("CLUSTAL W (1.81) multiple sequence alignment\n\n", .{});
            const seq_len = result.aligned_sequences[0].len;
            var pos: usize = 0;
            while (pos < seq_len) {
                const end = @min(pos + 60, seq_len);
                for (result.aligned_sequences, 0..) |aligned_seq, seq_idx| {
                    const header = headers.items[seq_idx];
                    var padded_header: [16]u8 = [_]u8{' '} ** 16;
                    const copy_len = @min(header.len, 16);
                    @memcpy(padded_header[0..copy_len], header[0..copy_len]);
                    std.debug.print("{s} {s}\n", .{padded_header, aligned_seq[pos..end]});
                }
                std.debug.print("\n", .{});
                pos = end;
            }
        },
        .stockholm => {
            std.debug.print("# STOCKHOLM 1.0\n", .{});
            for (result.aligned_sequences, 0..) |aligned_seq, seq_idx| {
                const header = headers.items[seq_idx];
                std.debug.print("{s} {s}\n", .{header, aligned_seq});
            }
            std.debug.print("//\n", .{});
        }
    }
}
