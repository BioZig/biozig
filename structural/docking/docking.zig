const std = @import("std");
const atom_mod = @import("../atom/atom.zig");
const geom = @import("../geometry/geometry.zig");
const Atom = atom_mod.Atom;
const Vec3 = geom.Vec3;
const BoundingBox = geom.BoundingBox;

/// Represents a rigid-body transformation (rotation + translation).
/// Primarily used to orient ligands during docking simulations.
pub const RigidTransform = struct {
    /// 3x3 rotation matrix
    rotation: [3][3]f64,
    /// Translation vector
    translation: Vec3,

    /// Initializes a rigid transform with rotation and translation.
    pub fn init(rotation: [3][3]f64, translation: Vec3) RigidTransform {
        return .{ .rotation = rotation, .translation = translation };
    }

    /// Returns the identity rigid transformation.
    pub fn identity() RigidTransform {
        return .{
            .rotation = .{
                .{ 1.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 1.0 },
            },
            .translation = Vec3.init(0.0, 0.0, 0.0),
        };
    }

    /// Applies the rigid transform to a 3D coordinate.
    pub fn apply(self: RigidTransform, p: Vec3) Vec3 {
        const r = self.rotation;
        const t = self.translation;
        return Vec3.init(
            r[0][0] * p.x + r[0][1] * p.y + r[0][2] * p.z + t.x,
            r[1][0] * p.x + r[1][1] * p.y + r[1][2] * p.z + t.y,
            r[2][0] * p.x + r[2][1] * p.y + r[2][2] * p.z + t.z,
        );
    }

    /// Inverts the rigid transform.
    /// Uses the property that the inverse of a proper rotation matrix R is its transpose R^T.
    pub fn invert(self: RigidTransform) RigidTransform {
        const r = self.rotation;
        const inv_r = [3][3]f64{
            .{ r[0][0], r[1][0], r[2][0] },
            .{ r[0][1], r[1][1], r[2][1] },
            .{ r[0][2], r[1][2], r[2][2] },
        };
        const t = self.translation;
        const inv_t = Vec3.init(
            -(inv_r[0][0] * t.x + inv_r[0][1] * t.y + inv_r[0][2] * t.z),
            -(inv_r[1][0] * t.x + inv_r[1][1] * t.y + inv_r[1][2] * t.z),
            -(inv_r[2][0] * t.x + inv_r[2][1] * t.y + inv_r[2][2] * t.z),
        );
        return .{ .rotation = inv_r, .translation = inv_t };
    }

    /// Composes two transforms (returns self * other, representing 'other' then 'self').
    pub fn compose(self: RigidTransform, other: RigidTransform) RigidTransform {
        const r1 = self.rotation;
        const r2 = other.rotation;

        var r_new: [3][3]f64 = undefined;
        for (0..3) |i| {
            for (0..3) |j| {
                r_new[i][j] = r1[i][0] * r2[0][j] + r1[i][1] * r2[1][j] + r1[i][2] * r2[2][j];
            }
        }

        const t2 = other.translation;
        const t1 = self.translation;
        const t_new = Vec3.init(
            r1[0][0] * t2.x + r1[0][1] * t2.y + r1[0][2] * t2.z + t1.x,
            r1[1][0] * t2.x + r1[1][1] * t2.y + r1[1][2] * t2.z + t1.y,
            r1[2][0] * t2.x + r1[2][1] * t2.y + r1[2][2] * t2.z + t1.z,
        );
        return .{ .rotation = r_new, .translation = t_new };
    }
};

/// Container representing docking scores divided into energy components.
pub const DockingScore = struct {
    /// Total binding score (lower is more favorable/stable)
    total_score: f64,
    /// Electrostatic contribution
    electrostatic: f64,
    /// Van der Waals contribution
    vanderwaals: f64,
    /// Desolvation contribution
    desolvation: f64,
    /// Conformational entropy penalty
    entropy: f64,

    /// Initializes a DockingScore container.
    pub fn init(total: f64, electrostatic: f64, vdw: f64, desolv: f64, entropy: f64) DockingScore {
        return .{
            .total_score = total,
            .electrostatic = electrostatic,
            .vanderwaals = vdw,
            .desolvation = desolv,
            .entropy = entropy,
        };
    }

    /// Checks if this score is better than another. Lower total scores represent higher binding affinity.
    pub fn betterThan(self: DockingScore, other: DockingScore) bool {
        return self.total_score < other.total_score;
    }
};

