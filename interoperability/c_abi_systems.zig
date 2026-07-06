const std = @import("std");
const systems = @import("systems");
const algorithms = @import("algorithms");
const ingestion = @import("ingestion");
const c_api = @import("c_api.zig");
const core = @import("core");

// -----------------------------------------------------------------------------
// Core Systems Data Structures
// -----------------------------------------------------------------------------

pub const CBiozigNetwork = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_network_create() callconv(.c) CBiozigNetwork {
    const arena_ptr = c_api.c_arena orelse return CBiozigNetwork{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.network.Network) catch return CBiozigNetwork{ .ptr = null };
    net_ptr.* = systems.network.Network.init(alloc);
    return CBiozigNetwork{ .ptr = net_ptr };
}

export fn biozig_systems_network_add_node(net_c: CBiozigNetwork, id_c: [*c]const u8) callconv(.c) usize {
    const arena_ptr = c_api.c_arena orelse return std.math.maxInt(usize);
    const alloc = arena_ptr.allocator();
    const net = @as(*systems.network.Network, @ptrCast(@alignCast(net_c.ptr)));
    const id = std.mem.span(id_c);
    const node = systems.network.Node.init(alloc, id) catch return std.math.maxInt(usize);
    return net.addNode(node) catch std.math.maxInt(usize);
}

export fn biozig_systems_network_add_edge(net_c: CBiozigNetwork, source: usize, target: usize, weight: f64, directed: bool) callconv(.c) c_int {
    const net = @as(*systems.network.Network, @ptrCast(@alignCast(net_c.ptr)));
    net.addEdge(source, target, weight, directed) catch return -1;
    return 0;
}

pub const CBiozigMetabolicNetwork = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_metabolism_create() callconv(.c) CBiozigMetabolicNetwork {
    const arena_ptr = c_api.c_arena orelse return CBiozigMetabolicNetwork{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.metabolism.MetabolicNetwork) catch return CBiozigMetabolicNetwork{ .ptr = null };
    net_ptr.* = systems.metabolism.MetabolicNetwork.init(alloc);
    return CBiozigMetabolicNetwork{ .ptr = net_ptr };
}

pub const CBiozigOntology = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_ontology_create() callconv(.c) CBiozigOntology {
    const arena_ptr = c_api.c_arena orelse return CBiozigOntology{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.ontology.Ontology) catch return CBiozigOntology{ .ptr = null };
    net_ptr.* = systems.ontology.Ontology.init(alloc);
    return CBiozigOntology{ .ptr = net_ptr };
}

pub const CBiozigKnowledgeGraph = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_knowledgegraph_create() callconv(.c) CBiozigKnowledgeGraph {
    const arena_ptr = c_api.c_arena orelse return CBiozigKnowledgeGraph{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.knowledgegraph.KnowledgeGraph) catch return CBiozigKnowledgeGraph{ .ptr = null };
    net_ptr.* = systems.knowledgegraph.KnowledgeGraph.init(alloc);
    return CBiozigKnowledgeGraph{ .ptr = net_ptr };
}

pub const CBiozigPathway = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_pathway_create(id_c: [*c]const u8, name_c: [*c]const u8) callconv(.c) CBiozigPathway {
    const arena_ptr = c_api.c_arena orelse return CBiozigPathway{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.pathway.Pathway) catch return CBiozigPathway{ .ptr = null };
    const id = std.mem.span(id_c);
    const name = std.mem.span(name_c);
    net_ptr.* = systems.pathway.Pathway.init(alloc, id, name) catch return CBiozigPathway{ .ptr = null };
    return CBiozigPathway{ .ptr = net_ptr };
}

pub const CBiozigSignalingNetwork = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_signaling_create() callconv(.c) CBiozigSignalingNetwork {
    const arena_ptr = c_api.c_arena orelse return CBiozigSignalingNetwork{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.signaling.SignalingNetwork) catch return CBiozigSignalingNetwork{ .ptr = null };
    net_ptr.* = systems.signaling.SignalingNetwork.init(alloc);
    return CBiozigSignalingNetwork{ .ptr = net_ptr };
}

