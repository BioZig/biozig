const std = @import("std");

/// The number of hash functions used for the MinHash sketch.
/// 256 provides a robust approximation of Jaccard similarity within ~6% error margin.
pub const SKETCH_SIZE: usize = 256;

/// A simple, blazing fast 64-bit integer hash (XorShift variant) for CPU register hashing.
inline fn wyhash64(x: u64, seed: u64) u64 {
    var a = x ^ seed;
    a ^= a >> 30;
    a *%= 0xbf58476d1ce4e5b9;
    a ^= a >> 27;
    a *%= 0x94d049bb133111eb;
    a ^= a >> 31;
    return a;
}

/// Represents the MinHash signature of a single sequence.
pub const Sketch = struct {
    hashes: [SKETCH_SIZE]u64,

    pub fn init() Sketch {
        var self = Sketch{ .hashes = undefined };
        @memset(&self.hashes, std.math.maxInt(u64));
        return self;
    }

    /// Computes Jaccard Similarity between two sketches.
    /// Returns a float between 0.0 (no overlap) and 1.0 (identical).
    pub fn jaccardSimilarity(self: *const Sketch, other: *const Sketch) f32 {
        var matches: usize = 0;
        for (0..SKETCH_SIZE) |i| {
            if (self.hashes[i] == other.hashes[i]) {
                matches += 1;
            }
        }
        return @as(f32, @floatFromInt(matches)) / @as(f32, @floatFromInt(SKETCH_SIZE));
    }
};

/// Generates a MinHash sketch directly from a packed sequence slice.
/// `k` is the k-mer length (max 32 for 2-bit DNA, max 12 for 5-bit Protein to fit inside a 64-bit integer).
/// `bits_per_element` is 2 for DNA/RNA, 5 for Proteins.
pub fn generateSketch(packed_data: []const u8, sequence_len: usize, k: u8, bits_per_element: u8) Sketch {
    // 2-bit DNA: max k=32 (64 bits). 5-bit Protein: max k=12 (60 bits).
    std.debug.assert(k * bits_per_element <= 64);
    
    var sketch = Sketch.init();
    if (sequence_len < k) return sketch;
    
    var window: u64 = 0;
    const k_mask: u64 = if (k * bits_per_element == 64) std.math.maxInt(u64) else (@as(u64, 1) << @as(u6, @intCast(k * bits_per_element))) - 1;
    const elem_mask: u32 = (@as(u32, 1) << @as(u5, @intCast(bits_per_element))) - 1;

    // Helper to read an element crossing byte boundaries
    const get_element = struct {
        fn f(data: []const u8, idx: usize, bpe: u8, mask: u32) u64 {
            const bit_offset = idx * bpe;
            const byte_idx = bit_offset / 8;
            const bit_shift = bit_offset % 8;
            
            var val: u32 = data[byte_idx];
            if (bit_shift + bpe > 8 and byte_idx + 1 < data.len) {
                val |= @as(u32, data[byte_idx + 1]) << 8;
                if (bit_shift + bpe > 16 and byte_idx + 2 < data.len) {
                    val |= @as(u32, data[byte_idx + 2]) << 16;
                }
            }
            return @as(u64, (val >> @as(u5, @truncate(bit_shift))) & mask);
        }
    }.f;
    
    // Initialize the first k-1 bases into the window
    for (0..k - 1) |i| {
        const nuc = get_element(packed_data, i, bits_per_element, elem_mask);
        window = (window << @as(u6, @intCast(bits_per_element))) | nuc;
    }
    
    // Slide window over the rest of the sequence
    for (k - 1..sequence_len) |i| {
        const nuc = get_element(packed_data, i, bits_per_element, elem_mask);
        window = ((window << @as(u6, @intCast(bits_per_element))) | nuc) & k_mask;
        
        for (0..SKETCH_SIZE) |h_idx| {
            const h = wyhash64(window, @as(u64, @intCast(h_idx * 0x9E3779B185EBCA87)));
            if (h < sketch.hashes[h_idx]) {
                sketch.hashes[h_idx] = h;
            }
        }
    }
    
    return sketch;
}

pub const Edge = struct {
    u: u32,
    v: u32,
    distance: f32, // Jaccard distance (1.0 - similarity)
};

/// GraphReconstructor orchestrates the initial MinHash graph reconstruction.
pub const GraphReconstructor = struct {
    allocator: std.mem.Allocator,
    kmer_size: u8,
    similarity_threshold: f32,
    bits_per_element: u8,

    pub fn init(allocator: std.mem.Allocator, kmer_size: u8, similarity_threshold: f32, bits_per_element: u8) GraphReconstructor {
        return .{
            .allocator = allocator,
            .kmer_size = kmer_size,
            .similarity_threshold = similarity_threshold,
            .bits_per_element = bits_per_element,
        };
    }

    /// Constructs the sparse edge list from an array of 2-bit packed sequences.
    /// `sequence_lens` provides the biological length of each packed array.
    pub fn buildSparseGraph(self: *GraphReconstructor, packed_sequences: [][]const u8, sequence_lens: []const usize) ![]Edge {
        // 1. Generate sketches for all sequences
        var sketches = try self.allocator.alloc(Sketch, packed_sequences.len);
        defer self.allocator.free(sketches);
        
        // TODO: This can be trivially parallelized using std.Thread.Pool
        for (0..packed_sequences.len) |i| {
            sketches[i] = generateSketch(packed_sequences[i], sequence_lens[i], self.kmer_size, self.bits_per_element);
        }

        // 2. Compute pairwise Jaccard similarities and build sparse edge list
        var edges = std.ArrayList(Edge).init(self.allocator);
        errdefer edges.deinit();

        for (0..sketches.len) |i| {
            for (i + 1..sketches.len) |j| {
                const similarity = sketches[i].jaccardSimilarity(&sketches[j]);
                if (similarity >= self.similarity_threshold) {
                    try edges.append(Edge{
                        .u = @as(u32, @intCast(i)),
                        .v = @as(u32, @intCast(j)),
                        .distance = 1.0 - similarity, // We need distance for topological filtration
                    });
                }
            }
        }

        return edges.toOwnedSlice();
    }
};
