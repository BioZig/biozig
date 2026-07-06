const std = @import("std");
const atom_mod = @import("../atom/atom.zig");
const residue_mod = @import("../residue/residue.zig");
const geom = @import("../geometry/geometry.zig");
const Atom = atom_mod.Atom;
const Residue = residue_mod.Residue;
const Vec3 = geom.Vec3;
const BoundingBox = geom.BoundingBox;

/// Represents structural statistics of a pocket.
pub const PocketStats = struct {
    num_atoms: usize,
    num_residues: usize,
    volume: f64,
    centroid: Vec3,
    span: Vec3,
};

/// Represents a pocket (e.g., ligand binding cavity or active site) in a molecular structure.
pub const Pocket = struct {
    /// Constituent atoms forming the surface/walls of the pocket.
    atoms: []const Atom,
    /// Constituent residues lining the pocket.
    residues: []const Residue,
    /// Pre-computed or estimated pocket volume in cubic Angstroms.
    volume: f64,
    /// Geometric centroid of the pocket.
    centroid: Vec3,
    /// Bounding box enclosing the pocket atoms/residues.
    bounding_box: BoundingBox,

    /// Initializes a new Pocket representation.
    /// Automatically calculates the centroid and bounding box from the constituent atoms
    /// (or constituent residues if no atoms are provided).
    pub fn init(atoms: []const Atom, residues: []const Residue, volume: f64) Pocket {
        var cent = Vec3.init(0, 0, 0);
        var bbox = BoundingBox{ .min = Vec3.init(0, 0, 0), .max = Vec3.init(0, 0, 0) };

        if (atoms.len > 0) {
            // Compute centroid of atoms
            var sum = Vec3.init(0, 0, 0);
            for (atoms) |a| {
                sum = sum.add(a.pos);
            }
            cent = sum.scale(1.0 / @as(f64, @floatFromInt(atoms.len)));

            // Compute bounding box of atoms
            var min = atoms[0].pos;
            var max = atoms[0].pos;
            for (atoms[1..]) |a| {
                min.x = @min(min.x, a.pos.x);
                min.y = @min(min.y, a.pos.y);
                min.z = @min(min.z, a.pos.z);
                max.x = @max(max.x, a.pos.x);
                max.y = @max(max.y, a.pos.y);
                max.z = @max(max.z, a.pos.z);
            }
            bbox = .{ .min = min, .max = max };
        } else if (residues.len > 0) {
            // Fallback to residues
            var sum = Vec3.init(0, 0, 0);
            for (residues) |res| {
                sum = sum.add(res.centroid());
            }
            cent = sum.scale(1.0 / @as(f64, @floatFromInt(residues.len)));

            var min = residues[0].boundingBox().min;
            var max = residues[0].boundingBox().max;
            for (residues[1..]) |res| {
                const r_bbox = res.boundingBox();
                min.x = @min(min.x, r_bbox.min.x);
                min.y = @min(min.y, r_bbox.min.y);
                min.z = @min(min.z, r_bbox.min.z);
                max.x = @max(max.x, r_bbox.max.x);
                max.y = @max(max.y, r_bbox.max.y);
                max.z = @max(max.z, r_bbox.max.z);
            }
            bbox = .{ .min = min, .max = max };
        }

        return Pocket{
            .atoms = atoms,
            .residues = residues,
            .volume = volume,
            .centroid = cent,
            .bounding_box = bbox,
        };
    }

    /// Checks if the pocket contains the atom with the given ID.
    pub fn containsAtom(self: Pocket, atom_id: usize) bool {
        for (self.atoms) |atom| {
            if (atom.id == atom_id) return true;
        }
        return false;
    }

    /// Checks if the pocket contains the residue with the given ID.
    pub fn containsResidue(self: Pocket, residue_id: usize) bool {
        for (self.residues) |res| {
            if (res.id == residue_id) return true;
        }
        return false;
    }

    /// Checks if a point is within the pocket's bounding box.
    pub fn containsPoint(self: Pocket, p: Vec3) bool {
        return self.bounding_box.contains(p);
    }

    /// Checks if a point is within a threshold distance of any constituent atom in the pocket.
    pub fn containsPointDistance(self: Pocket, p: Vec3, threshold: f64) bool {
        for (self.atoms) |atom| {
            if (geom.distance(p, atom.pos) <= threshold) return true;
        }
        return false;
    }

    /// Returns the number of atoms in the pocket.
    pub fn atomCount(self: Pocket) usize {
        return self.atoms.len;
    }

    /// Returns the number of residues lining the pocket.
    pub fn residueCount(self: Pocket) usize {
        return self.residues.len;
    }

    /// Returns summary statistics of the pocket.
    pub fn statistics(self: Pocket) PocketStats {
        const min = self.bounding_box.min;
        const max = self.bounding_box.max;
        return .{
            .num_atoms = self.atoms.len,
            .num_residues = self.residues.len,
            .volume = self.volume,
            .centroid = self.centroid,
            .span = Vec3.init(max.x - min.x, max.y - min.y, max.z - min.z),
        };
    }

    /// Estimates the total volume occupied by the union of VdW spheres of all pocket constituent atoms.
    /// Uses a deterministic grid-based voxelization approach inside the pocket's bounding box.
    /// This runs in O(N_voxels * N_atoms) time with O(1) memory.
    pub fn estimateUnionVolume(self: Pocket, voxel_size: f64) f64 {
        if (self.atoms.len == 0) return 0.0;
        if (voxel_size <= 0.0) return 0.0;

        const bbox = self.bounding_box;
        const span_x = bbox.max.x - bbox.min.x;
        const span_y = bbox.max.y - bbox.min.y;
        const span_z = bbox.max.z - bbox.min.z;

        const nx = @as(usize, @intFromFloat(@max(1.0, @ceil(span_x / voxel_size))));
        const ny = @as(usize, @intFromFloat(@max(1.0, @ceil(span_y / voxel_size))));
        const nz = @as(usize, @intFromFloat(@max(1.0, @ceil(span_z / voxel_size))));

        var occupied_voxels: usize = 0;

        // Perform VdW radius lookup helper from surfaces to keep constants synchronized.
        // We'll define a local getVdwRadius since we want to avoid import cycle issues if surfaces import pockets.
        const surfaces = @import("../surfaces/surfaces.zig");

        var ix: usize = 0;
        while (ix < nx) : (ix += 1) {
            const x = bbox.min.x + (@as(f64, @floatFromInt(ix)) + 0.5) * voxel_size;
            var iy: usize = 0;
            while (iy < ny) : (iy += 1) {
                const y = bbox.min.y + (@as(f64, @floatFromInt(iy)) + 0.5) * voxel_size;
                var iz: usize = 0;
                while (iz < nz) : (iz += 1) {
                    const z = bbox.min.z + (@as(f64, @floatFromInt(iz)) + 0.5) * voxel_size;
                    const p = Vec3.init(x, y, z);

                    for (self.atoms) |atom| {
                        const r = surfaces.getVdwRadius(atom.element);
                        const d2 = geom.distance2(p, atom.pos);
                        if (d2 <= r * r) {
                            occupied_voxels += 1;
                            break;
                        }
                    }
                }
            }
        }

        const voxel_vol = voxel_size * voxel_size * voxel_size;
        return @as(f64, @floatFromInt(occupied_voxels)) * voxel_vol;
    }
};

