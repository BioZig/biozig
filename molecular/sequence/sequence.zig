const std = @import("std");

/// Helper to extract the element type of a sequence.
pub fn ElementType(comptime SeqType: type) type {
    const CleanSeq = if (comptime @typeInfo(SeqType) == .pointer) @typeInfo(SeqType).pointer.child else SeqType;
    if (comptime @hasDecl(CleanSeq, "get")) {
        const func_info = @typeInfo(@TypeOf(CleanSeq.get));
        return func_info.@"fn".return_type.?;
    }
    switch (@typeInfo(SeqType)) {
        .pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .array => |arr| return arr.child,
                else => return ptr.child,
            }
        },
        .array => |arr| return arr.child,
        else => @compileError("Unsupported sequence type: " ++ @typeName(SeqType)),
    }
}

/// Returns the element at the given index for any sequence type.
/// Supports both types with a `.get(index)` method (e.g. packed sequences) and standard slices.
pub inline fn get(seq: anytype, index: usize) ElementType(@TypeOf(seq)) {
    const T = @TypeOf(seq);
    if (comptime @hasDecl(T, "get")) {
        return seq.get(index);
    } else if (comptime @typeInfo(T) == .pointer and @hasDecl(@typeInfo(T).pointer.child, "get")) {
        return seq.get(index);
    } else {
        return seq[index];
    }
}

/// Generic iterator over any sequence type.
pub fn Iterator(comptime SeqType: type) type {
    return struct {
        seq: SeqType,
        index: usize = 0,

        const Self = @This();
        pub const Element = ElementType(SeqType);

        pub fn next(self: *Self) ?Element {
            const length = if (comptime @typeInfo(SeqType) == .pointer) self.seq.len else self.seq.len;
            if (self.index >= length) return null;
            const val = get(self.seq, self.index);
            self.index += 1;
            return val;
        }
    };
}

/// A read-only generic sequence view wrapper for standard slices.
pub fn SequenceView(comptime T: type) type {
    return struct {
        bytes: []const T,
        len: usize,

        const Self = @This();

        pub fn init(bytes: []const T) Self {
            return .{
                .bytes = bytes,
                .len = bytes.len,
            };
        }

        pub fn get(self: Self, index: usize) T {
            std.debug.assert(index < self.len);
            return self.bytes[index];
        }

        pub fn slice(self: Self, start: usize, end: usize) Self {
            std.debug.assert(start <= end and end <= self.len);
            return .{
                .bytes = self.bytes[start..end],
                .len = end - start,
            };
        }

        pub fn iterator(self: Self) Iterator(Self) {
            return .{ .seq = self };
        }
    };
}

/// Generic k-mer iterator yielding sliding sub-views of length k.
pub fn KmerIterator(comptime ViewType: type) type {
    return struct {
        view: ViewType,
        k: usize,
        index: usize = 0,

        const Self = @This();

        pub fn next(self: *Self) ?ViewType {
            if (self.index + self.k > self.view.len) return null;
            const sub = self.view.slice(self.index, self.index + self.k);
            self.index += 1;
            return sub;
        }
    };
}

/// Checks if two sequences are identical in length and elements.
pub fn equal(a: anytype, b: anytype) bool {
    if (a.len != b.len) return false;
    for (0..a.len) |i| {
        if (get(a, i) != get(b, i)) return false;
    }
    return true;
}

/// Generates a deterministic hash of the sequence contents using xxHash64.
pub fn hash(seq: anytype) u64 {
    const XxHash64 = @import("core").hashing.XxHash64;
    var hash_val: u64 = 5381;
    for (0..seq.len) |i| {
        const val = get(seq, i);
        // Cast element to integer for hashing
        const int_val = @as(usize, @intFromEnum(val));
        var bytes: [@sizeOf(usize)]u8 = undefined;
        std.mem.writeInt(usize, &bytes, int_val, .little);
        hash_val = XxHash64.hash(&bytes, hash_val);
    }
    return hash_val;
}

