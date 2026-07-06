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
        var out_writer = output.OutputWriter.init(.text);

        if (std.mem.eql(u8, cmd, "markov") or std.mem.eql(u8, cmd, "kmer_stats")) {
            const seq = try readSequence(std.heap.page_allocator, in_path);
            defer std.heap.page_allocator.free(seq);

            if (std.mem.eql(u8, cmd, "markov")) {
                const res = try analytics.sequence.markov.computeTransitions(std.heap.page_allocator, seq, threads);
                defer std.heap.page_allocator.destroy(res);
                for (res, 0..) |row, i| {
                    var sum: u64 = 0;
                    for (row) |v| sum += v;
                    if (sum > 0) {
                        try out_writer.writeText("{c}: ", .{@as(u8, @intCast(i))});
                        for (row, 0..) |v, j| {
                            if (v > 0) try out_writer.writeText("{c}({d}) ", .{ @as(u8, @intCast(j)), v });
                        }
                        try out_writer.writeText("\n", .{});
                    }
                }
            } else if (std.mem.eql(u8, cmd, "kmer_stats")) {
                const k = args.k orelse 3;
                var res = try analytics.sequence.kmer_stats.computeKmerFrequencies(std.heap.page_allocator, seq, k, threads);
                defer res.deinit();
                var it = res.iterator();
                while (it.next()) |entry| {
                    try out_writer.writeText("{s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                }
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

                var j: usize = 0;
                while (j < mat.cols) : (j += 1) {
                    var k_idx: usize = 0;
                    while (k_idx < n_comps) : (k_idx += 1) {
                        try out_writer.writeText("{d:.4} ", .{res[j * n_comps + k_idx]});
                    }
                    try out_writer.writeText("\n", .{});
                }
            } else if (std.mem.eql(u8, cmd, "umap")) {
                const res = try analytics.dimensionality.umap.umap(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, threads);
                defer std.heap.page_allocator.free(res);

                var j: usize = 0;
                while (j < mat.rows) : (j += 1) {
                    try out_writer.writeText("{d:.4} {d:.4}\n", .{ res[j * 2], res[j * 2 + 1] });
                }
            } else if (std.mem.eql(u8, cmd, "tsne")) {
                const res = try analytics.dimensionality.tsne.tsne(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, threads);
                defer std.heap.page_allocator.free(res);

                var j: usize = 0;
                while (j < mat.rows) : (j += 1) {
                    try out_writer.writeText("{d:.4} {d:.4}\n", .{ res[j * 2], res[j * 2 + 1] });
                }
            } else if (std.mem.eql(u8, cmd, "kmeans")) {
                const k = args.k orelse 3;
                const max_iter: usize = 100;
                const res = try analytics.clustering.kmeans.kmeans(std.heap.page_allocator, mat.floats, mat.cols, k, max_iter, threads);
                defer res.deinit(std.heap.page_allocator);
                for (res.labels) |l| try out_writer.writeText("{d}\n", .{l});
            } else if (std.mem.eql(u8, cmd, "dbscan")) {
                const eps = args.eps orelse 0.5;
                const min_pts = args.min_pts orelse 5;
                const res = try analytics.clustering.dbscan.dbscan(std.heap.page_allocator, mat.floats, mat.cols, eps, min_pts, threads);
                defer res.deinit(std.heap.page_allocator);
                for (res.labels) |l| try out_writer.writeText("{d}\n", .{l});
            } else if (std.mem.eql(u8, cmd, "hierarchical")) {
                const k = args.k orelse 3;
                const res = try analytics.clustering.hierarchical.agglomerative(std.heap.page_allocator, mat.floats, mat.cols, k, threads);
                defer res.deinit(std.heap.page_allocator);
                for (res.labels) |l| try out_writer.writeText("{d}\n", .{l});
            } else if (std.mem.eql(u8, cmd, "svd")) {
                const res = try analytics.matrix.svd.computeSvd(std.heap.page_allocator, mat.floats, mat.rows, mat.cols, threads);
                defer {
                    std.heap.page_allocator.free(res.u);
                    std.heap.page_allocator.free(res.s);
                    std.heap.page_allocator.free(res.vt);
                }
                for (res.s) |s_val| try out_writer.writeText("{d:.4}\n", .{s_val});
            } else if (std.mem.eql(u8, cmd, "nmf")) {
                const Matrix = analytics.matrix.factorization.Matrix;
                const V = Matrix{ .data = mat.floats, .rows = mat.rows, .cols = mat.cols };
                const k = args.k orelse @min(mat.rows, mat.cols);
                var res = try analytics.matrix.factorization.nmf(std.heap.page_allocator, V, k, 100);
                defer {
                    res.W.deinit(std.heap.page_allocator);
                    res.H.deinit(std.heap.page_allocator);
                }
                var r: usize = 0;
                while (r < res.W.rows) : (r += 1) {
                    var c: usize = 0;
                    while (c < res.W.cols) : (c += 1) {
                        try out_writer.writeText("{d:.4} ", .{res.W.get(r, c)});
                    }
                    try out_writer.writeText("\n", .{});
                }
            } else if (std.mem.eql(u8, cmd, "descriptive")) {
                const mean = analytics.statistics.descriptive.weightedMean(mat.floats, mat.floats);
                try out_writer.writeText("Weighted Mean: {d:.4}\n", .{mean});
            } else if (std.mem.eql(u8, cmd, "correlation")) {
                const half = mat.floats.len / 2;
                const x = mat.floats[0..half];
                const y = mat.floats[half .. half * 2];
                const res = try analytics.statistics.correlation.pearson(std.heap.page_allocator, x, y);
                try out_writer.writeText("Pearson Correlation: {d:.4}\n", .{res.coefficient});
            } else if (std.mem.eql(u8, cmd, "regression")) {
                const half = mat.floats.len / 2;
                const x = mat.floats[0..half];
                const y = mat.floats[half .. half * 2];
                const res = try analytics.statistics.regression.simpleLinearRegression(x, y, std.heap.page_allocator);
                try out_writer.writeText("Slope: {d:.4}, Intercept: {d:.4}\n", .{ res.slope, res.intercept });
            } else if (std.mem.eql(u8, cmd, "hypothesis")) {
                const half = mat.floats.len / 2;
                const x = mat.floats[0..half];
                const y = mat.floats[half .. half * 2];
                const res = analytics.statistics.hypothesis.studentTTestTwoSample(x, y);
                try out_writer.writeText("T-test stat: {d:.4}, p-value: {d:.4}\n", .{ res.statistic, res.p_value });
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
                try out_writer.writeText("Node2Vec generated {} random walks.\n", .{walks.len});
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
                try out_writer.writeText("Spectral Laplacian computed.\n", .{});
            } else if (std.mem.eql(u8, cmd, "spia")) {
                const res = try analytics.pathways.spia.performSpia(std.heap.page_allocator, mat.floats, mat.floats, threads);
                try out_writer.writeText("SPIA computed. tA={d:.4}, p-value={d:.4}\n", .{ res.tA, res.p_value });
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
