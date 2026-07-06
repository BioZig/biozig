const std = @import("std");
const c_api = @import("c_api.zig");
const analytics = @import("analytics");

// Dimensionality Reduction Wrappers
pub const CBiozigDimRedResult = extern struct {
    data: [*c]const f64,
    rows: usize,
    cols: usize,
};

export fn biozig_analytics_pca(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    n_components: usize,
    threads: u16,
) callconv(.c) CBiozigDimRedResult {
    const arena_ptr = c_api.c_arena orelse return .{ .data = null, .rows = 0, .cols = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. rows * cols];
    
    if (analytics.dimensionality.pca.pca(alloc, data_slice, rows, cols, n_components, threads)) |res| {
        return .{
            .data = res.ptr,
            .rows = rows,
            .cols = n_components,
        };
    } else |_| {
        return .{ .data = null, .rows = 0, .cols = 0 };
    }
}

export fn biozig_analytics_tsne(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    threads: u16,
) callconv(.c) CBiozigDimRedResult {
    const arena_ptr = c_api.c_arena orelse return .{ .data = null, .rows = 0, .cols = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. rows * cols];
    
    if (analytics.dimensionality.tsne.tsne(alloc, data_slice, rows, cols, threads)) |res| {
        return .{
            .data = res.ptr,
            .rows = rows,
            .cols = 2,
        };
    } else |_| {
        return .{ .data = null, .rows = 0, .cols = 0 };
    }
}

export fn biozig_analytics_umap(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    threads: u16,
) callconv(.c) CBiozigDimRedResult {
    const arena_ptr = c_api.c_arena orelse return .{ .data = null, .rows = 0, .cols = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. rows * cols];
    
    if (analytics.dimensionality.umap.umap(alloc, data_slice, rows, cols, threads)) |res| {
        return .{
            .data = res.ptr,
            .rows = rows,
            .cols = 2,
        };
    } else |_| {
        return .{ .data = null, .rows = 0, .cols = 0 };
    }
}

// Clustering Wrappers
pub const CBiozigKMeansResult = extern struct {
    centroids: [*c]const f64,
    labels: [*c]const usize,
    k: usize,
    dim: usize,
    num_points: usize,
};

export fn biozig_analytics_kmeans(
    data: [*c]const f64,
    dim: usize,
    num_points: usize,
    k: usize,
    max_iter: usize,
    threads: u16,
) callconv(.c) CBiozigKMeansResult {
    const arena_ptr = c_api.c_arena orelse return .{ .centroids = null, .labels = null, .k = 0, .dim = 0, .num_points = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. num_points * dim];
    
    if (analytics.clustering.kmeans.kmeans(alloc, data_slice, dim, k, max_iter, threads)) |res| {
        return .{
            .centroids = res.centroids.ptr,
            .labels = res.labels.ptr,
            .k = k,
            .dim = dim,
            .num_points = num_points,
        };
    } else |_| {
        return .{ .centroids = null, .labels = null, .k = 0, .dim = 0, .num_points = 0 };
    }
}

pub const CBiozigHierarchicalResult = extern struct {
    labels: [*c]const usize,
    num_points: usize,
};

export fn biozig_analytics_hierarchical(
    data: [*c]const f64,
    dim: usize,
    num_points: usize,
    k: usize,
    threads: u16,
) callconv(.c) CBiozigHierarchicalResult {
    const arena_ptr = c_api.c_arena orelse return .{ .labels = null, .num_points = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. num_points * dim];
    
    if (analytics.clustering.hierarchical.agglomerative(alloc, data_slice, dim, k, threads)) |res| {
        return .{
            .labels = res.labels.ptr,
            .num_points = num_points,
        };
    } else |_| {
        return .{ .labels = null, .num_points = 0 };
    }
}

pub const CBiozigDBSCANResult = extern struct {
    labels: [*c]const isize,
    num_points: usize,
};

export fn biozig_analytics_dbscan(
    data: [*c]const f64,
    dim: usize,
    num_points: usize,
    eps: f64,
    min_pts: usize,
    threads: u16,
) callconv(.c) CBiozigDBSCANResult {
    const arena_ptr = c_api.c_arena orelse return .{ .labels = null, .num_points = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. num_points * dim];
    
    if (analytics.clustering.dbscan.dbscan(alloc, data_slice, dim, eps, min_pts, threads)) |res| {
        return .{
            .labels = res.labels.ptr,
            .num_points = num_points,
        };
    } else |_| {
        return .{ .labels = null, .num_points = 0 };
    }
}

// Matrix Wrappers
pub const CBiozigSvdResult = extern struct {
    u: [*c]const f64,
    s: [*c]const f64,
    vt: [*c]const f64,
    rows: usize,
    cols: usize,
};