/// Serializes sequence contents using core binary serialization.
pub fn serialize(writer: anytype, seq: anytype) !void {
    const serializeBinary = @import("core").serialization.serialize;
    try serializeBinary(writer, @as(u64, seq.len));
    for (0..seq.len) |i| {
        const val = get(seq, i);
        const int_val = @intFromEnum(val);
        try serializeBinary(writer, int_val);
    }
}

/// Deserializes a sequence into a destination buffer/slice.
pub fn deserializeInto(reader: anytype, dest: anytype) !void {
    const deserializeBinary = @import("core").serialization.deserialize;
    const len = try deserializeBinary(reader, u64, std.heap.page_allocator);
    std.debug.assert(len == dest.len);
    for (0..len) |i| {
        // Element is read as its backing enum tag type
        const Element = @TypeOf(get(dest, 0));
        const Tag = @typeInfo(Element).@"enum".tag_type;
        const val = try deserializeBinary(reader, Tag, std.heap.page_allocator);
        dest.set(i, @enumFromInt(val));
    }
}

/// Computes the Hamming distance between two sequences of equal length.
pub fn hammingDistance(a: anytype, b: anytype) usize {
    std.debug.assert(a.len == b.len);

    const T_a = @TypeOf(a);
    const T_b = @TypeOf(b);
    const is_u8_a = comptime ElementType(T_a) == u8;
    const is_u8_b = comptime ElementType(T_b) == u8;

    if (comptime is_u8_a and is_u8_b) {
        const slice_a: ?[]const u8 = if (comptime @typeInfo(T_a) == .pointer) a else if (comptime @hasField(T_a, "bytes")) a.bytes else null;
        const slice_b: ?[]const u8 = if (comptime @typeInfo(T_b) == .pointer) b else if (comptime @hasField(T_b, "bytes")) b.bytes else null;

        if (slice_a != null and slice_b != null) {
            const sa = slice_a.?;
            const sb = slice_b.?;
            if (sa.len == a.len and sb.len == b.len) {
                const vec_len = 32;
                var i: usize = 0;
                var dist: usize = 0;

                while (i + vec_len <= a.len) : (i += vec_len) {
                    const va: @Vector(vec_len, u8) = sa[i..][0..vec_len].*;
                    const vb: @Vector(vec_len, u8) = sb[i..][0..vec_len].*;
                    const mismatches = va != vb;
                    const mismatch_ints = @select(u8, mismatches, @as(@Vector(vec_len, u8), @splat(1)), @as(@Vector(vec_len, u8), @splat(0)));
                    dist += @reduce(.Add, mismatch_ints);
                }
                while (i < a.len) : (i += 1) {
                    if (sa[i] != sb[i]) dist += 1;
                }
                return dist;
            }
        }
    }

    var dist: usize = 0;
    for (0..a.len) |i| {
        if (get(a, i) != get(b, i)) {
            dist += 1;
        }
    }
    return dist;
}

/// Computes the Levenshtein edit distance between two sequences using O(min(M,N)) memory.
pub fn editDistance(a: anytype, b: anytype, allocator: std.mem.Allocator) !usize {
    const len_a = a.len;
    const len_b = b.len;
    if (len_a == 0) return len_b;
    if (len_b == 0) return len_a;

    const min_len = @min(len_a, len_b);
    const max_len = @max(len_a, len_b);

    const use_a_as_row = len_a <= len_b;
    const row_len = min_len + 1;

    var current_row = try allocator.alloc(usize, row_len);
    defer allocator.free(current_row);
    var previous_row = try allocator.alloc(usize, row_len);
    defer allocator.free(previous_row);

    for (0..row_len) |i| {
        previous_row[i] = i;
    }

    for (0..max_len) |j| {
        current_row[0] = j + 1;
        for (0..min_len) |i| {
            const val_a = if (use_a_as_row) get(a, i) else get(a, j);
            const val_b = if (use_a_as_row) get(b, j) else get(b, i);
            const cost: usize = if (val_a == val_b) 0 else 1;
            const insert_cost = previous_row[i + 1] + 1;
            const delete_cost = current_row[i] + 1;
            const substitute_cost = previous_row[i] + cost;
            current_row[i + 1] = @min(@min(insert_cost, delete_cost), substitute_cost);
        }
        @memcpy(previous_row, current_row);
    }
    return previous_row[min_len];
}