pub const CBiozigRegulatoryGraph = extern struct { ptr: ?*anyopaque };

export fn biozig_systems_regulation_create() callconv(.c) CBiozigRegulatoryGraph {
    const arena_ptr = c_api.c_arena orelse return CBiozigRegulatoryGraph{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const net_ptr = alloc.create(systems.regulation.RegulatoryGraph) catch return CBiozigRegulatoryGraph{ .ptr = null };
    net_ptr.* = systems.regulation.RegulatoryGraph.init(alloc);
    return CBiozigRegulatoryGraph{ .ptr = net_ptr };
}

// -----------------------------------------------------------------------------
// Algorithms - Systems Add (Dijkstra, BC, etc.)
// -----------------------------------------------------------------------------
pub const CBiozigAlgorithmsGraphBuilder = extern struct { ptr: ?*anyopaque };

export fn biozig_algorithms_systems_graph_builder_create(num_nodes: usize) callconv(.c) CBiozigAlgorithmsGraphBuilder {
    const arena_ptr = c_api.c_arena orelse return CBiozigAlgorithmsGraphBuilder{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const b_ptr = alloc.create(algorithms.systems.GraphBuilder) catch return CBiozigAlgorithmsGraphBuilder{ .ptr = null };
    b_ptr.* = algorithms.systems.GraphBuilder.init(num_nodes);
    return CBiozigAlgorithmsGraphBuilder{ .ptr = b_ptr };
}

export fn biozig_algorithms_systems_graph_builder_add_edge(b_c: CBiozigAlgorithmsGraphBuilder, u: usize, v: usize, w: f64) callconv(.c) c_int {
    const arena_ptr = c_api.c_arena orelse return -1;
    const alloc = arena_ptr.allocator();
    const b = @as(*algorithms.systems.GraphBuilder, @ptrCast(@alignCast(b_c.ptr)));
    b.addEdgeWeighted(alloc, u, v, w) catch return -1;
    return 0;
}

pub const CBiozigAlgorithmsGraph = extern struct { ptr: ?*anyopaque };

export fn biozig_algorithms_systems_graph_build(b_c: CBiozigAlgorithmsGraphBuilder) callconv(.c) CBiozigAlgorithmsGraph {
    const arena_ptr = c_api.c_arena orelse return CBiozigAlgorithmsGraph{ .ptr = null };
    const alloc = arena_ptr.allocator();
    const b = @as(*algorithms.systems.GraphBuilder, @ptrCast(@alignCast(b_c.ptr)));
    const g_ptr = alloc.create(algorithms.systems.Graph) catch return CBiozigAlgorithmsGraph{ .ptr = null };
    g_ptr.* = b.build(alloc) catch return CBiozigAlgorithmsGraph{ .ptr = null };
    return CBiozigAlgorithmsGraph{ .ptr = g_ptr };
}

pub const CDoubleArrayResult = extern struct { ptr: [*c]f64, len: usize };

export fn biozig_algorithms_systems_dijkstra(g_c: CBiozigAlgorithmsGraph, start: usize) callconv(.c) CDoubleArrayResult {
    const arena_ptr = c_api.c_arena orelse return CDoubleArrayResult{ .ptr = null, .len = 0 };
    const alloc = arena_ptr.allocator();
    const g = @as(*algorithms.systems.Graph, @ptrCast(@alignCast(g_c.ptr)));
    const res = algorithms.systems.dijkstra(alloc, g.*, start) catch return CDoubleArrayResult{ .ptr = null, .len = 0 };
    return CDoubleArrayResult{ .ptr = res.ptr, .len = res.len };
}

export fn biozig_algorithms_systems_betweenness(g_c: CBiozigAlgorithmsGraph) callconv(.c) CDoubleArrayResult {
    const arena_ptr = c_api.c_arena orelse return CDoubleArrayResult{ .ptr = null, .len = 0 };
    const alloc = arena_ptr.allocator();
    const g = @as(*algorithms.systems.Graph, @ptrCast(@alignCast(g_c.ptr)));
    const res = algorithms.systems.betweennessCentrality(alloc, g.*) catch return CDoubleArrayResult{ .ptr = null, .len = 0 };
    return CDoubleArrayResult{ .ptr = res.ptr, .len = res.len };
}

// -----------------------------------------------------------------------------
// Ingestion Parsers
// -----------------------------------------------------------------------------
pub const CBiozigParsedSystem = extern struct {
    net: CBiozigNetwork,
    path: CBiozigPathway,
};

export fn biozig_ingestion_systems_gpml_parse(filepath_c: [*c]const u8) callconv(.c) CBiozigParsedSystem {
    const err_res = CBiozigParsedSystem{ .net = .{ .ptr = null }, .path = .{ .ptr = null } };
    const arena_ptr = c_api.c_arena orelse return err_res;
    const alloc = arena_ptr.allocator();

    const filepath = std.mem.span(filepath_c);
    var mmap_reader = core.io.mmap.MMapReader.init(alloc, filepath) catch return err_res;
    defer mmap_reader.deinit();

    var parser = ingestion.systems.gpml.GpmlParser.init(alloc);
    defer parser.deinit();

    const res = parser.parse(mmap_reader.data) catch return err_res;

    const net_ptr = alloc.create(systems.network.Network) catch return err_res;
    net_ptr.* = res.net;

    const path_ptr = alloc.create(systems.pathway.Pathway) catch return err_res;
    path_ptr.* = res.path;

    return CBiozigParsedSystem{ .net = .{ .ptr = net_ptr }, .path = .{ .ptr = path_ptr } };
}

export fn biozig_ingestion_systems_biopax_parse(filepath_c: [*c]const u8) callconv(.c) CBiozigParsedSystem {
    const err_res = CBiozigParsedSystem{ .net = .{ .ptr = null }, .path = .{ .ptr = null } };
    const arena_ptr = c_api.c_arena orelse return err_res;
    const alloc = arena_ptr.allocator();

    const filepath = std.mem.span(filepath_c);
    var mmap_reader = core.io.mmap.MMapReader.init(alloc, filepath) catch return err_res;
    defer mmap_reader.deinit();

    var parser = ingestion.systems.biopax.BiopaxParser.init(alloc);

    const res = parser.parse(mmap_reader.data) catch return err_res;

    const net_ptr = alloc.create(systems.network.Network) catch return err_res;
    net_ptr.* = res.net;

    const path_ptr = alloc.create(systems.pathway.Pathway) catch return err_res;
    path_ptr.* = res.path;

    return CBiozigParsedSystem{ .net = .{ .ptr = net_ptr }, .path = .{ .ptr = path_ptr } };
}

export fn biozig_ingestion_systems_sbml_parse(filepath_c: [*c]const u8) callconv(.c) CBiozigParsedSystem {
    const err_res = CBiozigParsedSystem{ .net = .{ .ptr = null }, .path = .{ .ptr = null } };
    const arena_ptr = c_api.c_arena orelse return err_res;
    const alloc = arena_ptr.allocator();

    const filepath = std.mem.span(filepath_c);
    var mmap_reader = core.io.mmap.MMapReader.init(alloc, filepath) catch return err_res;
    defer mmap_reader.deinit();

    var parser = ingestion.systems.sbml.SbmlParser.init(alloc);

    const res = parser.parse(mmap_reader.data) catch return err_res;

    const net_ptr = alloc.create(systems.network.Network) catch return err_res;
    net_ptr.* = res.net;

    const path_ptr = alloc.create(systems.pathway.Pathway) catch return err_res;
    path_ptr.* = res.path;

    return CBiozigParsedSystem{ .net = .{ .ptr = net_ptr }, .path = .{ .ptr = path_ptr } };
}
