const std = @import("std");
const cellular = @import("cellular");
const ingestion = @import("ingestion");
const algorithms = @import("algorithms");
const c_api = @import("c_api.zig");
const core = @import("core");

// 1. singlecell
export fn biozig_cellular_cell_create(id: [*c]const u8, num_features: usize) callconv(.c) [*c]cellular.singlecell.Cell {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    const cell_ptr = alloc.create(cellular.singlecell.Cell) catch return null;
    cell_ptr.* = cellular.singlecell.Cell.init(alloc, std.mem.span(id), num_features) catch return null;
    return cell_ptr;
}

export fn biozig_cellular_cell_add_metadata(cell: [*c]cellular.singlecell.Cell, key: [*c]const u8, value: [*c]const u8) callconv(.c) c_int {
    if (cell == null) return -1;
    cell.*.addMetadata(std.mem.span(key), std.mem.span(value)) catch return -1;
    return 0;
}

export fn biozig_cellular_cell_collection_create() callconv(.c) [*c]cellular.singlecell.CellCollection {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    const col_ptr = alloc.create(cellular.singlecell.CellCollection) catch return null;
    col_ptr.* = cellular.singlecell.CellCollection.init(alloc);
    return col_ptr;
}

// 2. lineage
export fn biozig_cellular_lineage_node_create(cell_id: [*c]const u8) callconv(.c) [*c]cellular.lineage.LineageNode {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    return cellular.lineage.LineageNode.init(alloc, std.mem.span(cell_id)) catch return null;
}

export fn biozig_cellular_lineage_node_add_child(parent: [*c]cellular.lineage.LineageNode, child: [*c]cellular.lineage.LineageNode) callconv(.c) c_int {
    if (parent == null or child == null) return -1;
    parent.*.addChild(child) catch return -1;
    return 0;
}

export fn biozig_cellular_lineage_tree_create() callconv(.c) [*c]cellular.lineage.LineageTree {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    const tree_ptr = alloc.create(cellular.lineage.LineageTree) catch return null;
    tree_ptr.* = cellular.lineage.LineageTree.init(alloc);
    return tree_ptr;
}

// 3. cellcycle
export fn biozig_cellular_cellcycle_assign_phase(g1: f64, s: f64, g2m: f64) callconv(.c) c_int {
    const phase = cellular.cellcycle.Utils.assignPhase(g1, s, g2m);
    return @intFromEnum(phase);
}

export fn biozig_cellular_cellcycle_state_create(phase_int: c_int) callconv(.c) [*c]cellular.cellcycle.State {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const state_ptr = alloc.create(cellular.cellcycle.State) catch return null;
    state_ptr.* = cellular.cellcycle.State.init(alloc, @as(cellular.cellcycle.Phase, @enumFromInt(phase_int)));
    return state_ptr;
}

// 4. communication
export fn biozig_cellular_interaction_create(sender: usize, receiver: usize, ligand: [*c]const u8, receptor: [*c]const u8, score: f64) callconv(.c) [*c]cellular.communication.Interaction {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(cellular.communication.Interaction) catch return null;
    ptr.* = cellular.communication.Interaction.init(alloc, sender, receiver, std.mem.span(ligand), std.mem.span(receptor), score) catch return null;
    return ptr;
}

export fn biozig_cellular_interaction_graph_create() callconv(.c) [*c]cellular.communication.InteractionGraph {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(cellular.communication.InteractionGraph) catch return null;
    ptr.* = cellular.communication.InteractionGraph.init(alloc);
    return ptr;
}

// 5. expression
export fn biozig_cellular_dense_matrix_create(rows: usize, cols: usize) callconv(.c) [*c]cellular.expression.DenseMatrix {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(cellular.expression.DenseMatrix) catch return null;
    ptr.* = cellular.expression.DenseMatrix.init(alloc, rows, cols) catch return null;
    return ptr;
}

export fn biozig_cellular_sparse_matrix_create(format_int: c_int, rows: usize, cols: usize, nnz: usize) callconv(.c) [*c]cellular.expression.SparseMatrix {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(cellular.expression.SparseMatrix) catch return null;
    ptr.* = cellular.expression.SparseMatrix.init(alloc, @as(cellular.expression.SparseFormat, @enumFromInt(format_int)), rows, cols, nnz) catch return null;
    return ptr;
}