pub const GTRParams = struct {
    pi: [4]f64,        // Stationary base frequencies (A, C, G, T)
    alpha: f64,        // Transition rate
    beta: f64,         // Transversion rate
    gamma_shape: f64,  // Shape parameter for rate heterogeneity
};

/// Estimates GTR parameters from an entire MSA (array of sequences).
pub fn estimateGTRParams(msa: anytype) GTRParams {
    var counts = [4]usize{ 0, 0, 0, 0 };
    var total_bases: usize = 0;
    
    // Pass 1: Compute base frequencies
    for (msa) |seq| {
        for (0..seq.len) |i| {
            const base = get(seq, i);
            counts[@intFromEnum(base)] += 1;
            total_bases += 1;
        }
    }
    
    var pi: [4]f64 = undefined;
    for (0..4) |i| {
        pi[i] = @as(f64, @floatFromInt(counts[i])) / @as(f64, @floatFromInt(total_bases));
    }
    
    // Pass 2: Compute transition and transversion empirical frequencies
    var transitions: usize = 0;
    var transversions: usize = 0;
    var total_pairs: usize = 0;
    
    for (0..msa.len) |i| {
        for (i + 1..msa.len) |j| {
            const seq_i = msa[i];
            const seq_j = msa[j];
            std.debug.assert(seq_i.len == seq_j.len);
            for (0..seq_i.len) |k| {
                const b1 = get(seq_i, k);
                const b2 = get(seq_j, k);
                if (b1 != b2) {
                    const is_transition = (b1 == .A and b2 == .G) or (b1 == .G and b2 == .A) or
                                          (b1 == .C and b2 == .T) or (b1 == .T and b2 == .C);
                    if (is_transition) {
                        transitions += 1;
                    } else {
                        transversions += 1;
                    }
                }
                total_pairs += 1;
            }
        }
    }
    
    const alpha = if (total_pairs > 0) @as(f64, @floatFromInt(transitions)) / @as(f64, @floatFromInt(total_pairs)) else 0.0;
    const beta = if (total_pairs > 0) @as(f64, @floatFromInt(transversions)) / @as(f64, @floatFromInt(total_pairs)) else 0.0;
    
    return GTRParams{
        .pi = pi,
        .alpha = alpha,
        .beta = beta,
        .gamma_shape = 1.0, // Default uniform rate heterogeneity
    };
}

/// Computes the GTR distance between two sequences given the global parameters.
pub fn gtrDistance(a: anytype, b: anytype, params: GTRParams) f64 {
    std.debug.assert(a.len == b.len);
    
    var transitions: usize = 0;
    var transversions: usize = 0;
    
    for (0..a.len) |i| {
        const b1 = get(a, i);
        const b2 = get(b, i);
        if (b1 != b2) {
            const is_transition = (b1 == .A and b2 == .G) or (b1 == .G and b2 == .A) or
                                  (b1 == .C and b2 == .T) or (b1 == .T and b2 == .C);
            if (is_transition) {
                transitions += 1;
            } else {
                transversions += 1;
            }
        }
    }
    
    const p = @as(f64, @floatFromInt(transitions)) / @as(f64, @floatFromInt(a.len));
    const q = @as(f64, @floatFromInt(transversions)) / @as(f64, @floatFromInt(a.len));
    
    // Simplification to Kimura 2-Parameter distance using empirical alpha/beta and pi
    // For a strict GTR, this would involve matrix exponentiation. 
    // This serves as the closed-form log transformation.
    const py = params.pi[1] + params.pi[3]; // pyrimidines
    const pr = params.pi[0] + params.pi[2]; // purines
    
    _ = py;
    _ = pr;
    
    const w1 = 1.0 - 2.0 * p - q;
    const w2 = 1.0 - 2.0 * q;
    
    // Avoid log of negative numbers for highly divergent sequences
    const log_w1 = if (w1 > 0) @log(w1) else -10.0;
    const log_w2 = if (w2 > 0) @log(w2) else -10.0;
    
    return -0.5 * log_w1 - 0.25 * log_w2;
}

