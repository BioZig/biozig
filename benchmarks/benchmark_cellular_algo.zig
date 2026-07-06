const std = @import("std");
const cellular = @import("cellular");
const expression = cellular.expression;
const spatial = cellular.spatial;
const algorithms = @import("algorithms");
const cellular_algo = algorithms.cellular;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    
    std.debug.print("=== Cellular Algorithms Benchmark ===\n", .{});

    // 1. Benchmark 1M+ cells sparse matrix
    const num_cells: usize = 1_000_000;
    const num_genes: usize = 1_000;
    const nnz: usize = num_cells * 10; // 10 non-zeros per cell

    std.debug.print("Benchmarking Sparse CSR Matrix creation for {} cells, {} genes, {} nnz...\n", .{num_cells, num_genes, nnz});

    var sparse = try expression.SparseMatrix.init(allocator, .csr, num_cells, num_genes, nnz);
    
    // Fill with dummy data
    for (0..num_cells) |i| {
        sparse.indptr[i] = @as(u32, @intCast(i * 10));
    }
    sparse.indptr[num_cells] = @as(u32, @intCast(nnz));
    
    for (0..nnz) |i| {
        sparse.indices[i] = @as(u32, @intCast(i % num_genes));
        sparse.data[i] = 1.0;
    }

    std.debug.print("SparseMatrix initialization and filling done.\n", .{});
    
    // 1.1 Sparse Matrix Ops
    const col_sums = try cellular_algo.SparseMatrixOps.colSums(allocator, sparse);
    std.debug.print("SparseMatrixOps colSums done.\n", .{});
    allocator.free(col_sums);
    
    const row_sums = try cellular_algo.SparseMatrixOps.rowSums(allocator, sparse);
    std.debug.print("SparseMatrixOps rowSums done.\n", .{});
    allocator.free(row_sums);
    
    const dummy_vec = try allocator.alloc(f64, num_genes);
    @memset(dummy_vec, 1.0);
    const mul_res = try cellular_algo.SparseMatrixOps.multiplyVector(allocator, sparse, dummy_vec);
    std.debug.print("SparseMatrixOps multiplyVector done.\n", .{});
    allocator.free(mul_res);
    allocator.free(dummy_vec);
    
    // 1.2 PCA
    const pca_res = try cellular_algo.PCA.topComponent(allocator, sparse, 5);
    std.debug.print("PCA topComponent (5 iters) done.\n", .{});
    allocator.free(pca_res);
    
    // 1.3 Incremental PCA
    const ipca_res = try cellular_algo.IncrementalPCA.onlineTopComponent(allocator, sparse, 0.01);
    std.debug.print("IncrementalPCA onlineTopComponent done.\n", .{});
    allocator.free(ipca_res);
    
    // 1.4 Differential Expression
    var group1 = try allocator.alloc(usize, num_cells / 2);
    var group2 = try allocator.alloc(usize, num_cells / 2);
    for (0..num_cells/2) |i| {
        group1[i] = i;
        group2[i] = i + num_cells/2;
    }
    const de_res = try cellular_algo.DifferentialExpression.simpleDiffExp(allocator, sparse, group1, group2);
    std.debug.print("DifferentialExpression simpleDiffExp done.\n", .{});
    allocator.free(de_res);
    allocator.free(group1);
    allocator.free(group2);

    // 1.5 KMeans
    const kmeans_res = try cellular_algo.KMeans.fit(allocator, sparse, 5, 10);
    std.debug.print("KMeans fit done.\n", .{});
    allocator.free(kmeans_res.centroids);
    allocator.free(kmeans_res.labels);

    // 1.6 UMAP
    const umap_res = try cellular_algo.UMAP.transform(allocator, sparse, 2);
    std.debug.print("UMAP transform done.\n", .{});
    allocator.free(umap_res);

    // 1.7 t-SNE
    const tsne_res = try cellular_algo.TSNE.transform(allocator, sparse, 2);
    std.debug.print("t-SNE transform done.\n", .{});
    allocator.free(tsne_res);

    // 1.8 K-NN
    const knn_res = try cellular_algo.KNN.buildGraph(allocator, sparse, 5);
    std.debug.print("K-NN buildGraph done.\n", .{});
    allocator.free(knn_res.indices);
    allocator.free(knn_res.distances);

    // 1.9 ZINB
    const zinb_res = try cellular_algo.ZINB.fit(allocator, sparse);
    std.debug.print("ZINB fit done.\n", .{});
    allocator.free(zinb_res.mu);
    allocator.free(zinb_res.theta);
    allocator.free(zinb_res.pi);

    // 1.10 Trajectory Inference
    const traj_res = try cellular_algo.TrajectoryInference.computePseudotime(allocator, sparse, 0);
    std.debug.print("TrajectoryInference computePseudotime done.\n", .{});
    allocator.free(traj_res);

    sparse.deinit();

    // 2. Spatial Indexing Benchmark
    std.debug.print("Benchmarking Spatial Indexing...\n", .{});
    const num_points: usize = 100_000;
    
    var points = try allocator.alloc(spatial.SpatialCell, num_points);
    defer allocator.free(points);
    
    for (0..num_points) |i| {
        points[i] = .{ 
            .x = @as(f64, @floatFromInt(i % 100)), 
            .y = @as(f64, @floatFromInt((i / 100) % 100)), 
            .z = @as(f64, @floatFromInt((i / 10000) % 100)) 
        };
    }
    
    const index = spatial.SpatialIndex.init(allocator, points, 5.0);
    std.debug.print("SpatialIndex init for {} points done.\n", .{num_points});
    
    const neighbors = try index.findNeighbors(0, 5.0, allocator);
    defer allocator.free(neighbors);
    
    std.debug.print("SpatialIndex findNeighbors query done (Found {} neighbors).\n", .{neighbors.len});
}
