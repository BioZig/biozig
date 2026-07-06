const std = @import("std");
const dna = @import("molecular").dna;
const DNA2View = dna.DNA2View;
const Nucleotide = dna.Nucleotide;

const SAIS = struct {
    fn inducedSort(allocator: std.mem.Allocator, S: []const usize, SA: []usize, type_map: []const bool, bucket_ends: []const usize, bucket_heads: []const usize, lms_strings: []const usize, K: usize) !void {
        @memset(SA, std.math.maxInt(usize));
        
        var b_ends = try allocator.alloc(usize, K);
        defer allocator.free(b_ends);
        @memcpy(b_ends, bucket_ends);
        
        var i: usize = lms_strings.len;
        while (i > 0) {
            i -= 1;
            const p = lms_strings[i];
            const c = S[p];
            b_ends[c] -= 1;
            SA[b_ends[c]] = p;
        }

        var b_heads = try allocator.alloc(usize, K);
        defer allocator.free(b_heads);
        @memcpy(b_heads, bucket_heads);

        for (0..SA.len) |j| {
            if (SA[j] == std.math.maxInt(usize)) continue;
            if (SA[j] == 0) continue;
            const p = SA[j] - 1;
            if (!type_map[p]) {
                const c = S[p];
                SA[b_heads[c]] = p;
                b_heads[c] += 1;
            }
        }

        @memcpy(b_ends, bucket_ends);
        i = SA.len;
        while (i > 0) {
            i -= 1;
            if (SA[i] == std.math.maxInt(usize)) continue;
            if (SA[i] == 0) continue;
            const p = SA[i] - 1;
            if (type_map[p]) {
                const c = S[p];
                b_ends[c] -= 1;
                SA[b_ends[c]] = p;
            }
        }
    }

    pub fn sais(allocator: std.mem.Allocator, S: []const usize, SA: []usize, K: usize) !void {
        const n = S.len;
        if (n == 0) return;
        if (n == 1) {
            SA[0] = 0;
            return;
        }
        var type_map = try allocator.alloc(bool, n);
        defer allocator.free(type_map);
        type_map[n - 1] = true;
        var i: usize = n - 1;
        while (i > 0) {
            i -= 1;
            if (S[i] < S[i + 1]) {
                type_map[i] = true;
            } else if (S[i] > S[i + 1]) {
                type_map[i] = false;
            } else {
                type_map[i] = type_map[i + 1];
            }
        }

        const isLMS = struct {
            fn f(m: []const bool, idx: usize) bool {
                return idx > 0 and m[idx] and !m[idx - 1];
            }
        }.f;

        var lms_strings = try allocator.alloc(usize, n);
        defer allocator.free(lms_strings);
        var num_lms: usize = 0;
        
        for (1..n) |j| {
            if (isLMS(type_map, j)) {
                lms_strings[num_lms] = j;
                num_lms += 1;
            }
        }

        var bucket_sizes = try allocator.alloc(usize, K);
        defer allocator.free(bucket_sizes);
        @memset(bucket_sizes, 0);
        for (S) |c| {
            bucket_sizes[c] += 1;
        }

        var bucket_heads = try allocator.alloc(usize, K);
        defer allocator.free(bucket_heads);
        var bucket_ends = try allocator.alloc(usize, K);
        defer allocator.free(bucket_ends);
        
        var sum: usize = 0;
        for (0..K) |j| {
            bucket_heads[j] = sum;
            sum += bucket_sizes[j];
            bucket_ends[j] = sum;
        }

        try inducedSort(allocator, S, SA, type_map, bucket_ends, bucket_heads, lms_strings[0..num_lms], K);

        var n1: usize = 0;
        for (SA) |p| {
            if (isLMS(type_map, p)) {
                SA[n1] = p;
                n1 += 1;
            }
        }
        @memset(SA[n1..], std.math.maxInt(usize));

        var name: usize = 0;
        var prev: usize = std.math.maxInt(usize);
        for (0..n1) |j| {
            const p = SA[j];
            var diff = false;
            if (prev == std.math.maxInt(usize)) {
                diff = true;
            } else {
                var d: usize = 0;
                while (true) : (d += 1) {
                    if (S[p + d] != S[prev + d] or type_map[p + d] != type_map[prev + d]) {
                        diff = true;
                        break;
                    }
                    if (d > 0 and (isLMS(type_map, p + d) or isLMS(type_map, prev + d))) {
                        if (!isLMS(type_map, p + d) or !isLMS(type_map, prev + d)) diff = true;
                        break;
                    }
                }
            }
            if (diff) {
                name += 1;
                prev = p;
            }
            SA[n1 + p / 2] = name - 1;
        }

        var s1 = try allocator.alloc(usize, n1);
        defer allocator.free(s1);
        var p1 = try allocator.alloc(usize, n1);
        defer allocator.free(p1);

        var idx: usize = 0;
        for (n1..n) |j| {
            if (SA[j] != std.math.maxInt(usize)) {
                s1[idx] = SA[j];
                idx += 1;
            }
        }
        idx = 0;
        for (1..n) |j| {
            if (isLMS(type_map, j)) {
                p1[idx] = j;
                idx += 1;
            }
        }

        var sa1 = try allocator.alloc(usize, n1);
        defer allocator.free(sa1);
        
        if (name < n1) {
            try sais(allocator, s1, sa1, name);
        } else {
            for (0..n1) |j| {
                sa1[s1[j]] = j;
            }
        }

        var sorted_lms = try allocator.alloc(usize, n1);
        defer allocator.free(sorted_lms);
        for (0..n1) |j| {
            sorted_lms[j] = p1[sa1[j]];
        }

        try inducedSort(allocator, S, SA, type_map, bucket_ends, bucket_heads, sorted_lms, K);
    }
};

