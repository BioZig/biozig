const std = @import("std");
const structural = @import("structural_alg");

const Vec3 = structural.Vec3;
const CoordinateSet = structural.CoordinateSet;
const CoordinateSetMut = structural.CoordinateSetMut;

test "Structural - distance exact" {
    const a: Vec3 = .{ 0, 0, 0 };
    const b: Vec3 = .{ 3, 4, 0 };
    try std.testing.expectEqual(@as(f64, 5.0), structural.distance(a, b));

    const c: Vec3 = .{ 1, 1, 1 };
    const d: Vec3 = .{ 1, 1, 1 };
    try std.testing.expectEqual(@as(f64, 0.0), structural.distance(c, d));
}

test "Structural - computeDistanceMatrix empty and NaNs" {
    const alloc = std.testing.allocator;
    var empty_x = [_]f64{};
    var empty_y = [_]f64{};
    var empty_z = [_]f64{};
    const empty_cs = CoordinateSet{ .x = &empty_x, .y = &empty_y, .z = &empty_z };
    const empty_mat = try structural.computeDistanceMatrix(alloc, empty_cs);
    defer alloc.free(empty_mat);
    try std.testing.expectEqual(@as(usize, 0), empty_mat.len);

    var nan_x = [_]f64{std.math.nan(f64), 0};
    var nan_y = [_]f64{std.math.nan(f64), 0};
    var nan_z = [_]f64{std.math.nan(f64), 0};
    const nan_cs = CoordinateSet{ .x = &nan_x, .y = &nan_y, .z = &nan_z };
    const nan_mat = try structural.computeDistanceMatrix(alloc, nan_cs);
    defer alloc.free(nan_mat);
    try std.testing.expect(std.math.isNan(nan_mat[1]));
}

test "Structural - computeDistanceMatrixBlock empty" {
    const alloc = std.testing.allocator;
    const empty_points = [_]Vec3{};
    const mat = try structural.computeDistanceMatrixBlock(alloc, &empty_points, &empty_points);
    defer alloc.free(mat);
    try std.testing.expectEqual(@as(usize, 0), mat.len);
}

test "Structural - computeContactMap edge cases" {
    const alloc = std.testing.allocator;
    const empty_points = [_]Vec3{};
    const empty_map = try structural.computeContactMap(alloc, &empty_points, 1.0);
    defer alloc.free(empty_map);
    try std.testing.expectEqual(@as(usize, 0), empty_map.len);

    const points = [_]Vec3{ .{0,0,0}, .{1.1,0,0} };
    const map = try structural.computeContactMap(alloc, &points, 1.0);
    defer alloc.free(map);
    try std.testing.expect(map[0*2+0]); // self
    try std.testing.expect(!map[0*2+1]); // 1.1 > 1.0
}

test "Structural - computeRMSD empty" {
    var empty_x = [_]f64{};
    var empty_y = [_]f64{};
    var empty_z = [_]f64{};
    const empty_cs = CoordinateSet{ .x = &empty_x, .y = &empty_y, .z = &empty_z };
    
    const rmsd = try structural.computeRMSD(empty_cs, empty_cs);
    try std.testing.expectEqual(@as(f64, 0.0), rmsd);
}

test "Structural - computeRMSD length mismatch" {
    var x1 = [_]f64{1.0};
    var y1 = [_]f64{1.0};
    var z1 = [_]f64{1.0};
    var x2 = [_]f64{1.0, 2.0};
    var y2 = [_]f64{1.0, 2.0};
    var z2 = [_]f64{1.0, 2.0};
    
    const cs1 = CoordinateSet{ .x = &x1, .y = &y1, .z = &z1 };
    const cs2 = CoordinateSet{ .x = &x2, .y = &y2, .z = &z2 };
    
    try std.testing.expectError(error.LengthMismatch, structural.computeRMSD(cs1, cs2));
}

test "Structural - computeCentroid empty" {
    var empty_x = [_]f64{};
    var empty_y = [_]f64{};
    var empty_z = [_]f64{};
    const empty_cs = CoordinateSet{ .x = &empty_x, .y = &empty_y, .z = &empty_z };
    const c = structural.computeCentroid(empty_cs);
    try std.testing.expectEqual(@as(f64, 0.0), c[0]);
    try std.testing.expectEqual(@as(f64, 0.0), c[1]);
    try std.testing.expectEqual(@as(f64, 0.0), c[2]);
}

