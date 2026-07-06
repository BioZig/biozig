const std = @import("std");
const args_mod = @import("args.zig");
const output = @import("output.zig");
const MMapReader = @import("core").io.mmap.MMapReader;
const cellular = @import("cellular");
const algorithms = @import("algorithms");

const SparseMatrix = cellular.expression.SparseMatrix;

fn parseMtx(allocator: std.mem.Allocator, data: []const u8) !SparseMatrix {
    var lines = std.mem.splitScalar(u8, data, '\n');
    var rows: usize = 0;
    var cols: usize = 0;
    var nnz: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '%') continue;
        var it = std.mem.splitAny(u8, line, " \t");
        rows = try std.fmt.parseInt(usize, it.next() orelse return error.InvalidMtx, 10);
        cols = try std.fmt.parseInt(usize, it.next() orelse return error.InvalidMtx, 10);
        nnz = try std.fmt.parseInt(usize, it.next() orelse return error.InvalidMtx, 10);
        break;
    }

    var mat = try SparseMatrix.init(allocator, .csr, rows, cols, nnz);

    const Triplet = struct { r: u32, c: u32, v: f64 };
    var triplets = try allocator.alloc(Triplet, nnz);
    defer allocator.free(triplets);

    var i: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '%') continue;
        var it = std.mem.splitAny(u8, line, " \t");
        const r_str = it.next() orelse continue;
        const c_str = it.next() orelse continue;
        const v_str = it.next() orelse continue;

        triplets[i] = .{
            .r = (try std.fmt.parseInt(u32, r_str, 10)) - 1,
            .c = (try std.fmt.parseInt(u32, c_str, 10)) - 1,
            .v = try std.fmt.parseFloat(f64, v_str),
        };
        i += 1;
        if (i == nnz) break;
    }

    const SortFn = struct {
        fn lessThan(_: void, a: Triplet, b: Triplet) bool {
            if (a.r != b.r) return a.r < b.r;
            return a.c < b.c;
        }
    };
    std.mem.sort(Triplet, triplets, {}, SortFn.lessThan);

    var current_row: u32 = 0;
    mat.indptr[0] = 0;
    for (triplets, 0..) |t, idx| {
        while (current_row < t.r) {
            current_row += 1;
            mat.indptr[current_row] = @intCast(idx);
        }
        mat.indices[idx] = t.c;
        mat.data[idx] = t.v;
    }
    while (current_row < rows) {
        current_row += 1;
        mat.indptr[current_row] = @intCast(nnz);
    }

    return mat;
}