// 6. spatial
export fn biozig_cellular_spatial_index_create(cells_ptr: [*c]cellular.spatial.SpatialCell, num_cells: usize, grid_size: f64) callconv(.c) [*c]cellular.spatial.SpatialIndex {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    const ptr = alloc.create(cellular.spatial.SpatialIndex) catch return null;
    const cells_slice = cells_ptr[0..num_cells];
    ptr.* = cellular.spatial.SpatialIndex.init(alloc, cells_slice, grid_size);
    return ptr;
}

// 7. algorithms/cellular/advanced.zig wrappers
pub const CBiozigKMeansResult = extern struct {
    centroids: [*c]f64,
    labels: [*c]usize,
};

export fn biozig_algo_cellular_kmeans_fit(mat: [*c]cellular.expression.SparseMatrix, k: usize, max_iter: usize) callconv(.c) CBiozigKMeansResult {
    const err_res = CBiozigKMeansResult{ .centroids = null, .labels = null };
    const arena = c_api.c_arena orelse return err_res;
    const alloc = arena.allocator();

    if (mat == null) return err_res;

    const result = algorithms.cellular.KMeans.fit(alloc, mat.*, k, max_iter) catch return err_res;
    return CBiozigKMeansResult{
        .centroids = result.centroids.ptr,
        .labels = result.labels.ptr,
    };
}

export fn biozig_algo_cellular_umap_transform(mat: [*c]cellular.expression.SparseMatrix, n_components: usize) callconv(.c) [*c]f64 {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    if (mat == null) return null;

    const result = algorithms.cellular.UMAP.transform(alloc, mat.*, n_components) catch return null;
    return result.ptr;
}

export fn biozig_algo_cellular_tsne_transform(mat: [*c]cellular.expression.SparseMatrix, n_components: usize) callconv(.c) [*c]f64 {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    if (mat == null) return null;

    const result = algorithms.cellular.TSNE.transform(alloc, mat.*, n_components) catch return null;
    return result.ptr;
}

export fn biozig_algo_cellular_knn_build_graph(mat: [*c]cellular.expression.SparseMatrix, k: usize) callconv(.c) [*c]algorithms.cellular.KNN.Graph {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    if (mat == null) return null;

    const graph_ptr = alloc.create(algorithms.cellular.KNN.Graph) catch return null;
    graph_ptr.* = algorithms.cellular.KNN.buildGraph(alloc, mat.*, k) catch return null;
    return graph_ptr;
}

export fn biozig_algo_cellular_zinb_fit(mat: [*c]cellular.expression.SparseMatrix) callconv(.c) [*c]algorithms.cellular.ZINB.Params {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    if (mat == null) return null;

    const params_ptr = alloc.create(algorithms.cellular.ZINB.Params) catch return null;
    params_ptr.* = algorithms.cellular.ZINB.fit(alloc, mat.*) catch return null;
    return params_ptr;
}

export fn biozig_algo_cellular_trajectory_pseudotime(mat: [*c]cellular.expression.SparseMatrix, root_cell: usize) callconv(.c) [*c]f64 {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    if (mat == null) return null;

    const res = algorithms.cellular.TrajectoryInference.computePseudotime(alloc, mat.*, root_cell) catch return null;
    return res.ptr;
}

// 8. ingestion/transcriptomics/mtx.zig wrapper
export fn biozig_ingestion_mtx_parse_sparse(filepath: [*c]const u8) callconv(.c) [*c]cellular.expression.SparseMatrix {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    const path = std.mem.span(filepath);

    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return null;
    defer reader.deinit();

    const parser = ingestion.transcriptomics.mtx.MtxParser.init(alloc);
    const mat = parser.parseSparseMmap(reader.data) catch return null;

    const ptr = alloc.create(cellular.expression.SparseMatrix) catch return null;
    ptr.* = mat;
    return ptr;
}

export fn biozig_ingestion_mtx_parse_dense(filepath: [*c]const u8) callconv(.c) [*c]cellular.expression.DenseMatrix {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    const path = std.mem.span(filepath);

    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return null;
    defer reader.deinit();

    const parser = ingestion.transcriptomics.mtx.MtxParser.init(alloc);
    const mat = parser.parseDenseMmap(reader.data) catch return null;

    const ptr = alloc.create(cellular.expression.DenseMatrix) catch return null;
    ptr.* = mat;
    return ptr;
}
