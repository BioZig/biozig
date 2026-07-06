const std = @import("std");
const molecular = @import("molecular");
const algorithms = @import("algorithms");
const c_api = @import("c_api.zig");

fn getArena() ?std.mem.Allocator {
    if (c_api.c_arena) |arena| {
        return arena.allocator();
    }
    return null;
}

// distance.zig
export fn biozig_hamming_distance(seq_a_c: [*c]const u8, seq_b_c: [*c]const u8) callconv(.c) c_longlong {
    const alloc = getArena() orelse return -1;
    const seq_a = std.mem.span(seq_a_c);
    const seq_b = std.mem.span(seq_b_c);

    const dna2_a = molecular.dna.DNA2.init(seq_a, alloc) catch return -1;
    const dna2_b = molecular.dna.DNA2.init(seq_b, alloc) catch return -1;

    const dist = algorithms.molecular.distance.hammingDistance(dna2_a.view(), dna2_b.view()) catch return -1;
    return @as(c_longlong, @intCast(dist));
}

export fn biozig_levenshtein_distance(seq_a_c: [*c]const u8, seq_b_c: [*c]const u8) callconv(.c) c_longlong {
    const alloc = getArena() orelse return -1;
    const seq_a = std.mem.span(seq_a_c);
    const seq_b = std.mem.span(seq_b_c);

    const dna2_a = molecular.dna.DNA2.init(seq_a, alloc) catch return -1;
    const dna2_b = molecular.dna.DNA2.init(seq_b, alloc) catch return -1;

    const dist = algorithms.molecular.distance.levenshteinDistance(alloc, dna2_a.view(), dna2_b.view()) catch return -1;
    return @as(c_longlong, @intCast(dist));
}

// assembly.zig
pub const CBiozigDeBruijnGraph = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_debruijn_graph_create(k: c_int) callconv(.c) CBiozigDeBruijnGraph {
    const alloc = getArena() orelse return .{ .ptr = null };
    const dbg = alloc.create(algorithms.molecular.assembly.DeBruijnGraph) catch return .{ .ptr = null };
    dbg.* = algorithms.molecular.assembly.DeBruijnGraph.init(alloc, @intCast(k));
    return .{ .ptr = dbg };
}

export fn biozig_debruijn_graph_add_sequence(dbg_c: CBiozigDeBruijnGraph, seq_c: [*c]const u8) callconv(.c) c_int {
    if (dbg_c.ptr == null) return -1;
    const dbg: *algorithms.molecular.assembly.DeBruijnGraph = @ptrCast(@alignCast(dbg_c.ptr));
    const seq = std.mem.span(seq_c);
    dbg.addSequence(seq) catch return -1;
    return 0;
}

export fn biozig_debruijn_graph_destroy(dbg_c: CBiozigDeBruijnGraph) callconv(.c) void {
    if (dbg_c.ptr == null) return;
    const dbg: *algorithms.molecular.assembly.DeBruijnGraph = @ptrCast(@alignCast(dbg_c.ptr));
    dbg.deinit();
}

// motif.zig
pub const CBiozigMotifHits = extern struct {
    positions: [*c]c_longlong,
    count: c_int,
};

export fn biozig_search_motif_exact(seq_c: [*c]const u8, motif_c: [*c]const u8) callconv(.c) CBiozigMotifHits {
    const alloc = getArena() orelse return .{ .positions = null, .count = 0 };
    const seq = std.mem.span(seq_c);
    const motif = std.mem.span(motif_c);

    const dna2_seq = molecular.dna.DNA2.init(seq, alloc) catch return .{ .positions = null, .count = 0 };
    const dna2_motif = molecular.dna.DNA2.init(motif, alloc) catch return .{ .positions = null, .count = 0 };

    const hits = algorithms.molecular.motif.searchMotifExact(alloc, dna2_seq.view(), dna2_motif.view()) catch return .{ .positions = null, .count = 0 };

    const c_hits = alloc.alloc(c_longlong, hits.len) catch return .{ .positions = null, .count = 0 };
    for (hits, 0..) |h, i| {
        c_hits[i] = @intCast(h);
    }
    return .{ .positions = c_hits.ptr, .count = @intCast(hits.len) };
}