pub const SuffixArray = struct {
    sa: []usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, seq: DNA2View) !SuffixArray {
        const sa = try allocator.alloc(usize, seq.len + 1);
        errdefer allocator.free(sa);

        // O(N) SA-IS Construction
        var S = try allocator.alloc(usize, seq.len + 1);
        defer allocator.free(S);

        for (0..seq.len) |i| {
            S[i] = @as(usize, @intFromEnum(seq.get(i))) + 1; // 1-based to leave 0 for $
        }
        S[seq.len] = 0; // $ is smallest

        try SAIS.sais(allocator, S, sa, 6); // Alphabet size 6 ($ + 4 nucs)

        return SuffixArray{
            .sa = sa,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SuffixArray) void {
        self.allocator.free(self.sa);
    }
};

pub const BWT = struct {
    bwt: []u8, // Storing as u8 for A, C, G, T and $ (using 4 for $)
    primary_index: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, seq: DNA2View, sa: *const SuffixArray) !BWT {
        var bwt = try allocator.alloc(u8, seq.len + 1);
        errdefer allocator.free(bwt);

        var primary_index: usize = 0;
        for (sa.sa, 0..) |suffix_pos, i| {
            if (suffix_pos == 0) {
                bwt[i] = 0; // $
                primary_index = i;
            } else {
                bwt[i] = @as(u8, @intFromEnum(seq.get(suffix_pos - 1))) + 1;
            }
        }

        return BWT{
            .bwt = bwt,
            .primary_index = primary_index,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BWT) void {
        self.allocator.free(self.bwt);
    }
};

pub const FMIndex = struct {
    bwt: BWT,
    sa: SuffixArray,
    counts: [5]usize,
    occurrences: [][]usize, // For each char 0..4, prefix sum of occurrences
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, seq: DNA2View) !FMIndex {
        var sa = try SuffixArray.init(allocator, seq);
        errdefer sa.deinit();

        var bwt = try BWT.init(allocator, seq, &sa);
        errdefer bwt.deinit();

        var counts = [_]usize{0} ** 5;
        // Count frequencies in BWT
        for (bwt.bwt) |c| {
            counts[c] += 1;
        }

        // Cumulative counts (C array)
        var c_array = [_]usize{0} ** 5;
        var sum: usize = 0;
        for (0..5) |i| {
            c_array[i] = sum;
            sum += counts[i];
        }

        var occurrences = try allocator.alloc([]usize, 5);
        errdefer allocator.free(occurrences);
        for (0..5) |i| {
            occurrences[i] = try allocator.alloc(usize, bwt.bwt.len + 1);
        }
        errdefer {
            for (0..5) |i| allocator.free(occurrences[i]);
        }

        for (0..5) |i| occurrences[i][0] = 0;

        for (bwt.bwt, 0..) |c, i| {
            for (0..5) |char_idx| {
                occurrences[char_idx][i + 1] = occurrences[char_idx][i] + if (c == char_idx) @as(usize, 1) else @as(usize, 0);
            }
        }

        return FMIndex{
            .bwt = bwt,
            .sa = sa,
            .counts = c_array,
            .occurrences = occurrences,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FMIndex) void {
        for (0..5) |i| {
            self.allocator.free(self.occurrences[i]);
        }
        self.allocator.free(self.occurrences);
        self.bwt.deinit();
        self.sa.deinit();
    }

    // Returns the range [start, end) in the suffix array
    pub fn count(self: *const FMIndex, query: DNA2View) struct { start: usize, end: usize } {
        if (query.len == 0) return .{ .start = 0, .end = self.bwt.bwt.len };

        var start: usize = 0;
        var end: usize = self.bwt.bwt.len;

        var i: usize = query.len;
        while (i > 0) {
            i -= 1;
            const c = @as(u8, @intFromEnum(query.get(i))) + 1;
            start = self.counts[c] + self.occurrences[c][start];
            end = self.counts[c] + self.occurrences[c][end];
            if (start >= end) {
                return .{ .start = 0, .end = 0 };
            }
        }
        return .{ .start = start, .end = end };
    }
};

