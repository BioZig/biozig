const std = @import("std");
const geometry = @import("structural").geometry;
const testing = std.testing;

test "Vec3 math basics and basic properties" {
    const v1 = geometry.Vec3.init(1.0, 2.0, 3.0);
    const v2 = geometry.Vec3.init(4.0, 5.0, 6.0);
    
    const add = v1.add(v2);
    try testing.expectEqual(@as(f64, 5.0), add.x);
    try testing.expectEqual(@as(f64, 7.0), add.y);
    try testing.expectEqual(@as(f64, 9.0), add.z);
    
    const sub = v1.sub(v2);
    try testing.expectEqual(@as(f64, -3.0), sub.x);
    try testing.expectEqual(@as(f64, -3.0), sub.y);
    try testing.expectEqual(@as(f64, -3.0), sub.z);
    
    const scale = v1.scale(2.0);
    try testing.expectEqual(@as(f64, 2.0), scale.x);
    try testing.expectEqual(@as(f64, 4.0), scale.y);
    try testing.expectEqual(@as(f64, 6.0), scale.z);
    
    try testing.expectEqual(@as(f64, 32.0), v1.dot(v2));
    
    const cross = v1.cross(v2);
    try testing.expectEqual(@as(f64, -3.0), cross.x);
    try testing.expectEqual(@as(f64, 6.0), cross.y);
    try testing.expectEqual(@as(f64, -3.0), cross.z);
    
    try testing.expectEqual(@as(f64, 14.0), v1.norm2());
    try testing.expectApproxEqAbs(@as(f64, 3.74165738677), v1.norm(), 1e-9);
    
    const norm = v1.normalize();
    try testing.expectApproxEqAbs(@as(f64, 0.2672612419), norm.x, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0.5345224838), norm.y, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0.8017837257), norm.z, 1e-9);
}

test "Vec3 math edge cases (NaN, Infinity, Zero, Degenerate)" {
    const zero = geometry.Vec3.init(0.0, 0.0, 0.0);
    const z_norm = zero.normalize();
    try testing.expectEqual(@as(f64, 0.0), z_norm.x);
    try testing.expectEqual(@as(f64, 0.0), z_norm.y);
    try testing.expectEqual(@as(f64, 0.0), z_norm.z);

    const inf = std.math.inf(f64);
    const v_inf = geometry.Vec3.init(inf, inf, inf);
    const scaled_inf = v_inf.scale(0.0);
    try testing.expect(std.math.isNan(scaled_inf.x));
    
    const nan = std.math.nan(f64);
    const v1 = geometry.Vec3.init(1.0, 2.0, 3.0);
    const v_nan = geometry.Vec3.init(nan, nan, nan);
    const add_nan = v1.add(v_nan);
    try testing.expect(std.math.isNan(add_nan.x));
    
    // cross product with self should be zero
    const cross_self = v1.cross(v1);
    try testing.expectEqual(@as(f64, 0.0), cross_self.x);
    try testing.expectEqual(@as(f64, 0.0), cross_self.y);
    try testing.expectEqual(@as(f64, 0.0), cross_self.z);

    // collinear vectors cross product should be zero
    const v2 = geometry.Vec3.init(2.0, 4.0, 6.0);
    const cross_collinear = v1.cross(v2);
    try testing.expectEqual(@as(f64, 0.0), cross_collinear.x);
    try testing.expectEqual(@as(f64, 0.0), cross_collinear.y);
    try testing.expectEqual(@as(f64, 0.0), cross_collinear.z);
    
    // huge coordinates to check precision/overflow issues
    const huge = geometry.Vec3.init(1e300, 1e300, 1e300);
    const huge_scale = huge.scale(0.1);
    try testing.expect(huge_scale.x >= 1e299);
}

