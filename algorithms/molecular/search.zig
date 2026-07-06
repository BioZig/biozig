const std = @import("std");
const dna = @import("molecular").dna;
const DNA2View = dna.DNA2View;
const indexing = @import("indexing.zig");

pub const SearchResult = struct {
    pos: usize,
    score: i32,
    matches: usize,
};

pub const SearchLayer = struct {
    fm_index: *indexing.FMIndex,
    minimizers: []const indexing.Minimizer,
    ref_seq: DNA2View,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, fm_index: *indexing.FMIndex, minimizers: []const indexing.Minimizer, ref_seq: DNA2View) SearchLayer {
        return SearchLayer{
            .fm_index = fm_index,
            .minimizers = minimizers,
            .ref_seq = ref_seq,
            .allocator = allocator,
        };
    }

    /// Exact match using FM-Index / BWT
    pub fn exactMatch(self: *const SearchLayer, query: DNA2View) struct { start: usize, end: usize } {
        const res = self.fm_index.count(query);
        return .{ .start = res.start, .end = res.end };
    }

    /// Approximate matching using Seed-and-Extend (simplified heuristic)
    pub fn seedAndExtend(self: *const SearchLayer, query: DNA2View, max_errors: usize) []SearchResult {
        var results = std.ArrayList(SearchResult).empty;
        errdefer results.deinit(self.allocator);

        const seed_len: usize = if (query.len > 4) 4 else query.len;
        if (seed_len == 0) return results.toOwnedSlice(self.allocator) catch unreachable;

        for (0..query.len - seed_len + 1) |i| {
            const seed = query.slice(i, i + seed_len);
            const res = self.fm_index.count(seed);
            if (res.start < res.end) {
                for (res.start..res.end) |sa_idx| {
                    const pos = self.fm_index.sa.sa[sa_idx];
                    var errors: usize = 0;
                    var matches: usize = seed_len;
                    var q_idx: usize = i + seed_len;
                    var r_idx: usize = pos + seed_len;
                    
                    while (q_idx < query.len and r_idx < self.ref_seq.len) {
                        if (query.get(q_idx) != self.ref_seq.get(r_idx)) {
                            errors += 1;
                            if (errors > max_errors) break;
                        } else {
                            matches += 1;
                        }
                        q_idx += 1;
                        r_idx += 1;
                    }
                    
                    if (errors <= max_errors) {
                        results.append(self.allocator, .{
                            .pos = pos,
                            .score = @as(i32, @intCast(matches)) - @as(i32, @intCast(errors)),
                            .matches = matches,
                        }) catch unreachable;
                    }
                }
            }
        }
        return results.toOwnedSlice(self.allocator) catch unreachable;
    }

    /// Banding (Banded alignment heuristic)
    pub fn banding(self: *const SearchLayer, query: DNA2View, band_width: usize) []SearchResult {
        var results = std.ArrayList(SearchResult).empty;
        errdefer results.deinit(self.allocator);

        const seed_len = if (query.len > 4) 4 else query.len;
        if (seed_len == 0) return results.toOwnedSlice(self.allocator) catch unreachable;
        
        const seed = query.slice(0, seed_len);
        const res = self.fm_index.count(seed);

        for (res.start..res.end) |sa_idx| {
            const pos = self.fm_index.sa.sa[sa_idx];
            
            const max_ref_len = if (pos + query.len + band_width < self.ref_seq.len) query.len + band_width else self.ref_seq.len - pos;
            const ref_sub = self.ref_seq.slice(pos, pos + max_ref_len);

            var dp = self.allocator.alloc(i32, (query.len + 1) * (ref_sub.len + 1)) catch unreachable;
            defer self.allocator.free(dp);
            
            const w = band_width;
            for (0..query.len + 1) |i| {
                for (0..ref_sub.len + 1) |j| {
                    const idx = i * (ref_sub.len + 1) + j;
                    dp[idx] = -10000;
                }
            }
            dp[0] = 0;
            
            var best_score: i32 = 0;
            var best_matches: usize = 0;
            
            for (1..query.len + 1) |i| {
                const min_j = if (i > w) i - w else 1;
                const max_j = if (i + w <= ref_sub.len) i + w else ref_sub.len;
                
                for (min_j..max_j + 1) |j| {
                    const match = if (query.get(i - 1) == ref_sub.get(j - 1)) @as(i32, 1) else @as(i32, -1);
                    const idx = i * (ref_sub.len + 1) + j;
                    
                    const score_diag = dp[(i - 1) * (ref_sub.len + 1) + (j - 1)] + match;
                    const score_up = dp[(i - 1) * (ref_sub.len + 1) + j] - 1;
                    const score_left = dp[i * (ref_sub.len + 1) + (j - 1)] - 1;
                    
                    var max_s = score_diag;
                    if (score_up > max_s) max_s = score_up;
                    if (score_left > max_s) max_s = score_left;
                    if (max_s < 0) max_s = 0;
                    
                    dp[idx] = max_s;
                    if (max_s > best_score) {
                        best_score = max_s;
                        best_matches = if (match == 1) best_matches + 1 else best_matches;
                    }
                }
            }
            results.append(self.allocator, .{ .pos = pos, .score = best_score, .matches = best_matches }) catch unreachable;
        }

        return results.toOwnedSlice(self.allocator) catch unreachable;
    }

    /// Chaining (Chaining of minimizers/seeds)
    pub fn chaining(self: *const SearchLayer, query_minimizers: []const indexing.Minimizer) []SearchResult {
        var results = std.ArrayList(SearchResult).empty;
        errdefer results.deinit(self.allocator);

        const Anchor = struct {
            q_pos: usize,
            r_pos: usize,
            hash: u64,
        };
        var anchors = std.ArrayList(Anchor).empty;
        defer anchors.deinit(self.allocator);
        
        for (query_minimizers) |qm| {
            for (self.minimizers) |rm| {
                if (qm.hash == rm.hash) {
                    anchors.append(self.allocator, .{ .q_pos = qm.pos, .r_pos = rm.pos, .hash = qm.hash }) catch unreachable;
                }
            }
        }
        
        const lessThan = struct {
            fn f(ctx: void, a: Anchor, b: Anchor) bool {
                _ = ctx;
                return a.r_pos < b.r_pos;
            }
        }.f;
        std.mem.sort(Anchor, anchors.items, {}, lessThan);
        
        var scores = self.allocator.alloc(i32, anchors.items.len) catch unreachable;
        defer self.allocator.free(scores);
        @memset(scores, 1);
        
        var best_score: i32 = 0;
        var best_r_pos: usize = 0;
        
        for (0..anchors.items.len) |i| {
            for (0..i) |j| {
                if (anchors.items[i].q_pos > anchors.items[j].q_pos and anchors.items[i].r_pos > anchors.items[j].r_pos) {
                    if (scores[i] < scores[j] + 1) {
                        scores[i] = scores[j] + 1;
                    }
                }
            }
            if (scores[i] > best_score) {
                best_score = scores[i];
                best_r_pos = anchors.items[i].r_pos;
            }
        }
        
        if (best_score > 0) {
            results.append(self.allocator, .{ .pos = best_r_pos, .score = best_score, .matches = @intCast(best_score) }) catch unreachable;
        }

        return results.toOwnedSlice(self.allocator) catch unreachable;
    }
};

test "SearchLayer basic execution" {
    const alloc = std.testing.allocator;
    const dna_type = @import("molecular").dna;
    var seq = try dna_type.DNA2.init("ACGTACGTACGT", alloc);
    defer seq.deinit();

    var fm = try indexing.FMIndex.init(alloc, seq.view());
    defer fm.deinit();

    const mins = try indexing.computeMinimizers(alloc, seq.view(), 3, 3);
    defer alloc.free(mins);

    var searcher = SearchLayer.init(alloc, &fm, mins, seq.view());
    var query = try dna_type.DNA2.init("CGT", alloc);
    defer query.deinit();

    const exact = searcher.exactMatch(query.view());
    try std.testing.expect(exact.end > exact.start);
    
    const approx = searcher.seedAndExtend(query.view(), 1);
    alloc.free(approx);
    
    const banded = searcher.banding(query.view(), 5);
    alloc.free(banded);
    
    const chained = searcher.chaining(mins);
    alloc.free(chained);
}