test "Structural - centerPoints empty" {
    const alloc = std.testing.allocator;
    var points = try CoordinateSetMut.init(alloc, 0);
    defer points.deinit(alloc);
    structural.centerPoints(points);
}

test "Structural - computeKabschRotation exact match" {
    var x = [_]f64{ 1.0, 2.0 };
    var y = [_]f64{ 1.0, 2.0 };
    var z = [_]f64{ 1.0, 2.0 };
    const a = CoordinateSet{ .x = &x, .y = &y, .z = &z };
    const r = try structural.computeKabschRotation(a, a);
    
    // Should be identity matrix
    try std.testing.expectApproxEqAbs(1.0, r[0][0], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, r[0][1], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, r[0][2], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, r[1][0], 1e-5);
    try std.testing.expectApproxEqAbs(1.0, r[1][1], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, r[1][2], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, r[2][0], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, r[2][1], 1e-5);
    try std.testing.expectApproxEqAbs(1.0, r[2][2], 1e-5);
}

test "Structural - computeOptimalRMSD mismatch" {
    const alloc = std.testing.allocator;
    var x1 = [_]f64{1.0};
    var y1 = [_]f64{1.0};
    var z1 = [_]f64{1.0};
    var x2 = [_]f64{1.0, 2.0};
    var y2 = [_]f64{1.0, 2.0};
    var z2 = [_]f64{1.0, 2.0};
    const cs1 = CoordinateSet{ .x = &x1, .y = &y1, .z = &z1 };
    const cs2 = CoordinateSet{ .x = &x2, .y = &y2, .z = &z2 };
    try std.testing.expectError(error.LengthMismatch, structural.computeOptimalRMSD(alloc, cs1, cs2));
}

test "Structural - detectHydrogenBonds edge case max dist" {
    const alloc = std.testing.allocator;
    const donors = [_]Vec3{ .{0,0,0} };
    const acceptors = [_]Vec3{ .{0.5,0,0} };
    
    const hbonds1 = try structural.detectHydrogenBonds(alloc, &donors, &acceptors, 0.4);
    defer alloc.free(hbonds1);
    try std.testing.expectEqual(@as(usize, 0), hbonds1.len);

    const hbonds2 = try structural.detectHydrogenBonds(alloc, &donors, &acceptors, 0.5);
    defer alloc.free(hbonds2);
    try std.testing.expectEqual(@as(usize, 1), hbonds2.len);
}

test "Structural - computePocketStatistics edge cases" {
    const alloc = std.testing.allocator;
    const empty_points = [_]Vec3{};
    const empty_hydro = [_]f64{};
    const stats1 = try structural.computePocketStatistics(alloc, &empty_points, &empty_hydro);
    try std.testing.expectEqual(@as(f64, 0.0), stats1.volume);

    const points = [_]Vec3{ .{0,0,0} };
    const hydro_mismatch = [_]f64{};
    try std.testing.expectError(error.LengthMismatch, structural.computePocketStatistics(alloc, &points, &hydro_mismatch));
}

test "Structural - comparePockets exact" {
    const p1 = structural.PocketStatistics{ .volume = 10.0, .surface_area = 20.0, .hydrophobicity = 1.0 };
    try std.testing.expectEqual(@as(f64, 0.0), structural.comparePockets(p1, p1));
}

test "Structural - computeSurfaceMetrics empty" {
    const empty_points = [_]Vec3{};
    try std.testing.expectEqual(@as(f64, 0.0), structural.computeSurfaceMetrics(&empty_points));
}

test "Structural - computeRadiusOfGyration empty" {
    var empty_x = [_]f64{};
    var empty_y = [_]f64{};
    var empty_z = [_]f64{};
    const empty_cs = CoordinateSet{ .x = &empty_x, .y = &empty_y, .z = &empty_z };
    try std.testing.expectEqual(@as(f64, 0.0), structural.computeRadiusOfGyration(empty_cs));
}

test "Structural - computeANMHessian cutoff logic" {
    const alloc = std.testing.allocator;
    const coords = [_]Vec3{ .{0,0,0}, .{10,0,0} }; // far apart
    const H = try structural.computeANMHessian(alloc, &coords, 5.0, 1.0); // cutoff is 5.0
    defer alloc.free(H);
    
    // Everything should be 0 since dist is 10 > 5
    for (H) |val| {
        try std.testing.expectEqual(@as(f64, 0.0), val);
    }
}
