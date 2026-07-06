const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

extern fn biozig_structural_atom_create() callconv(.c) ?*anyopaque;
extern fn biozig_structural_assembly_create() callconv(.c) ?*anyopaque;
extern fn biozig_structural_contacts_create() callconv(.c) ?*anyopaque;
extern fn biozig_structural_residue_create() callconv(.c) ?*anyopaque;

pub const CBiozigGeometryVec3 = extern struct {
    x: f64,
    y: f64,
    z: f64,
};
extern fn biozig_structural_geometry_distance(a: CBiozigGeometryVec3, b: CBiozigGeometryVec3) callconv(.c) f64;

test "biozig_structural_creators" {
    _ = @import("c_api");
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    try std.testing.expect(biozig_structural_atom_create() == null);
    try std.testing.expect(biozig_structural_assembly_create() == null);
    try std.testing.expect(biozig_structural_contacts_create() == null);
    try std.testing.expect(biozig_structural_residue_create() == null);
}

test "biozig_structural_geometry_distance" {
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();

    const a = CBiozigGeometryVec3{ .x = 1.0, .y = 2.0, .z = 3.0 };
    const b = CBiozigGeometryVec3{ .x = 4.0, .y = 5.0, .z = 6.0 };

    const dist = biozig_structural_geometry_distance(a, b);
    try std.testing.expect(dist > 5.196 and dist < 5.197); // sqrt(27)
}
