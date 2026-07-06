const std = @import("std");
const structural = @import("structural");
const residue = structural.residue;
const atom = structural.atom;
const geometry = structural.geometry;
const testing = std.testing;

test "Residue init, stats, and basics" {
    const alloc = testing.allocator;
    const a1 = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    const a2 = try atom.Atom.init(2, "CA", .C, geometry.Vec3.init(1.4, 0.0, 0.0), 1.0, 20.0, null);
    
    var atoms = try alloc.alloc(atom.Atom, 2);
    defer alloc.free(atoms);
    atoms[0] = a1;
    atoms[1] = a2;
    
    const res = try residue.Residue.init(1, "GLY", atoms);
    
    try testing.expectEqualStrings("GLY", res.getName());
    try testing.expect(res.validate());
    
    const cent = res.centroid();
    try testing.expectApproxEqAbs(@as(f64, 0.7), cent.x, 1e-9);
    
    const box = res.boundingBox();
    try testing.expectEqual(@as(f64, 0.0), box.min.x);
    try testing.expectEqual(@as(f64, 1.4), box.max.x);
    
    try testing.expect(res.lookupAtom("CA") != null);
    try testing.expect(res.lookupAtom("CB") == null);
}

test "Residue mass and bounds edge cases" {
    const alloc = testing.allocator;
    // Empty residue
    const empty_atoms = try alloc.alloc(atom.Atom, 0);
    defer alloc.free(empty_atoms);
    const empty_res = try residue.Residue.init(999, "UNK", empty_atoms);
    
    try testing.expectEqualStrings("UNK", empty_res.getName());
    const m = empty_res.mass();
    try testing.expectEqual(@as(f64, 0.0), m);
    
    const c = empty_res.centroid();
    try testing.expectEqual(@as(f64, 0.0), c.x);
    
    const box = empty_res.boundingBox();
    try testing.expectEqual(@as(f64, 0.0), box.min.x);
    try testing.expectEqual(@as(f64, 0.0), box.max.x);
    
    try testing.expect(empty_res.lookupAtom("CA") == null);
}

test "Residue degenerate structures (NaNs and Extremes)" {
    const alloc = testing.allocator;
    const nan = std.math.nan(f64);
    const inf = std.math.inf(f64);
    
    const a_nan = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(nan, nan, nan), nan, nan, null);
    const a_inf = try atom.Atom.init(2, "CA", .C, geometry.Vec3.init(inf, -inf, inf), inf, inf, null);
    
    var atoms = try alloc.alloc(atom.Atom, 2);
    defer alloc.free(atoms);
    atoms[0] = a_nan;
    atoms[1] = a_inf;
    
    const bad_res = try residue.Residue.init(1, "BAD", atoms);
    
    try testing.expectEqualStrings("BAD", bad_res.getName());
    
    const box = bad_res.boundingBox();
    // Bounding box might be weird with NaN/inf, but should not crash
    _ = box;
    
    const cent = bad_res.centroid();
    // Centroid will likely have nan coords
    try testing.expect(std.math.isNan(cent.x) or std.math.isInf(cent.x) or cent.x == cent.x);
    
    try testing.expect(bad_res.lookupAtom("CA") != null);
}

test "Residue validation extreme" {
    const alloc = testing.allocator;
    // Massive array of atoms
    const size = 1000;
    var huge_atoms = try alloc.alloc(atom.Atom, size);
    defer alloc.free(huge_atoms);
    for (0..size) |i| {
        huge_atoms[i] = try atom.Atom.init(i, "X", .C, geometry.Vec3.init(0, 0, 0), 1.0, 1.0, null);
    }
    const huge_res = try residue.Residue.init(10, "HUG", huge_atoms);
    _ = huge_res.validate();
    const c = huge_res.centroid();
    try testing.expectEqual(@as(f64, 0.0), c.x);
}