// kmer.zig
export fn biozig_count_kmers(seq_c: [*c]const u8, k: c_int) callconv(.c) c_longlong {
    const alloc = getArena() orelse return -1;
    const seq = std.mem.span(seq_c);
    const dna2_seq = molecular.dna.DNA2.init(seq, alloc) catch return -1;

    var counts = algorithms.molecular.kmer.countKmers(alloc, dna2_seq.view(), @intCast(k)) catch return -1;
    defer counts.deinit();

    return @intCast(counts.count());
}

// suffix_tree.zig
pub const CBiozigSuffixTree = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_suffix_tree_create(seq_c: [*c]const u8) callconv(.c) CBiozigSuffixTree {
    const alloc = getArena() orelse return .{ .ptr = null };
    const seq = std.mem.span(seq_c);

    const tree = alloc.create(algorithms.molecular.suffix_tree.SuffixTree) catch return .{ .ptr = null };
    tree.* = algorithms.molecular.suffix_tree.SuffixTree.init(alloc, seq) catch return .{ .ptr = null };
    tree.build() catch return .{ .ptr = null };

    return .{ .ptr = tree };
}

export fn biozig_suffix_tree_destroy(tree_c: CBiozigSuffixTree) callconv(.c) void {
    if (tree_c.ptr == null) return;
    const tree: *algorithms.molecular.suffix_tree.SuffixTree = @ptrCast(@alignCast(tree_c.ptr));
    tree.deinit();
}

// hmm.zig
pub const CBiozigHMM = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_hmm_create(num_states: c_int, num_emissions: c_int) callconv(.c) CBiozigHMM {
    const alloc = getArena() orelse return .{ .ptr = null };
    const hmm = alloc.create(algorithms.molecular.hmm.HMM) catch return .{ .ptr = null };
    hmm.* = algorithms.molecular.hmm.HMM.init(alloc, @intCast(num_states), @intCast(num_emissions)) catch return .{ .ptr = null };
    return .{ .ptr = hmm };
}

export fn biozig_hmm_destroy(hmm_c: CBiozigHMM) callconv(.c) void {
    if (hmm_c.ptr == null) return;
    const hmm: *algorithms.molecular.hmm.HMM = @ptrCast(@alignCast(hmm_c.ptr));
    hmm.deinit();
}

export fn biozig_hmm_viterbi(hmm_c: CBiozigHMM, emissions_c: [*c]const c_longlong, emissions_len: c_int) callconv(.c) CBiozigMotifHits {
    const alloc = getArena() orelse return .{ .positions = null, .count = 0 };
    if (hmm_c.ptr == null) return .{ .positions = null, .count = 0 };
    const hmm: *const algorithms.molecular.hmm.HMM = @ptrCast(@alignCast(hmm_c.ptr));

    const emissions_slice = emissions_c[0..@intCast(emissions_len)];
    const em_usizes = alloc.alloc(usize, emissions_slice.len) catch return .{ .positions = null, .count = 0 };
    for (emissions_slice, 0..) |em, i| {
        em_usizes[i] = @intCast(em);
    }

    const states = hmm.viterbi(alloc, em_usizes) catch return .{ .positions = null, .count = 0 };
    const c_states = alloc.alloc(c_longlong, states.len) catch return .{ .positions = null, .count = 0 };
    for (states, 0..) |s, i| {
        c_states[i] = @intCast(s);
    }

    return .{ .positions = c_states.ptr, .count = @intCast(states.len) };
}

// indexing.zig
pub const CBiozigFMIndex = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_fmindex_create(seq_c: [*c]const u8) callconv(.c) CBiozigFMIndex {
    const alloc = getArena() orelse return .{ .ptr = null };
    const seq = std.mem.span(seq_c);
    const dna2_seq = molecular.dna.DNA2.init(seq, alloc) catch return .{ .ptr = null };

    const fmi = alloc.create(algorithms.molecular.indexing.FMIndex) catch return .{ .ptr = null };
    fmi.* = algorithms.molecular.indexing.FMIndex.init(alloc, dna2_seq.view()) catch return .{ .ptr = null };

    return .{ .ptr = fmi };
}

