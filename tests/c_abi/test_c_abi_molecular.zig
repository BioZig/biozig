const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

extern fn biozig_hamming_distance(seq_a_c: [*c]const u8, seq_b_c: [*c]const u8) callconv(.c) c_longlong;
extern fn biozig_levenshtein_distance(seq_a_c: [*c]const u8, seq_b_c: [*c]const u8) callconv(.c) c_longlong;

pub const CBiozigMotifHits = extern struct {
    positions: [*c]c_longlong,
    count: c_int,
};

extern fn biozig_search_motif_exact(seq_c: [*c]const u8, motif_c: [*c]const u8) callconv(.c) CBiozigMotifHits;

extern fn biozig_count_kmers(seq_c: [*c]const u8, k: c_int) callconv(.c) c_longlong;

test "biozig_molecular_distances" {
    _ = @import("c_api");
    
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();
    
    const seq_a = "ATCG\x00";
    const seq_b = "ATCC\x00";
    
    const h_dist = biozig_hamming_distance(seq_a.ptr, seq_b.ptr);
    try std.testing.expectEqual(@as(c_longlong, 1), h_dist);
    
    const l_dist = biozig_levenshtein_distance(seq_a.ptr, seq_b.ptr);
    try std.testing.expectEqual(@as(c_longlong, 1), l_dist);
}

test "biozig_search_motif_exact" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();
    
    const seq = "ATCGATCG\x00";
    const motif = "ATCG\x00";
    
    const res = biozig_search_motif_exact(seq.ptr, motif.ptr);
    try std.testing.expect(res.positions != null);
    try std.testing.expectEqual(@as(c_int, 2), res.count);
}

test "biozig_count_kmers" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();
    
    const seq = "ATCGATCG\x00";
    const k = 2;
    
    const count = biozig_count_kmers(seq.ptr, k);
    try std.testing.expect(count > 0);
}
