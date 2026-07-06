const std = @import("std");
const residue_mod = @import("../residue/residue.zig");
const geom = @import("../geometry/geometry.zig");
const Residue = residue_mod.Residue;
const Vec3 = geom.Vec3;

pub const ChainType = enum {
    protein,
    nucleic,
    mixed,
};

pub const Chain = struct {
    residues: []const Residue,
    id: [2]u8,
    id_len: u8,

    pub fn init(id: []const u8, residues: []const Residue) !Chain {
        if (id.len > 2) return error.ChainIdTooLong;
        var id_buf = [_]u8{0} ** 2;
        @memcpy(id_buf[0..id.len], id);
        return Chain{
            .id = id_buf,
            .id_len = @as(u8, @intCast(id.len)),
            .residues = residues,
        };
    }

    pub fn getId(self: *const Chain) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn lookupResidue(self: *const Chain, id: usize) ?*const Residue {
        for (self.residues, 0..) |_, i| {
            if (self.residues[i].id == id) return &self.residues[i];
        }
        return null;
    }

    pub fn len(self: *const Chain) usize {
        return self.residues.len;
    }

    pub fn centroid(self: *const Chain) Vec3 {
        var sum = Vec3.init(0, 0, 0);
        var count: usize = 0;
        for (self.residues) |res| {
            for (res.atoms) |atom| {
                sum = sum.add(atom.pos);
                count += 1;
            }
        }
        if (count == 0) return sum;
        return sum.scale(1.0 / @as(f64, @floatFromInt(count)));
    }

    pub fn reconstructSequence(self: *const Chain, allocator: std.mem.Allocator) ![]const u8 {
        const seq = try allocator.alloc(u8, self.residues.len);
        errdefer allocator.free(seq);
        for (self.residues, 0..) |res, i| {
            seq[i] = resChar(res.getName());
        }
        return seq;
    }

    pub fn determineType(self: *const Chain) ChainType {
        var has_protein = false;
        var has_nucleic = false;
        for (self.residues) |res| {
            const name = res.getName();
            if (isProteinResidue(name)) {
                has_protein = true;
            } else if (isNucleicResidue(name)) {
                has_nucleic = true;
            }
        }
        if (has_protein and has_nucleic) return .mixed;
        if (has_protein) return .protein;
        if (has_nucleic) return .nucleic;
        return .mixed;
    }

    fn resChar(name: []const u8) u8 {
        if (std.mem.eql(u8, name, "ALA")) return 'A';
        if (std.mem.eql(u8, name, "CYS")) return 'C';
        if (std.mem.eql(u8, name, "ASP")) return 'D';
        if (std.mem.eql(u8, name, "GLU")) return 'E';
        if (std.mem.eql(u8, name, "PHE")) return 'F';
        if (std.mem.eql(u8, name, "GLY")) return 'G';
        if (std.mem.eql(u8, name, "HIS")) return 'H';
        if (std.mem.eql(u8, name, "ILE")) return 'I';
        if (std.mem.eql(u8, name, "LYS")) return 'K';
        if (std.mem.eql(u8, name, "LEU")) return 'L';
        if (std.mem.eql(u8, name, "MET")) return 'M';
        if (std.mem.eql(u8, name, "ASN")) return 'N';
        if (std.mem.eql(u8, name, "PRO")) return 'P';
        if (std.mem.eql(u8, name, "GLN")) return 'Q';
        if (std.mem.eql(u8, name, "ARG")) return 'R';
        if (std.mem.eql(u8, name, "SER")) return 'S';
        if (std.mem.eql(u8, name, "THR")) return 'T';
        if (std.mem.eql(u8, name, "VAL")) return 'V';
        if (std.mem.eql(u8, name, "TRP")) return 'W';
        if (std.mem.eql(u8, name, "TYR")) return 'Y';

        // Nucleotides
        if (std.mem.eql(u8, name, "A") or std.mem.eql(u8, name, "DA")) return 'A';
        if (std.mem.eql(u8, name, "C") or std.mem.eql(u8, name, "DC")) return 'C';
        if (std.mem.eql(u8, name, "G") or std.mem.eql(u8, name, "DG")) return 'G';
        if (std.mem.eql(u8, name, "U") or std.mem.eql(u8, name, "DT") or std.mem.eql(u8, name, "T")) return 'T';

        return 'X';
    }

    fn isProteinResidue(name: []const u8) bool {
        const canonical = [_][]const u8{
            "ALA", "CYS", "ASP", "GLU", "PHE", "GLY", "HIS", "ILE", "LYS", "LEU",
            "MET", "ASN", "PRO", "GLN", "ARG", "SER", "THR", "VAL", "TRP", "TYR",
        };
        for (canonical) |c| {
            if (std.mem.eql(u8, name, c)) return true;
        }
        return false;
    }

    fn isNucleicResidue(name: []const u8) bool {
        const canonical = [_][]const u8{
            "A", "C", "G", "U", "T", "DA", "DC", "DG", "DT", "DU",
        };
        for (canonical) |c| {
            if (std.mem.eql(u8, name, c)) return true;
        }
        return false;
    }
};
