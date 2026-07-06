const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

extern fn biozig_cellular_cell_create(id: [*c]const u8, num_features: usize) callconv(.c) ?*anyopaque;
extern fn biozig_cellular_cell_add_metadata(cell: ?*anyopaque, key: [*c]const u8, value: [*c]const u8) callconv(.c) c_int;

extern fn biozig_cellular_lineage_node_create(cell_id: [*c]const u8) callconv(.c) ?*anyopaque;
extern fn biozig_cellular_lineage_tree_create() callconv(.c) ?*anyopaque;

extern fn biozig_cellular_cellcycle_assign_phase(g1: f64, s: f64, g2m: f64) callconv(.c) c_int;
extern fn biozig_cellular_cellcycle_state_create(phase_int: c_int) callconv(.c) ?*anyopaque;

extern fn biozig_cellular_dense_matrix_create(rows: usize, cols: usize) callconv(.c) ?*anyopaque;

test "biozig_cellular_cell_create" {
    _ = @import("c_api");
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const id = "cell_1\x00";
    const cell = biozig_cellular_cell_create(id.ptr, 100);
    try std.testing.expect(cell != null);

    const key = "type\x00";
    const val = "T-cell\x00";
    const ret = biozig_cellular_cell_add_metadata(cell, key.ptr, val.ptr);
    try std.testing.expectEqual(@as(c_int, 0), ret);
}

test "biozig_cellular_cellcycle" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const phase = biozig_cellular_cellcycle_assign_phase(0.1, 0.8, 0.1);
    try std.testing.expect(phase >= 0);

    const state = biozig_cellular_cellcycle_state_create(phase);
    try std.testing.expect(state != null);
}

test "biozig_cellular_dense_matrix_create" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const mat = biozig_cellular_dense_matrix_create(10, 10);
    try std.testing.expect(mat != null);
}
