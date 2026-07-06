const std = @import("std");
const model_mod = @import("../model/model.zig");
const geom = @import("../geometry/geometry.zig");
const atom_mod = @import("../atom/atom.zig");
const Model = model_mod.Model;
const Vec3 = geom.Vec3;
const BoundingBox = geom.BoundingBox;

pub const AssemblyTransform = struct {
    rotation: [3][3]f64,
    translation: Vec3,
};

pub const Assembly = struct {
    models: []const Model,
    transforms: []const AssemblyTransform,

    pub fn init(models: []const Model, transforms: []const AssemblyTransform) Assembly {
        return .{
            .models = models,
            .transforms = transforms,
        };
    }

    pub fn applyTransform(pos: Vec3, t: AssemblyTransform) Vec3 {
        const r = t.rotation;
        const tr = t.translation;
        return Vec3.init(
            r[0][0] * pos.x + r[0][1] * pos.y + r[0][2] * pos.z + tr.x,
            r[1][0] * pos.x + r[1][1] * pos.y + r[1][2] * pos.z + tr.y,
            r[2][0] * pos.x + r[2][1] * pos.y + r[2][2] * pos.z + tr.z,
        );
    }

    /// Traverses all atoms in the assembly, applying all transforms, and calling the callback for each.
    /// This is completely zero-copy and requires no memory allocations.
    pub fn traverseAtoms(
        self: Assembly,
        context: anytype,
        comptime callback: *const fn (ctx: @TypeOf(context), atom_id: usize, element: atom_mod.Element, pos: Vec3) void,
    ) void {
        for (self.models) |model| {
            for (model.chains) |chain| {
                for (chain.residues) |res| {
                    for (res.atoms) |atom| {
                        for (self.transforms) |t| {
                            const trans_pos = applyTransform(atom.pos, t);
                            callback(context, atom.id, atom.element, trans_pos);
                        }
                    }
                }
            }
        }
    }

    pub fn boundingBox(self: Assembly) BoundingBox {
        var min_x: ?f64 = null;
        var min_y: ?f64 = null;
        var min_z: ?f64 = null;
        var max_x: ?f64 = null;
        var max_y: ?f64 = null;
        var max_z: ?f64 = null;

        for (self.models) |model| {
            for (model.chains) |chain| {
                for (chain.residues) |res| {
                    for (res.atoms) |atom| {
                        for (self.transforms) |t| {
                            const p = applyTransform(atom.pos, t);
                            if (min_x == null) {
                                min_x = p.x;
                                min_y = p.y;
                                min_z = p.z;
                                max_x = p.x;
                                max_y = p.y;
                                max_z = p.z;
                            } else {
                                min_x = @min(min_x.?, p.x);
                                min_y = @min(min_y.?, p.y);
                                min_z = @min(min_z.?, p.z);
                                max_x = @max(max_x.?, p.x);
                                max_y = @max(max_y.?, p.y);
                                max_z = @max(max_z.?, p.z);
                            }
                        }
                    }
                }
            }
        }

        if (min_x == null) {
            return .{ .min = Vec3.init(0, 0, 0), .max = Vec3.init(0, 0, 0) };
        }
        return .{
            .min = Vec3.init(min_x.?, min_y.?, min_z.?),
            .max = Vec3.init(max_x.?, max_y.?, max_z.?),
        };
    }
};