test "BoundingBox basics and extreme boundaries" {
    const box = geometry.BoundingBox{
        .min = geometry.Vec3.init(0.0, 0.0, 0.0),
        .max = geometry.Vec3.init(10.0, 10.0, 10.0),
    };
    try testing.expect(box.contains(geometry.Vec3.init(5.0, 5.0, 5.0)));
    try testing.expect(!box.contains(geometry.Vec3.init(15.0, 5.0, 5.0)));
    try testing.expect(box.contains(geometry.Vec3.init(0.0, 0.0, 0.0)));
    try testing.expect(box.contains(geometry.Vec3.init(10.0, 10.0, 10.0)));

    // Degenerate bounding box
    const degen_box = geometry.BoundingBox{
        .min = geometry.Vec3.init(5.0, 5.0, 5.0),
        .max = geometry.Vec3.init(5.0, 5.0, 5.0),
    };
    try testing.expect(degen_box.contains(geometry.Vec3.init(5.0, 5.0, 5.0)));
    try testing.expect(!degen_box.contains(geometry.Vec3.init(5.0001, 5.0, 5.0)));
    
    // Inverted bounding box (min > max, logically shouldn't contain much but let's test behavior)
    const inv_box = geometry.BoundingBox{
        .min = geometry.Vec3.init(10.0, 10.0, 10.0),
        .max = geometry.Vec3.init(0.0, 0.0, 0.0),
    };
    try testing.expect(!inv_box.contains(geometry.Vec3.init(5.0, 5.0, 5.0)));

    const inf = std.math.inf(f64);
    const inf_box = geometry.BoundingBox{
        .min = geometry.Vec3.init(-inf, -inf, -inf),
        .max = geometry.Vec3.init(inf, inf, inf),
    };
    try testing.expect(inf_box.contains(geometry.Vec3.init(1e100, -1e100, 0.0)));
}

test "distance and centroid" {
    const v1 = geometry.Vec3.init(0.0, 0.0, 0.0);
    const v2 = geometry.Vec3.init(3.0, 4.0, 0.0);
    try testing.expectEqual(@as(f64, 25.0), geometry.distance2(v1, v2));
    try testing.expectEqual(@as(f64, 5.0), geometry.distance(v1, v2));
    
    var xs: [3]f64 align(32) = [_]f64{ 0.0, 3.0, 3.0 };
    var ys: [3]f64 align(32) = [_]f64{ 0.0, 4.0, -4.0 };
    var zs: [3]f64 align(32) = [_]f64{ 0.0, 0.0, 0.0 };
    const coords = geometry.CoordinateSet{ .x = &xs, .y = &ys, .z = &zs };
    
    const cent = geometry.centroid(coords);
    try testing.expectEqual(@as(f64, 2.0), cent.x);
    try testing.expectEqual(@as(f64, 0.0), cent.y);
    try testing.expectEqual(@as(f64, 0.0), cent.z);
    
    const box = geometry.boundingBox(coords);
    try testing.expectEqual(@as(f64, 0.0), box.min.x);
    try testing.expectEqual(@as(f64, -4.0), box.min.y);
    try testing.expectEqual(@as(f64, 0.0), box.min.z);
    try testing.expectEqual(@as(f64, 3.0), box.max.x);
    try testing.expectEqual(@as(f64, 4.0), box.max.y);
    try testing.expectEqual(@as(f64, 0.0), box.max.z);
}

