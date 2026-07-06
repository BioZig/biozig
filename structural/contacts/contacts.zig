const std = @import("std");
const atom_mod = @import("../atom/atom.zig");
const residue_mod = @import("../residue/residue.zig");
const geom = @import("../geometry/geometry.zig");
const Atom = atom_mod.Atom;
const Residue = residue_mod.Residue;
const Vec3 = geom.Vec3;

pub const Contact = struct {
    index_a: usize,
    index_b: usize,
    distance: f64,
};

pub const ResidueContact = struct {
    residue_a_id: usize,
    residue_b_id: usize,
    min_distance: f64,
};

const CellKey = struct {
    ix: i32,
    iy: i32,
    iz: i32,
};

/// Efficient spatial hashing contact search for atoms.
/// Time complexity: expected O(N).
pub fn searchAtomContacts(atoms: []const Atom, threshold: f64, allocator: std.mem.Allocator) ![]const Contact {
    if (threshold <= 0.0) return &[_]Contact{};

    var grid = std.AutoHashMap(CellKey, std.ArrayList(usize)).init(allocator);
    defer {
        var iter = grid.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        grid.deinit();
    }

    // 1. Populate the spatial grid
    for (atoms, 0..) |atom, i| {
        const key = CellKey{
            .ix = @intFromFloat(@floor(atom.pos.x / threshold)),
            .iy = @intFromFloat(@floor(atom.pos.y / threshold)),
            .iz = @intFromFloat(@floor(atom.pos.z / threshold)),
        };
        var res = try grid.getOrPut(key);
        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(usize).empty;
        }
        try res.value_ptr.append(allocator, i);
    }

    var contacts = std.ArrayList(Contact).empty;
    errdefer contacts.deinit(allocator);

    // 2. Query neighbors (using half-neighbor stencil to prevent double-counting)
    var iter = grid.iterator();
    while (iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const cell_atoms = entry.value_ptr.items;

        var dx: i32 = -1;
        while (dx <= 1) : (dx += 1) {
            var dy: i32 = -1;
            while (dy <= 1) : (dy += 1) {
                var dz: i32 = -1;
                while (dz <= 1) : (dz += 1) {
                    // Half-stencil condition: check lexicographically greater/equal cells only
                    const is_canonical = (dx > 0) or
                        (dx == 0 and dy > 0) or
                        (dx == 0 and dy == 0 and dz > 0) or
                        (dx == 0 and dy == 0 and dz == 0);

                    if (!is_canonical) continue;

                    const neigh_key = CellKey{
                        .ix = key.ix + dx,
                        .iy = key.iy + dy,
                        .iz = key.iz + dz,
                    };

                    if (grid.get(neigh_key)) |neigh_atoms| {
                        const is_self = (dx == 0 and dy == 0 and dz == 0);
                        for (cell_atoms) |i| {
                            for (neigh_atoms.items) |j| {
                                if (is_self) {
                                    if (i < j) {
                                        const dist = atoms[i].distance(atoms[j]);
                                        if (dist <= threshold) {
                                            try contacts.append(allocator, .{
                                                .index_a = i,
                                                .index_b = j,
                                                .distance = dist,
                                            });
                                        }
                                    }
                                } else {
                                    // Neighbor cell: check all pairs
                                    const dist = atoms[i].distance(atoms[j]);
                                    if (dist <= threshold) {
                                        try contacts.append(allocator, .{
                                            .index_a = @min(i, j),
                                            .index_b = @max(i, j),
                                            .distance = dist,
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return contacts.toOwnedSlice(allocator);
}

const ResiduePair = struct {
    r1: usize,
    r2: usize,
};

/// Efficient spatial hashing contact search for residues.
/// Two residues are in contact if the minimum distance between any of their atoms is <= threshold.
pub fn searchResidueContacts(residues: []const Residue, threshold: f64, allocator: std.mem.Allocator) ![]const ResidueContact {
    if (threshold <= 0.0) return &[_]ResidueContact{};

    // 1. Flatten all atoms and map them to their parent residue index
    var flat_atoms = std.ArrayList(Atom).empty;
    defer flat_atoms.deinit(allocator);
    var atom_res_indices = std.ArrayList(usize).empty;
    defer atom_res_indices.deinit(allocator);

    for (residues, 0..) |res, r_idx| {
        for (res.atoms) |atom| {
            try flat_atoms.append(allocator, atom);
            try atom_res_indices.append(allocator, r_idx);
        }
    }

    // 2. Perform fast atom contact search
    const atom_contacts = try searchAtomContacts(flat_atoms.items, threshold, allocator);
    defer allocator.free(atom_contacts);

    // 3. Map atom contacts to residue pairs and keep minimum distance
    var res_pairs_map = std.AutoHashMap(ResiduePair, f64).init(allocator);
    defer res_pairs_map.deinit();

    for (atom_contacts) |c| {
        const r_a = atom_res_indices.items[c.index_a];
        const r_b = atom_res_indices.items[c.index_b];

        if (r_a == r_b) continue; // Skip same-residue atom contacts

        const pair = ResiduePair{
            .r1 = @min(r_a, r_b),
            .r2 = @max(r_a, r_b),
        };

        const existing_dist = res_pairs_map.get(pair) orelse std.math.inf(f64);
        if (c.distance < existing_dist) {
            try res_pairs_map.put(pair, c.distance);
        }
    }

    // 4. Collect results
    var res_contacts = std.ArrayList(ResidueContact).empty;
    errdefer res_contacts.deinit(allocator);

    var entry_iter = res_pairs_map.iterator();
    while (entry_iter.next()) |entry| {
        const pair = entry.key_ptr.*;
        const dist = entry.value_ptr.*;
        try res_contacts.append(allocator, .{
            .residue_a_id = residues[pair.r1].id,
            .residue_b_id = residues[pair.r2].id,
            .min_distance = dist,
        });
    }

    return res_contacts.toOwnedSlice(allocator);
}