pub const CBiozigRange = extern struct {
    start: c_longlong,
    end: c_longlong,
};

export fn biozig_fmindex_count(fmi_c: CBiozigFMIndex, query_c: [*c]const u8) callconv(.c) CBiozigRange {
    if (fmi_c.ptr == null) return .{ .start = -1, .end = -1 };
    const alloc = getArena() orelse return .{ .start = -1, .end = -1 };

    const fmi: *const algorithms.molecular.indexing.FMIndex = @ptrCast(@alignCast(fmi_c.ptr));
    const query = std.mem.span(query_c);
    const dna2_query = molecular.dna.DNA2.init(query, alloc) catch return .{ .start = -1, .end = -1 };

    const res = fmi.count(dna2_query.view());
    return .{ .start = @intCast(res.start), .end = @intCast(res.end) };
}

export fn biozig_fmindex_destroy(fmi_c: CBiozigFMIndex) callconv(.c) void {
    if (fmi_c.ptr == null) return;
    const fmi: *algorithms.molecular.indexing.FMIndex = @ptrCast(@alignCast(fmi_c.ptr));
    fmi.deinit();
}

// msa.zig
pub const CBiozigMSA = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_msa_create(sequences_c: [*c]const [*c]const u8, count: c_int) callconv(.c) CBiozigMSA {
    const alloc = getArena() orelse return .{ .ptr = null };

    const seq_slice = sequences_c[0..@intCast(count)];
    const zig_seqs = alloc.alloc([]const u8, @intCast(count)) catch return .{ .ptr = null };
    for (seq_slice, 0..) |s, i| {
        zig_seqs[i] = std.mem.span(s);
    }

    const msa = alloc.create(algorithms.molecular.msa.MSA) catch return .{ .ptr = null };
    msa.* = algorithms.molecular.msa.MSA.init(alloc, zig_seqs);

    return .{ .ptr = msa };
}

// gibbs.zig
pub const CBiozigGibbsSampler = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_gibbs_sampler_create(sequences_c: [*c]const [*c]const u8, count: c_int, motif_len: c_int) callconv(.c) CBiozigGibbsSampler {
    const alloc = getArena() orelse return .{ .ptr = null };

    const seq_slice = sequences_c[0..@intCast(count)];
    const zig_seqs = alloc.alloc([]const u8, @intCast(count)) catch return .{ .ptr = null };
    for (seq_slice, 0..) |s, i| {
        zig_seqs[i] = std.mem.span(s);
    }

    const sampler = alloc.create(algorithms.molecular.gibbs.GibbsSampler) catch return .{ .ptr = null };
    sampler.* = algorithms.molecular.gibbs.GibbsSampler.init(alloc, zig_seqs, @intCast(motif_len));

    return .{ .ptr = sampler };
}

// search.zig
pub const CBiozigSearchLayer = extern struct {
    ptr: ?*anyopaque,
};

export fn biozig_search_layer_create(fmi_c: CBiozigFMIndex, ref_seq_c: [*c]const u8) callconv(.c) CBiozigSearchLayer {
    const alloc = getArena() orelse return .{ .ptr = null };
    if (fmi_c.ptr == null) return .{ .ptr = null };
    const fmi: *algorithms.molecular.indexing.FMIndex = @ptrCast(@alignCast(fmi_c.ptr));

    const ref_seq = std.mem.span(ref_seq_c);
    const dna2_ref = molecular.dna.DNA2.init(ref_seq, alloc) catch return .{ .ptr = null };

    const minimizers = algorithms.molecular.indexing.computeMinimizers(alloc, dna2_ref.view(), 10, 5) catch return .{ .ptr = null };

    const search_layer = alloc.create(algorithms.molecular.search.SearchLayer) catch return .{ .ptr = null };
    search_layer.* = algorithms.molecular.search.SearchLayer.init(alloc, fmi, minimizers, dna2_ref.view());

    return .{ .ptr = search_layer };
}
