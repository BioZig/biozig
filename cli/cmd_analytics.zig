const std = @import("std");
const ParsedArgs = @import("args.zig").ParsedArgs;
const analytics = @import("analytics");
const MMapReader = @import("core").io.mmap.MMapReader;
const output = @import("output.zig");

const MatrixData = struct {
    floats: []f64,
    rows: usize,
    cols: usize,
};

fn readMatrix(allocator: std.mem.Allocator, path: []const u8) !MatrixData {
    var reader = try MMapReader.init(allocator, path);
    defer reader.deinit();

    var floats = std.ArrayList(f64).empty;
    var lines = std.mem.splitScalar(u8, reader.data, '\n');
    var cols: usize = 0;
    var rows: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var it = std.mem.splitAny(u8, line, ",\t ");
        var line_cols: usize = 0;
        while (it.next()) |val| {
            if (val.len == 0) continue;
            const f = std.fmt.parseFloat(f64, val) catch continue;
            try floats.append(allocator, f);
            line_cols += 1;
        }
        if (cols == 0) cols = line_cols else if (cols != line_cols) return error.InvalidMatrix;
        rows += 1;
    }

    if (rows == 0 or cols == 0) return error.EmptyMatrix;
    return MatrixData{ .floats = floats.toOwnedSlice(allocator) catch unreachable, .rows = rows, .cols = cols };
}

fn readSequence(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var reader = try MMapReader.init(allocator, path);
    defer reader.deinit();

    var seq = std.ArrayList(u8).empty;
    var lines = std.mem.splitScalar(u8, reader.data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '>') continue; // skip fasta headers
        for (line) |c| {
            if (std.ascii.isWhitespace(c)) continue;
            try seq.append(allocator, c);
        }
    }
    return seq.toOwnedSlice(allocator);
}

