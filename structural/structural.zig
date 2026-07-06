const std = @import("std");

pub const atom = @import("atom/atom.zig");
pub const residue = @import("residue/residue.zig");
pub const chain = @import("chain/chain.zig");
pub const model = @import("model/model.zig");
pub const assembly = @import("assembly/assembly.zig");
pub const geometry = @import("geometry/geometry.zig");
pub const contacts = @import("contacts/contacts.zig");
pub const surfaces = @import("surfaces/surfaces.zig");
pub const pockets = @import("pockets/pockets.zig");
pub const docking = @import("docking/docking.zig");

test {
    // Reference submodules to force compiler analysis and run their internal tests
    _ = atom;
    _ = residue;
    _ = chain;
    _ = model;
    _ = assembly;
    _ = geometry;
    _ = contacts;
    _ = surfaces;
    _ = pockets;
    _ = docking;
}

test "Geometry: basic distance, angles, and dihedrals" {
    const Vec3 = geometry.Vec3;

    const p1 = Vec3.init(0.0, 0.0, 0.0);
    const p2 = Vec3.init(3.0, 4.0, 0.0);
    try std.testing.expectApproxEqAbs(geometry.distance(p1, p2), 5.0, 1e-9);
    try std.testing.expectApproxEqAbs(geometry.distance2(p1, p2), 25.0, 1e-9);

    // Angle of 90 degrees (pi/2 radians)
    const a = Vec3.init(1.0, 0.0, 0.0);
    const b = Vec3.init(0.0, 0.0, 0.0);
    const c = Vec3.init(0.0, 1.0, 0.0);
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, geometry.angle(a, b, c), 1e-9);

    // Dihedral angle of 0 degrees (cis-planar)
    const d1 = Vec3.init(0.0, 1.0, 0.0);
    const d2 = Vec3.init(0.0, 0.0, 0.0);
    const d3 = Vec3.init(1.0, 0.0, 0.0);
    const d4_cis = Vec3.init(1.0, 1.0, 0.0);
    try std.testing.expectApproxEqAbs(0.0, geometry.dihedral(d1, d2, d3, d4_cis), 1e-9);

    // Dihedral angle of 180 degrees (trans-planar)
    const d4_trans = Vec3.init(1.0, -1.0, 0.0);
    try std.testing.expectApproxEqAbs(std.math.pi, geometry.dihedral(d1, d2, d3, d4_trans), 1e-9);
}

test "Geometry: Jacobi symmetric diagonalization and SVD" {
    const H = [3][3]f64{
        .{ 3.0, 2.0, 4.0 },
        .{ 2.0, 0.0, 2.0 },
        .{ 4.0, 2.0, 3.0 },
    };

    var V = [_][3]f64{[_]f64{0} ** 3} ** 3;
    var d = [_]f64{0} ** 3;
    geometry.jacobiSymmetric3(H, &V, &d);

    // Verify V * diag(d) * V^T recovers H
    for (0..3) |i| {
        for (0..3) |j| {
            var sum: f64 = 0.0;
            for (0..3) |k| {
                sum += V[i][k] * d[k] * V[j][k];
            }
            try std.testing.expectApproxEqAbs(sum, H[i][j], 1e-9);
        }
    }

    // Verify SVD of a non-symmetric matrix
    const M = [3][3]f64{
        .{ 1.0, 2.0, 3.0 },
        .{ 0.0, 1.0, 4.0 },
        .{ 5.0, 6.0, 0.0 },
    };
    var U = [_][3]f64{[_]f64{0} ** 3} ** 3;
    var S = [_]f64{0} ** 3;
    var V_svd = [_][3]f64{[_]f64{0} ** 3} ** 3;
    geometry.svd3(M, &U, &S, &V_svd);

    // Verify M = U * S * V^T
    for (0..3) |i| {
        for (0..3) |j| {
            var sum: f64 = 0.0;
            for (0..3) |k| {
                sum += U[i][k] * S[k] * V_svd[j][k];
            }
            try std.testing.expectApproxEqAbs(sum, M[i][j], 1e-9);
        }
    }
}