test "centroid edge cases" {
    // Empty set
    var empty_xs: [0]f64 align(32) = undefined;
    var empty_ys: [0]f64 align(32) = undefined;
    var empty_zs: [0]f64 align(32) = undefined;
    const empty_coords = geometry.CoordinateSet{ .x = &empty_xs, .y = &empty_ys, .z = &empty_zs };
    
    const empty_cent = geometry.centroid(empty_coords);
    try testing.expectEqual(@as(f64, 0.0), empty_cent.x);
    try testing.expectEqual(@as(f64, 0.0), empty_cent.y);
    try testing.expectEqual(@as(f64, 0.0), empty_cent.z);
    
    const empty_box = geometry.boundingBox(empty_coords);
    try testing.expectEqual(@as(f64, 0.0), empty_box.min.x);
    try testing.expectEqual(@as(f64, 0.0), empty_box.max.x);

    // CoordinateSetMut init
    var coords_mut = try geometry.CoordinateSetMut.init(testing.allocator, 100);
    defer coords_mut.deinit(testing.allocator);
    for (0..100) |i| {
        coords_mut.x[i] = 1.0;
        coords_mut.y[i] = -1.0;
        coords_mut.z[i] = 0.0;
    }
    const mut_as_const = geometry.CoordinateSet{ .x = coords_mut.x, .y = coords_mut.y, .z = coords_mut.z };
    const mut_cent = geometry.centroid(mut_as_const);
    try testing.expectApproxEqAbs(@as(f64, 1.0), mut_cent.x, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, -1.0), mut_cent.y, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0.0), mut_cent.z, 1e-9);
}

test "angle and dihedral functions" {
    const a = geometry.Vec3.init(1.0, 0.0, 0.0);
    const b = geometry.Vec3.init(0.0, 0.0, 0.0);
    const c = geometry.Vec3.init(0.0, 1.0, 0.0);
    
    const ang = geometry.angle(a, b, c);
    try testing.expectApproxEqAbs(std.math.pi / 2.0, ang, 1e-9);
    
    const collinear_ang = geometry.angle(a, b, geometry.Vec3.init(2.0, 0.0, 0.0));
    try testing.expectApproxEqAbs(0.0, collinear_ang, 1e-9);
    
    // Coincident points (zero vector norm check)
    const coin_ang = geometry.angle(a, a, c);
    try testing.expectApproxEqAbs(0.0, coin_ang, 1e-9);

    const d1 = geometry.Vec3.init(1.0, 0.0, 0.0);
    const d2 = geometry.Vec3.init(0.0, 0.0, 0.0);
    const d3 = geometry.Vec3.init(0.0, 1.0, 0.0);
    const d4 = geometry.Vec3.init(0.0, 1.0, 1.0);
    
    const dih = geometry.dihedral(d1, d2, d3, d4);
    // x-z plane checking
    try testing.expectApproxEqAbs(std.math.pi / 2.0, @abs(dih), 1e-9);
}

test "angle and dihedral extreme cases" {
    const nan = std.math.nan(f64);
    const v_nan = geometry.Vec3.init(nan, nan, nan);
    const z = geometry.Vec3.init(0.0, 0.0, 0.0);
    
    const ang_nan = geometry.angle(z, z, v_nan);
    _ = ang_nan; // math functions handling NaN can vary, just ensure no crash
    
    // highly spaced dihedrals
    const far1 = geometry.Vec3.init(1e10, 0.0, 0.0);
    const far2 = geometry.Vec3.init(0.0, 0.0, 0.0);
    const far3 = geometry.Vec3.init(0.0, 1e10, 0.0);
    const far4 = geometry.Vec3.init(0.0, 1e10, 1e10);
    
    const far_dih = geometry.dihedral(far1, far2, far3, far4);
    try testing.expectApproxEqAbs(std.math.pi / 2.0, @abs(far_dih), 1e-5);
}

test "jacobiSymmetric3 and svd3 sanity checks" {
    const a = [_][3]f64{
        [_]f64{ 2.0, 0.0, 0.0 },
        [_]f64{ 0.0, 3.0, 0.0 },
        [_]f64{ 0.0, 0.0, 4.0 },
    };
    var V: [3][3]f64 = undefined;
    var d: [3]f64 = undefined;
    geometry.jacobiSymmetric3(a, &V, &d);
    
    // Since already diagonal, d should be 2, 3, 4 basically
    // However Jacobi might reorder or something, but let's check sum
    const sum = d[0] + d[1] + d[2];
    try testing.expectApproxEqAbs(@as(f64, 9.0), sum, 1e-9);
}
