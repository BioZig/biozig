const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const mmcif = ingestion.structural.mmcif;

const SliceReader = struct {
    buffer: []const u8,
    pos: usize = 0,
    pub fn readByte(self: *@This()) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const b = self.buffer[self.pos];
        self.pos += 1;
        return b;
    }
};

// ─── Happy Path ───────────────────────────────────────────────────────────────

test "mmcif: parse minimal valid atom_site loop" {
    const data =
        "loop_\n" ++
        "_atom_site.group_PDB\n" ++
        "_atom_site.id\n" ++
        "_atom_site.type_symbol\n" ++
        "_atom_site.label_atom_id\n" ++
        "_atom_site.label_comp_id\n" ++
        "_atom_site.label_asym_id\n" ++
        "_atom_site.label_seq_id\n" ++
        "_atom_site.Cartn_x\n" ++
        "_atom_site.Cartn_y\n" ++
        "_atom_site.Cartn_z\n" ++
        "_atom_site.occupancy\n" ++
        "_atom_site.B_iso_or_equiv\n" ++
        "_atom_site.pdbx_formal_charge\n" ++
        "ATOM 1 N N ALA A 1 11.104 6.134 -6.504 1.00 0.00 ?\n";
    var fbs = SliceReader{ .buffer = data };
    const models = try mmcif.parseMmcif(testing.allocator, &fbs);
    defer {
        for (models) |*m| {
            for (m.chains) |*c| {
                for (c.residues) |*r| testing.allocator.free(r.atoms);
                testing.allocator.free(c.residues);
            }
            testing.allocator.free(m.chains);
        }
        testing.allocator.free(models);
    }
    try testing.expectEqual(@as(usize, 1), models.len);
    try testing.expectEqual(@as(usize, 1), models[0].chains.len);
}

test "mmcif: comment and blank lines are skipped" {
    const data =
        "# comment\n\n" ++
        "loop_\n" ++
        "_atom_site.group_PDB\n" ++
        "_atom_site.id\n" ++
        "_atom_site.type_symbol\n" ++
        "_atom_site.label_atom_id\n" ++
        "_atom_site.label_comp_id\n" ++
        "_atom_site.label_asym_id\n" ++
        "_atom_site.label_seq_id\n" ++
        "_atom_site.Cartn_x\n" ++
        "_atom_site.Cartn_y\n" ++
        "_atom_site.Cartn_z\n" ++
        "_atom_site.occupancy\n" ++
        "_atom_site.B_iso_or_equiv\n" ++
        "_atom_site.pdbx_formal_charge\n" ++
        "ATOM 1 C CA ALA A 1 1.0 2.0 3.0 1.00 0.00 ?\n";
    var fbs = SliceReader{ .buffer = data };
    const models = try mmcif.parseMmcif(testing.allocator, &fbs);
    defer {
        for (models) |*m| {
            for (m.chains) |*c| {
                for (c.residues) |*r| testing.allocator.free(r.atoms);
                testing.allocator.free(c.residues);
            }
            testing.allocator.free(m.chains);
        }
        testing.allocator.free(models);
    }
    try testing.expectEqual(@as(usize, 1), models.len);
}

test "mmcif: empty file returns no models" {
    var fbs = SliceReader{ .buffer = "" };
    const models = try mmcif.parseMmcif(testing.allocator, &fbs);
    defer testing.allocator.free(models);
    try testing.expectEqual(@as(usize, 0), models.len);
}

test "mmcif: only comments, no atom_site data -> no models" {
    const data = "# This is a cif file\n_entry.id 1ABC\n";
    var fbs = SliceReader{ .buffer = data };
    const models = try mmcif.parseMmcif(testing.allocator, &fbs);
    defer testing.allocator.free(models);
    try testing.expectEqual(@as(usize, 0), models.len);
}

// ─── parseMmcifCoords (fast buffer path) ─────────────────────────────────────

test "mmcif: parseMmcifCoords extracts x/y/z from full loop" {
    const data =
        "loop_\n" ++
        "_atom_site.group_PDB\n" ++
        "_atom_site.id\n" ++
        "_atom_site.type_symbol\n" ++
        "_atom_site.label_atom_id\n" ++
        "_atom_site.label_comp_id\n" ++
        "_atom_site.label_asym_id\n" ++
        "_atom_site.label_seq_id\n" ++
        "_atom_site.Cartn_x\n" ++
        "_atom_site.Cartn_y\n" ++
        "_atom_site.Cartn_z\n" ++
        "_atom_site.occupancy\n" ++
        "_atom_site.B_iso_or_equiv\n" ++
        "_atom_site.pdbx_formal_charge\n" ++
        "ATOM 1 N N ALA A 1 11.104 6.134 -6.504 1.00 0.00 ?\n" ++
        "ATOM 2 C CA ALA A 1 11.639 6.071 -5.147 1.00 0.00 ?\n";
    const coords = try mmcif.parseMmcifCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 2), coords.len);
    try testing.expectEqual(@as(f64, 11.104), coords[0].x);
    try testing.expectEqual(@as(f64, 6.134), coords[0].y);
    try testing.expectEqual(@as(f64, -6.504), coords[0].z);
}

test "mmcif: parseMmcifCoords on empty buffer returns empty slice" {
    const coords = try mmcif.parseMmcifCoords(testing.allocator, "");
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 0), coords.len);
}

test "mmcif: parseMmcifCoords skips HETATM lines not tagged as atom_site" {
    // In the parseMmcifCoords path, lines must start with ATOM or HETATM
    // but only if we are in atom_site context. Without a proper loop_ context, no coords.
    const data = "HETATM 1 C LIG A 201 10.0 20.0 30.0 1.00 0.00 ?\n";
    const coords = try mmcif.parseMmcifCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 0), coords.len);
}