test "Geometry: Kabsch superposition" {
    const Vec3 = geometry.Vec3;

    // Rotation around Z axis by 30 degrees (0.52359877 radians)
    const theta = 30.0 * std.math.pi / 180.0;
    const cos_t = @cos(theta);
    const sin_t = @sin(theta);
    const R = [3][3]f64{
        .{ cos_t, -sin_t, 0.0 },
        .{ sin_t,  cos_t, 0.0 },
        .{ 0.0,    0.0,   1.0 },
    };
    const t = Vec3.init(10.0, -5.0, 2.5);

    const x_x align(32) = [_]f64{ 0, 1, 0, 1 };
    const x_y align(32) = [_]f64{ 0, 0, 1, 1 };
    const x_z align(32) = [_]f64{ 0, 0, 0, 1 };
    const x_coords = geometry.CoordinateSet{ .x = &x_x, .y = &x_y, .z = &x_z };

    // Generate Y = R * X + t
    var y_x: [4]f64 align(32) = undefined;
    var y_y: [4]f64 align(32) = undefined;
    var y_z: [4]f64 align(32) = undefined;
    for (0..4) |i| {
        y_x[i] = R[0][0]*x_x[i] + R[0][1]*x_y[i] + R[0][2]*x_z[i] + t.x;
        y_y[i] = R[1][0]*x_x[i] + R[1][1]*x_y[i] + R[1][2]*x_z[i] + t.y;
        y_z[i] = R[2][0]*x_x[i] + R[2][1]*x_y[i] + R[2][2]*x_z[i] + t.z;
    }
    const y_coords = geometry.CoordinateSet{ .x = &y_x, .y = &y_y, .z = &y_z };

    // Run Kabsch superposition
    const res = try geometry.kabsch(x_coords, y_coords);
    const transform = res.@"0";
    const rmsd = res.@"1";

    // Expected RMSD is exactly 0.0 (modulo float precision)
    try std.testing.expectApproxEqAbs(rmsd, 0.0, 1e-9);

    // Verify reconstructed rotation matrix matches R
    for (0..3) |i| {
        for (0..3) |j| {
            try std.testing.expectApproxEqAbs(transform.rotation[i][j], R[i][j], 1e-9);
        }
    }
}

test "Atom: binary serialization and deserialization roundtrip" {
    const allocator = std.testing.allocator;
    const original = try atom.Atom.init(
        1337,
        "CA",
        .C,
        geometry.Vec3.init(12.34, -56.78, 90.12),
        0.95,
        22.5,
        -1,
    );

    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try original.serialize(&writer);

    const written = writer.buffered();
    var reader = std.Io.Reader.fixed(written);
    const deserialized = try atom.Atom.deserialize(&reader, allocator);

    try std.testing.expect(original.equals(deserialized));
}

test "Model and Assembly: traversal and bounding box" {
    // Construct dummy structure
    const atom1 = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(0, 0, 0), 1.0, 20.0, null);
    const atom2 = try atom.Atom.init(2, "CA", .C, geometry.Vec3.init(1.4, 0, 0), 1.0, 20.0, null);
    const atoms = [_]atom.Atom{ atom1, atom2 };

    const res = try residue.Residue.init(1, "GLY", &atoms);
    const residues = [_]residue.Residue{res};

    const ch = try chain.Chain.init("A", &residues);
    const chains = [_]chain.Chain{ch};

    const mod = model.Model.init(1, &chains);
    const models = [_]model.Model{mod};

    // Assembly with Identity + Translation transform
    const t1 = assembly.AssemblyTransform{
        .rotation = .{
            .{ 1, 0, 0 },
            .{ 0, 1, 0 },
            .{ 0, 0, 1 },
        },
        .translation = geometry.Vec3.init(10.0, 0.0, 0.0),
    };
    const transforms = [_]assembly.AssemblyTransform{t1};

    const ass = assembly.Assembly.init(&models, &transforms);

    // Traverse and check
    const Context = struct {
        count: usize = 0,
        const Self = @This();
        pub fn cb(self: *Self, id: usize, el: atom.Element, pos: geometry.Vec3) void {
            _ = id;
            _ = el;
            // First atom translated by 10 should be at (10, 0, 0)
            if (self.count == 0) {
                std.debug.assert(pos.x == 10.0);
            }
            self.count += 1;
        }
    };
    var ctx = Context{};
    ass.traverseAtoms(&ctx, Context.cb);
    try std.testing.expectEqual(ctx.count, 2);

    const bbox = ass.boundingBox();
    // Bbox should enclose (10, 0, 0) and (11.4, 0, 0)
    try std.testing.expectApproxEqAbs(bbox.min.x, 10.0, 1e-9);
    try std.testing.expectApproxEqAbs(bbox.max.x, 11.4, 1e-9);
}
