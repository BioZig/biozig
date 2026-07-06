const std = @import("std");
const algorithms = @import("algorithms");
const ingestion = @import("ingestion");
const core = @import("core");
const c_api = @import("c_api.zig");

const PhyloTree = @import("visualization").phylogeny.PhyloTree;
const evolutionary = algorithms.evolutionary;
const newick = ingestion.evolutionary.newick;
const nexus = ingestion.evolutionary.nexus;
const phyloxml = ingestion.evolutionary.phyloxml;
const MMapReader = core.io.mmap.MMapReader;

export fn biozig_evolutionary_upgma(n: usize, dist_flat: [*c]const f64, labels_c: [*c][*c]const u8) callconv(.c) ?*anyopaque {
    const arena_ptr = c_api.c_arena orelse return null;
    const alloc = arena_ptr.allocator();

    var dist_matrix = alloc.alloc([]const f64, n) catch return null;
    for (0..n) |i| {
        dist_matrix[i] = dist_flat[i * n .. i * n + n];
    }

    var labels = alloc.alloc([]const u8, n) catch return null;
    for (0..n) |i| {
        labels[i] = std.mem.span(labels_c[i]);
    }

    const tree = evolutionary.upgma(alloc, dist_matrix, labels) catch return null;
    const tree_ptr = alloc.create(PhyloTree) catch return null;
    tree_ptr.* = tree;
    return @ptrCast(tree_ptr);
}

export fn biozig_evolutionary_neighbor_joining(n: usize, dist_flat: [*c]const f64, labels_c: [*c][*c]const u8) callconv(.c) ?*anyopaque {
    const arena_ptr = c_api.c_arena orelse return null;
    const alloc = arena_ptr.allocator();

    var dist_matrix = alloc.alloc([]const f64, n) catch return null;
    for (0..n) |i| {
        dist_matrix[i] = dist_flat[i * n .. i * n + n];
    }

    var labels = alloc.alloc([]const u8, n) catch return null;
    for (0..n) |i| {
        labels[i] = std.mem.span(labels_c[i]);
    }

    const tree = evolutionary.neighborJoining(alloc, dist_matrix, labels) catch return null;
    const tree_ptr = alloc.create(PhyloTree) catch return null;
    tree_ptr.* = tree;
    return @ptrCast(tree_ptr);
}

export fn biozig_evolutionary_parsimony_fitch(tree_opaque: ?*anyopaque, leaf_ids: [*c]const usize, states: [*c]const usize, num_leaves: usize) callconv(.c) c_int {
    const arena_ptr = c_api.c_arena orelse return -1;
    const alloc = arena_ptr.allocator();
    const tree_ptr: *PhyloTree = @ptrCast(@alignCast(tree_opaque orelse return -1));

    var map = std.AutoHashMap(usize, usize).init(alloc);
    for (0..num_leaves) |i| {
        map.put(leaf_ids[i], states[i]) catch return -1;
    }

    const score = evolutionary.parsimonyFitch(alloc, tree_ptr.*, map) catch return -1;
    return @intCast(score);
}

export fn biozig_evolutionary_felsenstein_pruning(tree_opaque: ?*anyopaque, leaf_ids: [*c]const usize, states: [*c]const usize, num_leaves: usize, mu: f64) callconv(.c) f64 {
    const arena_ptr = c_api.c_arena orelse return -1.0;
    const alloc = arena_ptr.allocator();
    const tree_ptr: *PhyloTree = @ptrCast(@alignCast(tree_opaque orelse return -1.0));

    var map = std.AutoHashMap(usize, evolutionary.Nucleotide).init(alloc);
    for (0..num_leaves) |i| {
        map.put(leaf_ids[i], @enumFromInt(states[i])) catch return -1.0;
    }

    const likelihood = evolutionary.felsensteinPruning(alloc, tree_ptr.*, map, mu) catch return -1.0;
    return likelihood;
}

pub const CBiozigTreeList = extern struct {
    trees: [*c]?*anyopaque,
    count: usize,
};

