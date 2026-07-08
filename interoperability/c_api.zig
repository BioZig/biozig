const std = @import("std");
const core = @import("core");

/// Global reference to the engine's memory arena.
/// In a C-ABI context, we map the entire C lifecycle into this single arena.
pub var c_arena: ?*std.heap.ArenaAllocator = null;

/// Initializes the BioZig engine and its memory arena.
/// Returns 0 on success, -1 on failure.
export fn biozig_context_create() callconv(.c) c_int {
    if (c_arena != null) return -1; // Already initialized

    const allocator = std.heap.page_allocator;
    const arena_ptr = allocator.create(std.heap.ArenaAllocator) catch return -1;
    arena_ptr.* = std.heap.ArenaAllocator.init(allocator);
    c_arena = arena_ptr;

    return 0;
}

/// Instantly deallocates the entire BioZig engine memory arena.
/// Returns 0 on success.
export fn biozig_context_destroy() callconv(.c) c_int {
    if (c_arena) |arena_ptr| {
        arena_ptr.deinit();
        std.heap.page_allocator.destroy(arena_ptr);
        c_arena = null;
        return 0;
    }
    return -1; // Not initialized
}

/// A simple test function to verify the C-ABI is responsive.
/// Returns 42.
export fn biozig_ping() callconv(.c) c_int {
    return 42;
}

pub const CBiozigAlignmentResult = extern struct {
    score: c_int,
    aligned_a: [*c]const u8,
    aligned_b: [*c]const u8,
};

/// Performs Needleman-Wunsch global sequence alignment on two raw C strings.
/// It dynamically allocates the result strings inside the BioZig Arena.
/// Ensure `biozig_context_create()` has been called prior.
export fn biozig_align_global(seq_a_c: [*c]const u8, seq_b_c: [*c]const u8, match_score: c_int, mismatch_penalty: c_int, gap_penalty: c_int) callconv(.c) CBiozigAlignmentResult {
    const error_res = CBiozigAlignmentResult{ .score = -999999, .aligned_a = null, .aligned_b = null };

    const arena_ptr = c_arena orelse return error_res;
    const alloc = arena_ptr.allocator();

    const seq_a = std.mem.span(seq_a_c);
    const seq_b = std.mem.span(seq_b_c);

    const dna = @import("molecular").dna;
    const alignment = @import("algorithms").molecular.alignment;

    const dna2_a = dna.DNA2.init(seq_a, alloc) catch return error_res;
    const view_a = dna2_a.view();

    const dna2_b = dna.DNA2.init(seq_b, alloc) catch return error_res;
    const view_b = dna2_b.view();

    const opts = alignment.AlignmentOptions{
        .match_score = @intCast(match_score),
        .mismatch_penalty = @intCast(mismatch_penalty),
        .gap_penalty = @intCast(gap_penalty),
    };

    const result = alignment.globalAlignment(alloc, view_a, view_b, opts) catch return error_res;

    // Convert zig slices back to null-terminated C strings in the arena
    const c_align_a = alloc.dupeZ(u8, result.aligned_a) catch return error_res;
    const c_align_b = alloc.dupeZ(u8, result.aligned_b) catch return error_res;

    return CBiozigAlignmentResult{
        .score = @intCast(result.score),
        .aligned_a = c_align_a.ptr,
        .aligned_b = c_align_b.ptr,
    };
}

/// Computes the Shannon Entropy of a nucleotide sequence.
/// Returns a double precision float.
export fn biozig_shannon_entropy(seq_c: [*c]const u8) callconv(.c) f64 {
    const arena_ptr = c_arena orelse return 0.0;
    const alloc = arena_ptr.allocator();
    const seq = std.mem.span(seq_c);
    const dna = @import("molecular").dna;
    const information = @import("algorithms").molecular.information;

    const dna2 = dna.DNA2.init(seq, alloc) catch return 0.0;
    const view = dna2.view();

    return information.shannonEntropy(view);
}

/// Translates a DNA string into an Amino Acid string using the standard genetic code.
/// The result is null-terminated and dynamically allocated in the arena.
export fn biozig_translate_dna(seq_c: [*c]const u8) callconv(.c) [*c]const u8 {
    const arena_ptr = c_arena orelse return null;
    const alloc = arena_ptr.allocator();
    const seq = std.mem.span(seq_c);
    const dna = @import("molecular").dna;
    const coding = @import("algorithms").molecular.coding;

    const dna2 = dna.DNA2.init(seq, alloc) catch return null;
    const view = dna2.view();

    const protein = coding.translateDNA(alloc, view) catch return null;
    const c_protein = alloc.dupeZ(u8, protein) catch return null;

    return c_protein.ptr;
}

// Incorporate the Network C ABI endpoints
comptime {
    _ = @import("c_api_net.zig");
}

test "C-ABI Context" {
    try std.testing.expect(biozig_context_create() == 0);
    try std.testing.expect(biozig_context_create() == -1); // Duplicate fails
    try std.testing.expect(biozig_ping() == 42);
    try std.testing.expect(biozig_context_destroy() == 0);
}

comptime {
    _ = @import("c_abi_parsers.zig");
}
comptime {
    _ = @import("c_abi_structural.zig");
}
comptime {
    _ = @import("c_abi_molecular.zig");
}
comptime {
    _ = @import("c_abi_analytics.zig");
}
comptime {
    _ = @import("c_abi_cellular.zig");
}
comptime {
    _ = @import("c_abi_systems.zig");
}
comptime {
    _ = @import("c_abi_evolutionary.zig");
}
comptime {
    _ = @import("c_abi_population.zig");
}