pub fn execute(args: ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig analytics - Statistical models, matrix decompositions, pathways, and sequence metrics
            \\
            \\Usage:
            \\  biozig analytics <command> [options]
            \\
            \\Commands:
            \\  pca              Principal Component Analysis
            \\  umap             Uniform Manifold Approximation and Projection
            \\  tsne             t-Distributed Stochastic Neighbor Embedding
            \\  kmeans           K-Means Clustering
            \\  dbscan           Density-Based Spatial Clustering of Applications with Noise
            \\  hierarchical     Hierarchical Clustering
            \\  svd              Singular Value Decomposition
            \\  nmf              Non-negative Matrix Factorization
            \\  markov           Markov sequence models
            \\  kmer_stats       K-mer statistics and spectra
            \\  descriptive      Descriptive statistics
            \\  correlation      Pearson/Spearman correlation
            \\  regression       Linear regression
            \\  hypothesis       Hypothesis testing (t-test)
            \\  node2vec         Node2Vec graph embedding
            \\  spectral         Spectral clustering (GraphML)
            \\  spia             Signaling Pathway Impact Analysis
            \\
            \\Options:
            \\  -h, --help       Show this help message and exit
            \\  -i, --input      Input file path
            \\  -t, --threads    Number of CPU threads
            \\  -k,              Number of clusters/components
            \\  --eps            Epsilon radius (DBSCAN)
            \\  --min-pts        Minimum points (DBSCAN)
            \\
        , .{});
        return;
    }

    if (args.run) |cmd| {
        const in_path = args.input orelse {
            std.debug.print("Error: Command requires an --input file (-i).\n", .{});
            return error.MissingInput;
        };
        const threads = args.threads orelse 1;
        _ = output;

        if (std.mem.eql(u8, cmd, "markov") or std.mem.eql(u8, cmd, "kmer_stats")) {
            const seq = try readSequence(std.heap.page_allocator, in_path);
            defer std.heap.page_allocator.free(seq);

            if (std.mem.eql(u8, cmd, "markov")) {
                const res = try analytics.sequence.markov.computeTransitions(std.heap.page_allocator, seq, threads);
                defer std.heap.page_allocator.destroy(res);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "kmer_stats")) {
                const k = args.k orelse 3;
                var res = try analytics.sequence.kmer_stats.computeKmerFrequencies(std.heap.page_allocator, seq, k, threads);
                defer res.deinit();
                std.debug.print("{any}\n", .{res});
            }
            return;
        }

        if (std.mem.eql(u8, cmd, "pca") or std.mem.eql(u8, cmd, "umap") or std.mem.eql(u8, cmd, "tsne") or std.mem.eql(u8, cmd, "kmeans") or std.mem.eql(u8, cmd, "dbscan") or std.mem.eql(u8, cmd, "hierarchical") or std.mem.eql(u8, cmd, "svd") or std.mem.eql(u8, cmd, "nmf") or std.mem.eql(u8, cmd, "descriptive") or std.mem.eql(u8, cmd, "correlation") or std.mem.eql(u8, cmd, "regression") or std.mem.eql(u8, cmd, "hypothesis") or std.mem.eql(u8, cmd, "node2vec") or std.mem.eql(u8, cmd, "spectral") or std.mem.eql(u8, cmd, "spia")) {
            const mat = try readMatrix(std.heap.page_allocator, in_path);
            defer std.heap.page_allocator.free(mat.floats);

            if (std.mem.eql(u8, cmd, "pca")) {
                const n_comps: usize = @min(2, mat.cols);
                const res = try analytics.dimensionality.pca.pca(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, n_comps, threads);
                defer std.heap.page_allocator.free(res);

                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "umap")) {
                const res = try analytics.dimensionality.umap.umap(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, threads);
                defer std.heap.page_allocator.free(res);

                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "tsne")) {
                const res = try analytics.dimensionality.tsne.tsne(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, threads);
                defer std.heap.page_allocator.free(res);

                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "kmeans")) {
                const k = args.k orelse 3;
                const max_iter: usize = 100;
                const res = try analytics.clustering.kmeans.kmeans(std.heap.page_allocator, mat.floats, mat.cols, k, max_iter, threads);
                defer res.deinit(std.heap.page_allocator);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "dbscan")) {
                const eps = args.eps orelse 0.5;
                const min_pts = args.min_pts orelse 5;
                const res = try analytics.clustering.dbscan.dbscan(std.heap.page_allocator, mat.floats, mat.cols, eps, min_pts, threads);
                defer res.deinit(std.heap.page_allocator);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "hierarchical")) {
                const k = args.k orelse 3;
                const res = try analytics.clustering.hierarchical.agglomerative(std.heap.page_allocator, mat.floats, mat.cols, k, threads);
                defer res.deinit(std.heap.page_allocator);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "svd")) {
                const res = try analytics.matrix.svd.computeSvd(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, threads);
                defer {
                    std.heap.page_allocator.free(res.u);
                    std.heap.page_allocator.free(res.s);
                    std.heap.page_allocator.free(res.vt);
                }
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "nmf")) {
                const Matrix = analytics.matrix.factorization.Matrix;
                const V = Matrix{ .data = mat.floats, .rows = mat.rows, .cols = mat.cols };
                const k = args.k orelse @min(mat.rows, mat.cols);
                var res = try analytics.matrix.factorization.nmf(std.heap.page_allocator, V, k, 100);
                defer {
                    res.W.deinit(std.heap.page_allocator);
                    res.H.deinit(std.heap.page_allocator);
                }
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "descriptive")) {
                const mean = analytics.statistics.descriptive.weightedMean(mat.floats, mat.floats);
                std.debug.print("{any}\n", .{mean});
            } else if (std.mem.eql(u8, cmd, "correlation")) {
                const half = mat.floats.len / 2;
                const x = mat.floats[0..half];
                const y = mat.floats[half .. half * 2];
                const res = try analytics.statistics.correlation.pearson(std.heap.page_allocator, x, y);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "regression")) {
                const half = mat.floats.len / 2;
                const x = mat.floats[0..half];
                const y = mat.floats[half .. half * 2];
                const res = try analytics.statistics.regression.simpleLinearRegression(x, y, std.heap.page_allocator);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "hypothesis")) {
                const half = mat.floats.len / 2;
                const x = mat.floats[0..half];
                const y = mat.floats[half .. half * 2];
                const res = analytics.statistics.hypothesis.studentTTestTwoSample(x, y);
                std.debug.print("{any}\n", .{res});
            } else if (std.mem.eql(u8, cmd, "node2vec")) {
                var graph = try analytics.graphml.node2vec.Graph.init(std.heap.page_allocator, @intCast(mat.rows));
                defer graph.deinit();
                var i: usize = 0;
                while (i < mat.rows) : (i += 1) {
                    if (mat.cols >= 2) {
                        try graph.addEdge(@intFromFloat(mat.floats[i * mat.cols]), @intFromFloat(mat.floats[i * mat.cols + 1]));
                    }
                }
                const walks = try analytics.graphml.node2vec.Node2Vec.simulateWalks(std.heap.page_allocator, &graph, 10, 5, threads);
                defer std.heap.page_allocator.free(walks);
                std.debug.print("{any}\n", .{walks});
            } else if (std.mem.eql(u8, cmd, "spectral")) {
                var graph = try analytics.graphml.spectral.Graph.init(std.heap.page_allocator, @intCast(mat.rows));
                defer graph.deinit();
                var i: usize = 0;
                while (i < mat.rows) : (i += 1) {
                    if (mat.cols >= 2) {
                        try graph.addEdge(@intFromFloat(mat.floats[i * mat.cols]), @intFromFloat(mat.floats[i * mat.cols + 1]));
                    }
                }
                const lap = try analytics.graphml.spectral.Spectral.computeLaplacian(std.heap.page_allocator, &graph);
                defer std.heap.page_allocator.free(lap);
                std.debug.print("{any}\n", .{lap});
            } else if (std.mem.eql(u8, cmd, "spia")) {
                const res = try analytics.pathways.spia.performSpia(std.heap.page_allocator, mat.floats, mat.floats, threads);
                std.debug.print("{any}\n", .{res});
            } else {
                std.debug.print("Routing to {s} (Pending full pipeline integration)...\n", .{cmd});
            }
        } else {
            std.debug.print("Error: Unknown command '{s}'.\n", .{cmd});
        }
    } else {
        std.debug.print("Error: No command provided for analytics.\n", .{});
        std.process.exit(1);
    }
}