export fn biozig_analytics_svd(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    threads: u16,
) callconv(.c) CBiozigSvdResult {
    const arena_ptr = c_api.c_arena orelse return .{ .u = null, .s = null, .vt = null, .rows = 0, .cols = 0 };
    const alloc = arena_ptr.allocator();
    const data_slice = data[0 .. rows * cols];
    
    if (analytics.matrix.svd.computeSvd(alloc, data_slice, rows, cols, threads)) |res| {
        return .{
            .u = res.u.ptr,
            .s = res.s.ptr,
            .vt = res.vt.ptr,
            .rows = rows,
            .cols = cols,
        };
    } else |_| {
        return .{ .u = null, .s = null, .vt = null, .rows = 0, .cols = 0 };
    }
}

pub const CBiozigNmfResult = extern struct {
    w: [*c]const f64,
    h: [*c]const f64,
    rows: usize,
    k: usize,
    cols: usize,
};

export fn biozig_analytics_nmf(
    data: [*c]const f64,
    rows: usize,
    cols: usize,
    k: usize,
    iterations: usize,
) callconv(.c) CBiozigNmfResult {
    const arena_ptr = c_api.c_arena orelse return .{ .w = null, .h = null, .rows = 0, .k = 0, .cols = 0 };
    const alloc = arena_ptr.allocator();
    
    const V = analytics.matrix.factorization.Matrix.init(alloc, rows, cols) catch return .{ .w = null, .h = null, .rows = 0, .k = 0, .cols = 0 };
    @memcpy(V.data, data[0 .. rows * cols]);

    if (analytics.matrix.factorization.nmf(alloc, V, k, iterations)) |res| {
        return .{
            .w = res.W.data.ptr,
            .h = res.H.data.ptr,
            .rows = rows,
            .k = k,
            .cols = cols,
        };
    } else |_| {
        return .{ .w = null, .h = null, .rows = 0, .k = 0, .cols = 0 };
    }
}

export fn biozig_analytics_mds(
    data: [*c]const f64,
    n: usize,
    k: usize,
) callconv(.c) CBiozigDimRedResult {
    const arena_ptr = c_api.c_arena orelse return .{ .data = null, .rows = 0, .cols = 0 };
    const alloc = arena_ptr.allocator();
    
    const D = analytics.matrix.factorization.Matrix.init(alloc, n, n) catch return .{ .data = null, .rows = 0, .cols = 0 };
    @memcpy(D.data, data[0 .. n * n]);

    if (analytics.matrix.factorization.mds(alloc, D, k)) |res| {
        return .{
            .data = res.data.ptr,
            .rows = n,
            .cols = k,
        };
    } else |_| {
        return .{ .data = null, .rows = 0, .cols = 0 };
    }
}

// GraphML Wrappers
pub const CBiozigOpaqueGraph = extern struct {
    ptr: *anyopaque,
};

export fn biozig_analytics_node2vec_init(num_nodes: u32) callconv(.c) CBiozigOpaqueGraph {
    const arena_ptr = c_api.c_arena orelse return .{ .ptr = undefined };
    const alloc = arena_ptr.allocator();
    
    if (alloc.create(analytics.graphml.node2vec.Graph)) |g_ptr| {
        if (analytics.graphml.node2vec.Graph.init(alloc, num_nodes)) |g| {
            g_ptr.* = g;
            return .{ .ptr = g_ptr };
        } else |_| {}
    } else |_| {}
    return .{ .ptr = undefined };
}

// Statistics Wrappers
pub const CBiozigCorrelationResult = extern struct {
    coefficient: f64,
    p_value: f64,
};

export fn biozig_analytics_pearson(x: [*c]const f64, y: [*c]const f64, len: usize) callconv(.c) CBiozigCorrelationResult {
    const res = analytics.statistics.correlation.pearson(null, x[0..len], y[0..len]) catch analytics.statistics.correlation.CorrelationResult{ .coefficient = 0.0, .p_value = 1.0 };
    return .{ .coefficient = res.coefficient, .p_value = res.p_value };
}

export fn biozig_analytics_spearman(x: [*c]const f64, y: [*c]const f64, len: usize) callconv(.c) CBiozigCorrelationResult {
    const arena_ptr = c_api.c_arena orelse return .{ .coefficient = 0, .p_value = 1 };
    if (analytics.statistics.correlation.spearman(x[0..len], y[0..len], arena_ptr.allocator())) |res| {
        return .{ .coefficient = res.coefficient, .p_value = res.p_value };
    } else |_| {
        return .{ .coefficient = 0, .p_value = 1 };
    }
}

export fn biozig_analytics_kendall_tau(x: [*c]const f64, y: [*c]const f64, len: usize) callconv(.c) CBiozigCorrelationResult {
    const res = analytics.statistics.correlation.kendallTau(null, x[0..len], y[0..len]) catch analytics.statistics.correlation.CorrelationResult{ .coefficient = 0.0, .p_value = 1.0 };
    return .{ .coefficient = res.coefficient, .p_value = res.p_value };
}

// Pathways Wrappers
export fn biozig_analytics_hypergeometric_pvalue(k: usize, K: usize, n: usize, N: usize) callconv(.c) f64 {
    return analytics.pathways.enrichment.hypergeometricPValue(k, K, n, N);
}
