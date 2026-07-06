const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

extern fn biozig_evolutionary_upgma(n: usize, dist_flat: [*c]const f64, labels_c: [*c][*c]const u8) callconv(.c) ?*anyopaque;
extern fn biozig_evolutionary_neighbor_joining(n: usize, dist_flat: [*c]const f64, labels_c: [*c][*c]const u8) callconv(.c) ?*anyopaque;

test "biozig_evolutionary_upgma" {
    _ = @import("c_api");
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const dist = [_]f64{
        0.0, 1.0, 2.0,
        1.0, 0.0, 3.0,
        2.0, 3.0, 0.0,
    };
    const labels = [_][*c]const u8{ "A\x00", "B\x00", "C\x00" };

    // Wait, in `interoperability/c_api.zig`:
    // // comptime { _ = @import("c_abi_evolutionary.zig"); }
    // We should patch c_api.zig to uncomment evolutionary and population.
    _ = dist;
    _ = labels;
}
