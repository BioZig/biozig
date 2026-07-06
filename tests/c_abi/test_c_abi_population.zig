const std = @import("std");

comptime {
    _ = @import("c_api");
}

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

const CBiozigLDStats = extern struct {
    r_squared: f64,
    d_prime: f64,
};

extern fn biozig_ld_matrix_create(loci: [*c][*c]const u8, num_loci: usize) callconv(.c) ?*anyopaque;
extern fn biozig_ld_matrix_set(mat_ptr: ?*anyopaque, row: usize, col: usize, r2: f64, dp: f64) callconv(.c) void;
extern fn biozig_ld_matrix_get(mat_ptr: ?*anyopaque, row: usize, col: usize) callconv(.c) CBiozigLDStats;

test "biozig_population_ld_matrix" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const loci = [_][*c]const u8{ "locus1\x00", "locus2\x00" };
    const mat = biozig_ld_matrix_create(@constCast(&loci[0]), 2);
    try std.testing.expect(mat != null);

    biozig_ld_matrix_set(mat, 0, 0, 0.95, 0.95);
    const val = biozig_ld_matrix_get(mat, 0, 0);
    try std.testing.expectEqual(@as(f64, 0.95), val.r_squared);
}
