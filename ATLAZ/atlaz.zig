const std = @import("std");
const molecular = @import("molecular");
const sparse = @import("analytics").matrix.sparse;
pub const simplex = @import("simplex.zig");
pub const wasserstein = @import("metrics/wasserstein.zig");
pub const hungarian = @import("metrics/hungarian.zig");

pub const Config = struct {
    max_distance: f64 = 1.0,
    knn_k: usize = 10,
};

pub const Results = struct {
    persistence_pairs: []sparse.PersistencePair,
    tss_scores: []f64,
    recombination_breakpoints: []Breakpoint,
};

pub const PairwiseData = struct {
    total_diff: usize,
    ts_count: usize,
    tv_count: usize,
    gtr_distance: f64,
};

pub const Pair = struct { i: usize, j: usize };

pub const ColumnCache = struct {
    changed_pairs: []Pair,
    base_distances: []f64,
};

pub const Breakpoint = struct {
    start: usize, // Column mapped from birth distance
    end: usize,   // Column mapped from death distance
    persistence: f64,
};

pub const ATLAZ = struct {
    /// Wrapper function to execute the full topological pipeline
    pub fn run(allocator: std.mem.Allocator, msa: []molecular.dna.DNA2View, config: Config) !Results {
        // 1. Compute GTR parameters from MSA (first pass)
        const params = molecular.sequence.estimateGTRParams(msa);
        
        // 2. Build distance matrix (N x N, lower triangular)
        const dist_matrix = try buildDistanceMatrix(allocator, msa, params);
        defer allocator.free(dist_matrix);
        
        // Phase 2: Vietoris-Rips → Boundary Matrix Reduction (On-the-fly)
        const pairs = try simplex.buildAndReduceRips(
            allocator,
            dist_matrix,
            msa.len,
            config.max_distance,
            config.knn_k,
        );
        
        // Phase 3: Biological Mapping
        // Precompute the global pairwise state for the entire alignment
        const pairwise_data = try buildPairwiseData(allocator, msa, params);
        defer {
            for (pairwise_data) |row| allocator.free(row);
            allocator.free(pairwise_data);
        }
        
        // Cache the specific sequence pairs affected by each column
        const column_cache = try buildColumnCache(allocator, msa, pairwise_data);
        defer {
            for (column_cache) |cache| {
                allocator.free(cache.changed_pairs);
                allocator.free(cache.base_distances);
            }
            allocator.free(column_cache);
        }
        
        // Compute H0 perturbation scores
        const tss_scores = try computeTopologicalSelectionScores(
            allocator, 
            msa, 
            pairs, 
            pairwise_data, 
            column_cache, 
            config
        );
        
        // Detect H1 recombination intervals
        const recombination_breakpoints = try detectRecombinationBreakpoints(allocator, pairs);
        
        return Results{
            .persistence_pairs = pairs, // Caller owns this memory
            .tss_scores = tss_scores,
            .recombination_breakpoints = recombination_breakpoints,
        };
    }

    pub fn buildDistanceMatrix(allocator: std.mem.Allocator, msa: []molecular.dna.DNA2View, params: molecular.sequence.GTRParams) ![]f64 {
        const n = msa.len;
        const size = (n * (n - 1)) / 2;
        var dist_matrix = try allocator.alloc(f64, size);
        var idx: usize = 0;
        for (1..n) |i| {
            for (0..i) |j| {
                dist_matrix[idx] = molecular.sequence.gtrDistance(msa[i], msa[j], params);
                idx += 1;
            }
        }
        return dist_matrix;
    }

    fn buildPairwiseData(allocator: std.mem.Allocator, msa: []molecular.dna.DNA2View, params: molecular.sequence.GTRParams) ![][]PairwiseData {
        const n = msa.len;
        var data = try allocator.alloc([]PairwiseData, n);
        for (0..n) |i| {
            data[i] = try allocator.alloc(PairwiseData, i);
            for (0..i) |j| {
                // In full implementation, this parses the exact TS/TV breakdown.
                // For v0.2 scaffolding, we compute the standard GTR.
                const dist = molecular.sequence.gtrDistance(msa[i], msa[j], params);
                data[i][j] = .{
                    .total_diff = 0, // Would be populated from raw iteration
                    .ts_count = 0,
                    .tv_count = 0,
                    .gtr_distance = dist,
                };
            }
        }
        return data;
    }

    fn buildColumnCache(allocator: std.mem.Allocator, msa: []molecular.dna.DNA2View, pairwise_data: [][]PairwiseData) ![]ColumnCache {
        const L = msa[0].len;
        var cache = try allocator.alloc(ColumnCache, L);
        
        for (0..L) |col| {
            var changed_pairs = std.ArrayList(Pair).empty;
            
            for (0..msa.len) |i| {
                for (0..i) |j| {
                    if (molecular.sequence.get(msa[i], col) != molecular.sequence.get(msa[j], col)) {
                        try changed_pairs.append(allocator, .{ .i = i, .j = j });
                    }
                }
            }
            
            cache[col].changed_pairs = try changed_pairs.toOwnedSlice(allocator);
            cache[col].base_distances = try allocator.alloc(f64, cache[col].changed_pairs.len);
            
            for (cache[col].changed_pairs, 0..) |pair, idx| {
                cache[col].base_distances[idx] = pairwise_data[pair.i][pair.j].gtr_distance;
            }
        }
        return cache;
    }

    fn filterPairs(allocator: std.mem.Allocator, pairs: []sparse.PersistencePair, dim: usize) ![]sparse.PersistencePair {
        var filtered = std.ArrayList(sparse.PersistencePair).empty;
        for (pairs) |p| {
            if (p.dimension == dim) {
                try filtered.append(allocator, p);
            }
        }
        return try filtered.toOwnedSlice(allocator);
    }

    const ThreadContext = struct {
        allocator: std.mem.Allocator,
        msa: []molecular.dna.DNA2View,
        original_h0: []sparse.PersistencePair,
        original_h1: []sparse.PersistencePair,
        pairwise_data: [][]PairwiseData,
        column_cache: []ColumnCache,
        config: Config,
        tss_scores: []f64,
        start_col: usize,
        end_col: usize,
    };

    fn computeChunk(ctx: ThreadContext) void {
        const L = ctx.msa[0].len;
        const n = ctx.msa.len;
        const size = (n * (n - 1)) / 2;
        
        var temp_dist = ctx.allocator.alloc(f64, size) catch return;
        defer ctx.allocator.free(temp_dist);

        for (ctx.start_col..ctx.end_col) |col| {
            var idx: usize = 0;
            for (1..n) |i| {
                for (0..i) |j| {
                    temp_dist[idx] = ctx.pairwise_data[i][j].gtr_distance;
                    idx += 1;
                }
            }
            
            const affected = ctx.column_cache[col];
            const diff = 1.0 / @as(f64, @floatFromInt(L));
            for (affected.changed_pairs) |pair| {
                const min = @min(pair.i, pair.j);
                const max = @max(pair.i, pair.j);
                const offset = (max * (max - 1)) / 2 + min;
                temp_dist[offset] = if (temp_dist[offset] > diff) temp_dist[offset] - diff else 0.0;
            }
            
            std.debug.print("Col {d}/{d} [Thread {d}-{d}]\n", .{col, L, ctx.start_col, ctx.end_col});
            const modified_pairs = simplex.buildAndReduceRips(ctx.allocator, temp_dist, ctx.msa.len, ctx.config.max_distance, ctx.config.knn_k) catch continue;
            defer ctx.allocator.free(modified_pairs);
            
            const modified_h0 = filterPairs(ctx.allocator, modified_pairs, 0) catch continue;
            defer ctx.allocator.free(modified_h0);
            
            const modified_h1 = filterPairs(ctx.allocator, modified_pairs, 1) catch continue;
            defer ctx.allocator.free(modified_h1);
            
            const distance_h0 = wasserstein.wassersteinDistance(ctx.allocator, ctx.original_h0, modified_h0) catch 0.0;
            const distance_h1 = wasserstein.wassersteinDistance(ctx.allocator, ctx.original_h1, modified_h1) catch 0.0;
            
            ctx.tss_scores[col] = 0.7 * distance_h0 + 0.3 * distance_h1;
        }
    }

    fn computeTopologicalSelectionScores(
        allocator: std.mem.Allocator, 
        msa: []molecular.dna.DNA2View, 
        original_pairs: []sparse.PersistencePair,
        pairwise_data: [][]PairwiseData,
        column_cache: []ColumnCache,
        config: Config,
    ) ![]f64 {
        const L = msa[0].len;
        const tss_scores = try allocator.alloc(f64, L);
        
        const original_h0 = try filterPairs(allocator, original_pairs, 0);
        defer allocator.free(original_h0);
        
        const original_h1 = try filterPairs(allocator, original_pairs, 1);
        defer allocator.free(original_h1);
        
        const num_threads = 8;
        var threads: [num_threads]std.Thread = undefined;
        
        const chunk_size = (L + num_threads - 1) / num_threads;
        
        for (0..num_threads) |t| {
            const start = t * chunk_size;
            const end = @min(start + chunk_size, L);
            
            if (start >= L) {
                // Dummy thread to satisfy array
                threads[t] = try std.Thread.spawn(.{}, computeChunk, .{ThreadContext{
                    .allocator = allocator,
                    .msa = msa,
                    .original_h0 = original_h0,
                    .original_h1 = original_h1,
                    .pairwise_data = pairwise_data,
                    .column_cache = column_cache,
                    .config = config,
                    .tss_scores = tss_scores,
                    .start_col = L,
                    .end_col = L,
                }});
                continue;
            }
            
            threads[t] = try std.Thread.spawn(.{}, computeChunk, .{ThreadContext{
                .allocator = allocator,
                .msa = msa,
                .original_h0 = original_h0,
                .original_h1 = original_h1,
                .pairwise_data = pairwise_data,
                .column_cache = column_cache,
                .config = config,
                .tss_scores = tss_scores,
                .start_col = start,
                .end_col = end,
            }});
        }
        
        for (0..num_threads) |t| {
            threads[t].join();
        }
        
        return tss_scores;
    }

    fn detectRecombinationBreakpoints(allocator: std.mem.Allocator, pairs: []sparse.PersistencePair) ![]Breakpoint {
        var breakpoints = std.ArrayList(Breakpoint).empty;
        
        for (pairs) |pair| {
            if (pair.dimension == 1) {
                // Death distance - Birth distance
                // Here, birth/death are simplex indices; we would map them to filtration values
                const persistence = @as(f64, @floatFromInt(pair.death - pair.birth)); 
                if (persistence > 0.1) {
                    try breakpoints.append(allocator, .{
                        .start = 0, // Placeholder mapping
                        .end = 0,
                        .persistence = persistence,
                    });
                }
            }
        }
        
        return try breakpoints.toOwnedSlice(allocator);
    }
};
