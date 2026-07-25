const std = @import("std");

pub const SequenceType = enum {
    DNA,
    Protein,
};

pub fn detectSequenceType(sequences: [][]const u8) SequenceType {
    var count: usize = 0;
    for (sequences) |seq| {
        for (seq) |c| {
            const upper = std.ascii.toUpper(c);
            if (upper != 'A' and upper != 'C' and upper != 'G' and upper != 'T' and upper != 'U' and upper != 'N' and upper != '-') {
                return .Protein;
            }
        }
        count += 1;
        if (count >= 5) break;
    }
    return .DNA;
}

pub const SequenceGraph = struct {
    allocator: std.mem.Allocator,
    num_sequences: usize,
    distances: []f64,
    seq_type: SequenceType,

    pub fn init(allocator: std.mem.Allocator, num_seqs: usize, seq_type: SequenceType) !SequenceGraph {
        const num_pairs = (num_seqs * (num_seqs - 1)) / 2;
        const dists = try allocator.alloc(f64, num_pairs);
        @memset(dists, 1.0);
        return SequenceGraph{
            .allocator = allocator,
            .num_sequences = num_seqs,
            .distances = dists,
            .seq_type = seq_type,
        };
    }

    pub fn deinit(self: *SequenceGraph) void {
        self.allocator.free(self.distances);
    }

    pub fn setDistance(self: *SequenceGraph, i: usize, j: usize, dist: f64) void {
        std.debug.assert(i != j);
        const min = @min(i, j);
        const max = @max(i, j);
        const n = self.num_sequences;
        const idx = n * min - min * (min + 1) / 2 + max - min - 1;
        self.distances[idx] = dist;
    }

    pub fn getDistance(self: *const SequenceGraph, i: usize, j: usize) f64 {
        if (i == j) return 0.0;
        const min = @min(i, j);
        const max = @max(i, j);
        const n = self.num_sequences;
        const idx = n * min - min * (min + 1) / 2 + max - min - 1;
        return self.distances[idx];
    }
};

inline fn packDNA(char: u8) u64 {
    const upper = std.ascii.toUpper(char);
    return switch (upper) {
        'C' => 1,
        'G' => 2,
        'T', 'U' => 3,
        else => 0,
    };
}

inline fn packProtein(char: u8) u64 {
    const upper = std.ascii.toUpper(char);
    if (upper < 'A' or upper > 'Z') return 0;
    return @as(u64, upper - 'A') & 31;
}

pub fn buildGraph(allocator: std.mem.Allocator, sequences: [][]const u8, user_k: usize) !SequenceGraph {
    const seq_type = detectSequenceType(sequences);
    
    const k = if (user_k > 0) user_k else if (seq_type == .DNA) @as(usize, 7) else @as(usize, 5);
    
    var graph = try SequenceGraph.init(allocator, sequences.len, seq_type);
    errdefer graph.deinit();

    var local_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer local_arena.deinit();
    const temp_allocator = local_arena.allocator();

    var kmer_sets = try temp_allocator.alloc(std.AutoHashMap(u64, void), sequences.len);

    // Populate k-mer sets using Bit Packing
    for (sequences, 0..) |seq, i| {
        kmer_sets[i] = std.AutoHashMap(u64, void).init(temp_allocator);
        if (seq.len >= k) {
            // Pre-calculate the bitshift based on sequence type
            const shift_bits: u5 = if (seq_type == .DNA) 2 else 5;
            
            var j: usize = 0;
            while (j <= seq.len - k) : (j += 1) {
                var packed_kmer: u64 = 0;
                for (0..k) |offset| {
                    const char = seq[j + offset];
                    const bits = if (seq_type == .DNA) packDNA(char) else packProtein(char);
                    packed_kmer = (packed_kmer << shift_bits) | bits;
                }
                try kmer_sets[i].put(packed_kmer, {});
            }
        }
    }

    for (0..sequences.len) |i| {
        for (0..i) |j| {
            const set_a = &kmer_sets[i];
            const set_b = &kmer_sets[j];

            const size_a = set_a.count();
            const size_b = set_b.count();

            if (size_a == 0 or size_b == 0) {
                graph.setDistance(i, j, 1.0);
                continue;
            }

            const smaller = if (size_a < size_b) set_a else set_b;
            const larger = if (size_a < size_b) set_b else set_a;

            var intersection_size: usize = 0;
            var iter = smaller.keyIterator();
            while (iter.next()) |kmer_ptr| {
                if (larger.contains(kmer_ptr.*)) {
                    intersection_size += 1;
                }
            }

            const union_size = size_a + size_b - intersection_size;
            
            const jaccard = @as(f64, @floatFromInt(intersection_size)) / @as(f64, @floatFromInt(union_size));
            const distance = 1.0 - jaccard;
            
            graph.setDistance(i, j, distance);
        }
    }

    return graph;
}