export fn biozig_evolutionary_nearest_neighbor_interchange(tree_opaque: ?*anyopaque) callconv(.c) CBiozigTreeList {
    const err_res = CBiozigTreeList{ .trees = null, .count = 0 };
    const arena_ptr = c_api.c_arena orelse return err_res;
    const alloc = arena_ptr.allocator();
    const tree_ptr: *PhyloTree = @ptrCast(@alignCast(tree_opaque orelse return err_res));

    const list = evolutionary.nearestNeighborInterchange(alloc, tree_ptr.*) catch return err_res;

    var ptrs = alloc.alloc(?*anyopaque, list.items.len) catch return err_res;
    for (list.items, 0..) |t, i| {
        const p = alloc.create(PhyloTree) catch return err_res;
        p.* = t;
        ptrs[i] = @ptrCast(p);
    }

    return CBiozigTreeList{
        .trees = ptrs.ptr,
        .count = list.items.len,
    };
}

export fn biozig_evolutionary_subtree_pruning_regrafting(tree_opaque: ?*anyopaque) callconv(.c) CBiozigTreeList {
    const err_res = CBiozigTreeList{ .trees = null, .count = 0 };
    const arena_ptr = c_api.c_arena orelse return err_res;
    const alloc = arena_ptr.allocator();
    const tree_ptr: *PhyloTree = @ptrCast(@alignCast(tree_opaque orelse return err_res));

    const list = evolutionary.subtreePruningRegrafting(alloc, tree_ptr.*) catch return err_res;

    var ptrs = alloc.alloc(?*anyopaque, list.items.len) catch return err_res;
    for (list.items, 0..) |t, i| {
        const p = alloc.create(PhyloTree) catch return err_res;
        p.* = t;
        ptrs[i] = @ptrCast(p);
    }

    return CBiozigTreeList{
        .trees = ptrs.ptr,
        .count = list.items.len,
    };
}

export fn biozig_evolutionary_bayesian_mcmc(tree_opaque: ?*anyopaque, leaf_ids: [*c]const usize, states: [*c]const usize, num_leaves: usize, iterations: usize) callconv(.c) ?*anyopaque {
    const arena_ptr = c_api.c_arena orelse return null;
    const alloc = arena_ptr.allocator();
    const tree_ptr: *PhyloTree = @ptrCast(@alignCast(tree_opaque orelse return null));

    var map = std.AutoHashMap(usize, evolutionary.Nucleotide).init(alloc);
    for (0..num_leaves) |i| {
        map.put(leaf_ids[i], @enumFromInt(states[i])) catch return null;
    }

    const res_tree = evolutionary.bayesianMCMC(alloc, tree_ptr.*, map, iterations) catch return null;
    const res_ptr = alloc.create(PhyloTree) catch return null;
    res_ptr.* = res_tree;
    return @ptrCast(res_ptr);
}

export fn biozig_ingestion_parse_newick(filepath_c: [*c]const u8) callconv(.c) ?*anyopaque {
    const arena_ptr = c_api.c_arena orelse return null;
    const alloc = arena_ptr.allocator();
    const filepath = std.mem.span(filepath_c);

    var mmap = MMapReader.init(alloc, filepath) catch return null;
    defer mmap.deinit();

    const tree = newick.parseNewick(alloc, mmap.data) catch return null;
    const tree_ptr = alloc.create(PhyloTree) catch return null;
    tree_ptr.* = tree;
    return @ptrCast(tree_ptr);
}

export fn biozig_ingestion_parse_nexus(filepath_c: [*c]const u8) callconv(.c) ?*anyopaque {
    const arena_ptr = c_api.c_arena orelse return null;
    const alloc = arena_ptr.allocator();
    const filepath = std.mem.span(filepath_c);

    var mmap = MMapReader.init(alloc, filepath) catch return null;
    defer mmap.deinit();

    const tree = nexus.parseNexus(alloc, mmap.data) catch return null;
    const tree_ptr = alloc.create(PhyloTree) catch return null;
    tree_ptr.* = tree;
    return @ptrCast(tree_ptr);
}

export fn biozig_ingestion_parse_phyloxml(filepath_c: [*c]const u8) callconv(.c) ?*anyopaque {
    const arena_ptr = c_api.c_arena orelse return null;
    const alloc = arena_ptr.allocator();
    const filepath = std.mem.span(filepath_c);

    var mmap = MMapReader.init(alloc, filepath) catch return null;
    defer mmap.deinit();

    const tree = phyloxml.parsePhyloXml(alloc, mmap.data) catch return null;
    const tree_ptr = alloc.create(PhyloTree) catch return null;
    tree_ptr.* = tree;
    return @ptrCast(tree_ptr);
}