pub fn execute(args: args_mod.ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig cellular <command> [options]
            \\
            \\Commands:
            \\  umap                      Uniform Manifold Approximation and Projection
            \\  tsne                      t-Distributed Stochastic Neighbor Embedding
            \\  kmeans                    K-Means Clustering
            \\  zinb                      Zero-Inflated Negative Binomial modeling
            \\  pseudotime                Trajectory Inference
            \\  pca                       Principal Component Analysis
            \\  incremental_pca           Incremental PCA
            \\  knn                       K-Nearest Neighbors Graph
            \\  diff_exp                  Differential Expression
            \\  mean_expression           Mean Expression
            \\  variance_expression       Variance Expression
            \\  spatial_distance          Spatial Distance
            \\  spatial_neighborhood      Spatial Neighborhood Search
            \\  neighborhood_expression   Neighborhood Expression Stats
            \\  score_cell_cycle          Cell Cycle Scoring
            \\  sparse_col_sums           Sparse Matrix Column Sums
            \\  sparse_row_sums           Sparse Matrix Row Sums
            \\  sparse_multiply           Sparse Matrix Vector Multiplication
            \\  assign_phase              Assign Cell Cycle Phase
            \\  get_interactions          Get Cell Communication Interactions
            \\  get_ancestry              Get Lineage Ancestry
            \\  find_neighbors            Spatial Index Find Neighbors
            \\
            \\Options:
            \\  -i, --input  Input sparse matrix (.mtx)
            \\
        , .{});
        return;
    }

    const cmd = args.run orelse {
        std.debug.print("Error: Cellular domain requires a command (e.g., umap, tsne, kmeans).\n", .{});
        return;
    };

    const supported_commands = [_][]const u8{ "umap", "tsne", "kmeans", "zinb", "pseudotime", "pca", "incremental_pca", "knn", "diff_exp", "mean_expression", "variance_expression", "spatial_distance", "spatial_neighborhood", "neighborhood_expression", "score_cell_cycle", "sparse_col_sums", "sparse_row_sums", "sparse_multiply", "assign_phase", "get_interactions", "get_ancestry", "find_neighbors" };

    var is_supported = false;
    for (supported_commands) |supported| {
        if (std.mem.eql(u8, cmd, supported)) {
            is_supported = true;
            break;
        }
    }

    if (is_supported) {
        var out_writer = output.OutputWriter.init(.text);
        if (args.input) |in_path| {
            var reader = MMapReader.init(std.heap.page_allocator, in_path) catch |err| {
                std.debug.print("Error opening input file '{s}': {}\n", .{ in_path, err });
                return err;
            };
            defer reader.deinit();

            var mat = try parseMtx(std.heap.page_allocator, reader.data);
            defer mat.deinit();

            if (std.mem.eql(u8, cmd, "umap")) {
                const res = try algorithms.cellular.UMAP.transform(std.heap.page_allocator, mat, 2);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("UMAP: {} elements\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "tsne")) {
                const res = try algorithms.cellular.TSNE.transform(std.heap.page_allocator, mat, 2);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("TSNE: {} elements\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "kmeans")) {
                const res = try algorithms.cellular.KMeans.fit(std.heap.page_allocator, mat, 3, 100);
                defer std.heap.page_allocator.free(res.labels);
                defer std.heap.page_allocator.free(res.centroids);
                try out_writer.writeText("KMeans: {} labels\n", .{res.labels.len});
            } else if (std.mem.eql(u8, cmd, "zinb")) {
                const res = try algorithms.cellular.ZINB.fit(std.heap.page_allocator, mat);
                defer std.heap.page_allocator.free(res.mu);
                defer std.heap.page_allocator.free(res.theta);
                defer std.heap.page_allocator.free(res.pi);
                try out_writer.writeText("ZINB fitted on {} features\n", .{res.mu.len});
            } else if (std.mem.eql(u8, cmd, "pseudotime")) {
                const res = try algorithms.cellular.TrajectoryInference.computePseudotime(std.heap.page_allocator, mat, 0);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Pseudotime computed for {} cells\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "pca")) {
                const res = try algorithms.cellular.PCA.topComponent(std.heap.page_allocator, mat, 10);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("PCA top component length: {}\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "incremental_pca")) {
                const res = try algorithms.cellular.IncrementalPCA.onlineTopComponent(std.heap.page_allocator, mat, 0.01);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Incremental PCA computed length: {}\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "knn")) {
                const res = try algorithms.cellular.KNN.buildGraph(std.heap.page_allocator, mat, 5);
                defer std.heap.page_allocator.free(res.indices);
                defer std.heap.page_allocator.free(res.distances);
                try out_writer.writeText("KNN built with {} indices\n", .{res.indices.len});
            } else if (std.mem.eql(u8, cmd, "diff_exp")) {
                const group1 = [_]usize{0};
                const group2 = [_]usize{1};
                const res = try algorithms.cellular.DifferentialExpression.simpleDiffExp(std.heap.page_allocator, mat, &group1, &group2);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Diff Exp computed for {} genes\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "sparse_col_sums")) {
                const res = try algorithms.cellular.SparseMatrixOps.colSums(std.heap.page_allocator, mat);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Sparse col sums: {} cols\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "sparse_row_sums")) {
                const res = try algorithms.cellular.SparseMatrixOps.rowSums(std.heap.page_allocator, mat);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Sparse row sums: {} rows\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "sparse_multiply")) {
                const x = try std.heap.page_allocator.alloc(f64, mat.cols);
                defer std.heap.page_allocator.free(x);
                @memset(x, 1.0);
                const res = try algorithms.cellular.SparseMatrixOps.multiplyVector(std.heap.page_allocator, mat, x);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Sparse multiply: {} rows\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "mean_expression")) {
                const res = algorithms.cellular.meanExpression(mat.data);
                try out_writer.writeText("Mean Expression: {d:.4}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "variance_expression")) {
                const res = algorithms.cellular.varianceExpression(mat.data);
                try out_writer.writeText("Variance Expression: {d:.4}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "spatial_distance")) {
                const res = algorithms.cellular.spatialDistance(0.0, 0.0, 1.0, 1.0);
                try out_writer.writeText("Spatial distance: {d:.4}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "spatial_neighborhood")) {
                var px = [_]f64{ 0.0, 1.0 };
                var py = [_]f64{ 0.0, 1.0 };
                const points = algorithms.cellular.CoordinateSet2D{ .x = &px, .y = &py };
                const res = try algorithms.cellular.spatialNeighborhood(std.heap.page_allocator, 0.0, 0.0, points, 2.0);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Spatial Neighborhood: {} neighbors\n", .{res.len});
            } else if (std.mem.eql(u8, cmd, "neighborhood_expression")) {
                var n = [_]algorithms.cellular.SpatialNeighbor{.{ .index = 0, .distance = 0.0 }};
                var expr = [_]f64{1.5};
                const res = algorithms.cellular.neighborhoodExpressionStats(&n, &expr);
                try out_writer.writeText("Neighborhood expr: {d:.4}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "score_cell_cycle")) {
                var expr = [_]f64{ 1.0, 2.0 };
                var m1 = [_]bool{ true, false };
                var m2 = [_]bool{ false, true };
                const res = try algorithms.cellular.scoreCellCycle(&expr, &m1, &m2);
                try out_writer.writeText("G1/S: {d:.4}, G2/M: {d:.4}\n", .{ res.g1_s, res.g2_m });
            } else if (std.mem.eql(u8, cmd, "assign_phase")) {
                const res = cellular.cellcycle.Utils.assignPhase(1.0, 0.5, 0.2);
                try out_writer.writeText("Phase: {s}\n", .{res.toString()});
            } else if (std.mem.eql(u8, cmd, "get_interactions")) {
                var graph = cellular.communication.InteractionGraph.init(std.heap.page_allocator);
                defer graph.deinit();
                try out_writer.writeText("Interactions graph ready.\n", .{});
            } else if (std.mem.eql(u8, cmd, "get_ancestry")) {
                var tree = cellular.lineage.LineageTree.init(std.heap.page_allocator);
                defer tree.deinit();
                try out_writer.writeText("Lineage tree ready.\n", .{});
            } else if (std.mem.eql(u8, cmd, "find_neighbors")) {
                var cells = [_]cellular.spatial.SpatialCell{.{ .x = 0, .y = 0, .z = 0 }};
                var idx = cellular.spatial.SpatialIndex.init(std.heap.page_allocator, &cells, 1.0);
                const res = try idx.findNeighbors(0, 1.0, std.heap.page_allocator);
                defer std.heap.page_allocator.free(res);
                try out_writer.writeText("Found {} neighbors in spatial index\n", .{res.len});
            } else {
                std.debug.print("Routing to {s} (Pending full pipeline integration)...\n", .{cmd});
            }
        } else {
            std.debug.print("Error: Input file -i is required for robust execution.\n", .{});
        }
    } else {
        std.debug.print("Error: Unknown cellular command '{s}'\n", .{cmd});
    }
}