/// Represents a distinct structural pose of a ligand.
pub const Pose = struct {
    /// Identifier for this pose
    pose_id: usize,
    /// original (untransformed) ligand atoms reference
    atoms: []const Atom,
    /// Transformation applied to the ligand
    transform: RigidTransform,
    /// Score evaluation for this pose
    score: DockingScore,

    /// Initializes a Pose.
    pub fn init(pose_id: usize, atoms: []const Atom, transform: RigidTransform, score: DockingScore) Pose {
        return .{
            .pose_id = pose_id,
            .atoms = atoms,
            .transform = transform,
            .score = score,
        };
    }

    /// Retrieves the transformed coordinate of the atom at index.
    pub fn getTransformedPos(self: Pose, index: usize) Vec3 {
        return self.transform.apply(self.atoms[index].pos);
    }

    /// Writes the transformed coordinate of all atoms in this pose to dest.
    pub fn writeTransformedCoordinates(self: Pose, dest: []Vec3) !void {
        if (dest.len != self.atoms.len) return error.SliceLengthMismatch;
        for (self.atoms, 0..) |atom, i| {
            dest[i] = self.transform.apply(atom.pos);
        }
    }

    /// Calculates the centroid of the transformed pose.
    pub fn centroid(self: Pose) Vec3 {
        if (self.atoms.len == 0) return Vec3.init(0, 0, 0);
        var sum = Vec3.init(0, 0, 0);
        for (self.atoms) |atom| {
            const p = self.transform.apply(atom.pos);
            sum = sum.add(p);
        }
        return sum.scale(1.0 / @as(f64, @floatFromInt(self.atoms.len)));
    }

    /// Calculates the bounding box enclosing all transformed atoms in this pose.
    pub fn boundingBox(self: Pose) BoundingBox {
        if (self.atoms.len == 0) {
            return .{ .min = Vec3.init(0, 0, 0), .max = Vec3.init(0, 0, 0) };
        }
        var min = self.transform.apply(self.atoms[0].pos);
        var max = min;
        for (self.atoms[1..]) |atom| {
            const p = self.transform.apply(atom.pos);
            min.x = @min(min.x, p.x);
            min.y = @min(min.y, p.y);
            min.z = @min(min.z, p.z);
            max.x = @max(max.x, p.x);
            max.y = @max(max.y, p.y);
            max.z = @max(max.z, p.z);
        }
        return .{ .min = min, .max = max };
    }
};

test "Rigid transform and docking pose operations" {
    // 1. Check RigidTransform inversion and composition
    const rot = [3][3]f64{
        .{ 0.0, -1.0, 0.0 },
        .{ 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0 },
    }; // 90 degree Z rotation
    const trans = Vec3.init(1.0, 2.0, 3.0);
    const transform = RigidTransform.init(rot, trans);

    const p = Vec3.init(1.0, 0.0, 0.0);
    const p_trans = transform.apply(p);
    // x' = 0*1 - 1*0 + 1 = 1
    // y' = 1*1 + 0*0 + 2 = 3
    // z' = 0 + 3 = 3
    try std.testing.expectApproxEqAbs(p_trans.x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(p_trans.y, 3.0, 1e-5);
    try std.testing.expectApproxEqAbs(p_trans.z, 3.0, 1e-5);

    const inv = transform.invert();
    const p_back = inv.apply(p_trans);
    try std.testing.expectApproxEqAbs(p_back.x, p.x, 1e-5);
    try std.testing.expectApproxEqAbs(p_back.y, p.y, 1e-5);
    try std.testing.expectApproxEqAbs(p_back.z, p.z, 1e-5);

    const composed = transform.compose(inv);
    const p_comp = composed.apply(p_trans);
    try std.testing.expectApproxEqAbs(p_comp.x, p_trans.x, 1e-5);

    // 2. DockingScore comparison
    const score1 = DockingScore.init(-8.5, -2.0, -6.0, 0.5, 1.0);
    const score2 = DockingScore.init(-7.2, -1.5, -5.0, 0.7, 1.0);
    try std.testing.expect(score1.betterThan(score2));

    // 3. Pose properties
    const atom1 = try Atom.init(1, "O", .O, Vec3.init(0, 0, 0), 1.0, 20.0, null);
    const atom2 = try Atom.init(2, "H", .H, Vec3.init(1.0, 0, 0), 1.0, 20.0, null);
    const atoms = [_]Atom{ atom1, atom2 };

    const pose = Pose.init(42, &atoms, transform, score1);
    try std.testing.expectEqual(pose.pose_id, 42);
    try std.testing.expectApproxEqAbs(pose.getTransformedPos(0).x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(pose.getTransformedPos(1).x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(pose.getTransformedPos(1).y, 3.0, 1e-5);

    const cent = pose.centroid();
    try std.testing.expectApproxEqAbs(cent.x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(cent.y, 2.5, 1e-5);

    const bbox = pose.boundingBox();
    try std.testing.expect(bbox.contains(cent));
}