test "Suffix Array and BWT" {
    const alloc = std.testing.allocator;
    const dna_type = @import("molecular").dna;
    var seq = try dna_type.DNA2.init("ACGTACGT", alloc);
    defer seq.deinit();

    var fm = try FMIndex.init(alloc, seq.view());
    defer fm.deinit();

    var query = try dna_type.DNA2.init("CGT", alloc);
    defer query.deinit();
    
    const res = fm.count(query.view());
    try std.testing.expectEqual(@as(usize, 2), res.end - res.start);
}

pub const Minimizer = struct {
    hash: u64,
    pos: usize,
};

pub fn computeMinimizers(allocator: std.mem.Allocator, seq: DNA2View, w: usize, k: usize) ![]Minimizer {
    std.debug.assert(w > 0 and k > 0 and seq.len >= k);
    var minimizers = std.ArrayList(Minimizer).empty;
    errdefer minimizers.deinit(allocator);

    const n_windows = if (seq.len >= w + k - 1) seq.len - w - k + 2 else 0;
    if (n_windows == 0) return minimizers.toOwnedSlice(allocator);

    const QueueItem = struct {
        hash: u64,
        pos: usize,
    };
    
    var deque = try allocator.alloc(QueueItem, seq.len);
    defer allocator.free(deque);
    var head: usize = 0;
    var tail: usize = 0;

    var last_minimizer_pos: ?usize = null;
    
    var current_hash: u64 = 0;
    const mask = if (k == 32) std.math.maxInt(u64) else (@as(u64, 1) << @as(u6, @intCast(2 * k))) - 1;

    for (0..seq.len - k + 1) |i| {
        if (i == 0) {
            for (0..k) |l| {
                current_hash = (current_hash << 2) | @as(u64, @intFromEnum(seq.get(l)));
            }
        } else {
            current_hash = ((current_hash << 2) & mask) | @as(u64, @intFromEnum(seq.get(i + k - 1)));
        }
        
        const mixed_hash = std.hash.Wyhash.hash(0, std.mem.asBytes(&current_hash));

        while (tail > head and deque[tail - 1].hash > mixed_hash) {
            tail -= 1;
        }
        deque[tail] = .{ .hash = mixed_hash, .pos = i };
        tail += 1;

        if (deque[head].pos + w <= i) {
            head += 1;
        }

        if (i >= w - 1) {
            const min_item = deque[head];
            if (last_minimizer_pos == null or last_minimizer_pos.? != min_item.pos) {
                try minimizers.append(allocator, .{ .hash = min_item.hash, .pos = min_item.pos });
                last_minimizer_pos = min_item.pos;
            }
        }
    }

    return minimizers.toOwnedSlice(allocator);
}

test "Minimizers" {
    const alloc = std.testing.allocator;
    const dna_type = @import("molecular").dna;
    var seq = try dna_type.DNA2.init("ACGTACGTACGT", alloc);
    defer seq.deinit();

    const mins = try computeMinimizers(alloc, seq.view(), 3, 3);
    defer alloc.free(mins);
    try std.testing.expect(mins.len > 0);
}
