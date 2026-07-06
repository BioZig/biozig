const std = @import("std");
const atom_mod = @import("../atom/atom.zig");
const geom = @import("../geometry/geometry.zig");
const Atom = atom_mod.Atom;
const Vec3 = geom.Vec3;
const BoundingBox = geom.BoundingBox;

pub fn getAtomicMass(el: atom_mod.Element) f64 {
    return switch (el) {
        .H => 1.008,
        .C => 12.011,
        .N => 14.007,
        .O => 15.999,
        .P => 30.974,
        .S => 32.06,
        .generic => |bytes| {
            if (std.mem.eql(u8, &bytes, "FE") or std.mem.eql(u8, &bytes, "Fe")) return 55.845;
            if (std.mem.eql(u8, &bytes, "MG") or std.mem.eql(u8, &bytes, "Mg")) return 24.305;
            if (std.mem.eql(u8, &bytes, "NA") or std.mem.eql(u8, &bytes, "Na")) return 22.990;
            if (std.mem.eql(u8, &bytes, "CL") or std.mem.eql(u8, &bytes, "Cl")) return 35.45;
            if (std.mem.eql(u8, &bytes, "CA") or std.mem.eql(u8, &bytes, "Ca")) return 40.078;
            if (std.mem.eql(u8, &bytes, "ZN") or std.mem.eql(u8, &bytes, "Zn")) return 65.38;
            return 12.011; // Fallback to Carbon-like average mass
        },
    };
}

pub const Residue = struct {
    id: usize,
    atoms: []const Atom,
    name: [4]u8,
    name_len: u8,

    pub fn init(id: usize, name: []const u8, atoms: []const Atom) !Residue {
        if (name.len > 4) return error.ResidueNameTooLong;
        var name_buf = [_]u8{0} ** 4;
        @memcpy(name_buf[0..name.len], name);
        return Residue{
            .id = id,
            .name = name_buf,
            .name_len = @as(u8, @intCast(name.len)),
            .atoms = atoms,
        };
    }

    pub fn getName(self: *const Residue) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn lookupAtom(self: *const Residue, name: []const u8) ?*const Atom {
        for (self.atoms, 0..) |_, i| {
            if (std.mem.eql(u8, self.atoms[i].getName(), name)) return &self.atoms[i];
        }
        return null;
    }

    pub fn centroid(self: *const Residue) Vec3 {
        var sum = Vec3.init(0, 0, 0);
        if (self.atoms.len == 0) return sum;
        for (self.atoms) |atom| {
            sum = sum.add(atom.pos);
        }
        return sum.scale(1.0 / @as(f64, @floatFromInt(self.atoms.len)));
    }

    pub fn mass(self: *const Residue) f64 {
        var total: f64 = 0.0;
        for (self.atoms) |atom| {
            total += getAtomicMass(atom.element);
        }
        return total;
    }

    pub fn boundingBox(self: *const Residue) BoundingBox {
        if (self.atoms.len == 0) {
            return .{ .min = Vec3.init(0, 0, 0), .max = Vec3.init(0, 0, 0) };
        }
        var min = self.atoms[0].pos;
        var max = self.atoms[0].pos;
        for (self.atoms[1..]) |atom| {
            min.x = @min(min.x, atom.pos.x);
            min.y = @min(min.y, atom.pos.y);
            min.z = @min(min.z, atom.pos.z);
            max.x = @max(max.x, atom.pos.x);
            max.y = @max(max.y, atom.pos.y);
            max.z = @max(max.z, atom.pos.z);
        }
        return .{ .min = min, .max = max };
    }

    pub fn validate(self: *const Residue) bool {
        if (self.atoms.len == 0) return false;
        if (self.name_len == 0) return false;
        return true;
    }
};