test "Pocket basic operations" {
    const atom1 = try Atom.init(10, "CA", .C, Vec3.init(0, 0, 0), 1.0, 10.0, null);
    const atom2 = try Atom.init(11, "CB", .C, Vec3.init(2.0, 0, 0), 1.0, 10.0, null);
    const atoms = [_]Atom{ atom1, atom2 };

    const res = try Residue.init(1, "ALA", &atoms);
    const residues = [_]Residue{res};

    const pocket = Pocket.init(&atoms, &residues, 150.0);

    // Verify statistics and geometry
    try std.testing.expectEqual(pocket.atomCount(), 2);
    try std.testing.expectEqual(pocket.residueCount(), 1);
    try std.testing.expectApproxEqAbs(pocket.centroid.x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(pocket.centroid.y, 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(pocket.centroid.z, 0.0, 1e-5);

    // Bounding box: min x=0, max x=2
    try std.testing.expect(pocket.bounding_box.contains(Vec3.init(0.5, 0, 0)));
    try std.testing.expect(!pocket.bounding_box.contains(Vec3.init(3.0, 0, 0)));

    // Containment checks
    try std.testing.expect(pocket.containsAtom(10));
    try std.testing.expect(pocket.containsAtom(11));
    try std.testing.expect(!pocket.containsAtom(99));
    try std.testing.expect(pocket.containsResidue(1));
    try std.testing.expect(!pocket.containsResidue(99));

    try std.testing.expect(pocket.containsPointDistance(Vec3.init(0, 1.0, 0), 1.1));
    try std.testing.expect(!pocket.containsPointDistance(Vec3.init(0, 5.0, 0), 1.1));

    // Stats
    const stats = pocket.statistics();
    try std.testing.expectEqual(stats.num_atoms, 2);
    try std.testing.expectEqual(stats.num_residues, 1);
    try std.testing.expectApproxEqAbs(stats.volume, 150.0, 1e-5);
    try std.testing.expectApproxEqAbs(stats.span.x, 2.0, 1e-5);

    // Union volume estimate
    // Single carbon atom has VdW radius 1.7. Since they are at (0,0,0) and (2,0,0), their VdW spheres overlap.
    const union_vol = pocket.estimateUnionVolume(0.1);
    try std.testing.expect(union_vol > 0.0);
}
