const std = @import("std");
const structural = @import("structural");
const atom_mod = structural.atom;
const residue_mod = structural.residue;
const chain_mod = structural.chain;
const model_mod = structural.model;
const geom = structural.geometry;
const Vec3 = geom.Vec3;
const pdb = @import("pdb.zig");

const TempAtom = struct {
    id: usize,
    name: []const u8,
    element: atom_mod.Element,
    pos: Vec3,
    occupancy: f64,
    b_factor: f64,
    formal_charge: ?i8,
    res_seq: usize,
    res_name: []const u8,
    chain_id: []const u8,
};

pub fn parseMmcif(allocator: std.mem.Allocator, reader: anytype) ![]const model_mod.Model {
    var line_buf = std.ArrayList(u8).empty;
    defer line_buf.deinit(allocator);

    var models = std.ArrayList(model_mod.Model).empty;
    errdefer {
        for (models.items) |*m| {
            for (m.chains) |*c| {
                for (c.residues) |*r| {
                    allocator.free(r.atoms);
                }
                allocator.free(c.residues);
            }
            allocator.free(m.chains);
        }
        models.deinit(allocator);
    }

    var temp_atoms = std.ArrayList(TempAtom).empty;
    defer {
        for (temp_atoms.items) |ta| {
            allocator.free(ta.name);
            allocator.free(ta.res_name);
            allocator.free(ta.chain_id);
        }
        temp_atoms.deinit(allocator);
    }

    var in_loop = false;
    var tags = std.ArrayList([]const u8).empty;
    defer {
        for (tags.items) |t| allocator.free(t);
        tags.deinit(allocator);
    }

    var id_idx: ?usize = null;
    var type_symbol_idx: ?usize = null;
    var atom_id_idx: ?usize = null;
    var comp_id_idx: ?usize = null;
    var asym_id_idx: ?usize = null;
    var seq_id_idx: ?usize = null;
    var x_idx: ?usize = null;
    var y_idx: ?usize = null;
    var z_idx: ?usize = null;
    var occ_idx: ?usize = null;
    var b_iso_idx: ?usize = null;
    var charge_idx: ?usize = null;

    main_loop: while (true) {
        line_buf.clearRetainingCapacity();
        while (true) {
            const b = reader.readByte() catch |err| {
                if (err == error.EndOfStream) {
                    if (line_buf.items.len == 0) break :main_loop;
                    break;
                } else {
                    return err;
                }
            };
            if (b == '\n') break;
            try line_buf.append(allocator, b);
        }

        const line = std.mem.trim(u8, line_buf.items, " \r\t");
        if (line.len == 0 or line[0] == '#') continue;

        if (std.mem.eql(u8, line, "loop_")) {
            // Process previous loop or state
            in_loop = true;
            for (tags.items) |t| allocator.free(t);
            tags.clearRetainingCapacity();
            id_idx = null;
            type_symbol_idx = null;
            atom_id_idx = null;
            comp_id_idx = null;
            asym_id_idx = null;
            seq_id_idx = null;
            x_idx = null;
            y_idx = null;
            z_idx = null;
            occ_idx = null;
            b_iso_idx = null;
            charge_idx = null;
            continue;
        }

        if (in_loop) {
            if (line[0] == '_') {
                try tags.append(allocator, try allocator.dupe(u8, line));
                const col_idx = tags.items.len - 1;
                if (std.mem.eql(u8, line, "_atom_site.id")) id_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.type_symbol")) type_symbol_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.label_atom_id")) atom_id_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.label_comp_id")) comp_id_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.label_asym_id")) asym_id_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.label_seq_id")) seq_id_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.Cartn_x")) x_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.Cartn_y")) y_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.Cartn_z")) z_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.occupancy")) occ_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.B_iso_or_equiv")) b_iso_idx = col_idx;
                if (std.mem.eql(u8, line, "_atom_site.pdbx_formal_charge")) charge_idx = col_idx;
            } else {
                // We reached the values section of the loop
                if (id_idx != null and x_idx != null and y_idx != null and z_idx != null) {
                    // Parse values
                    var tokens = std.mem.tokenizeAny(u8, line, " \t");
                    var col_count: usize = 0;
                    var row_vals = std.ArrayList([]const u8).empty;
                    defer row_vals.deinit(allocator);

                    while (tokens.next()) |tok| {
                        try row_vals.append(allocator, tok);
                        col_count += 1;
                    }

                    if (row_vals.items.len >= tags.items.len) {
                        const id_str = row_vals.items[id_idx.?];
                        const x_str = row_vals.items[x_idx.?];
                        const y_str = row_vals.items[y_idx.?];
                        const z_str = row_vals.items[z_idx.?];

                        const id = try std.fmt.parseInt(usize, id_str, 10);
                        const x = try std.fmt.parseFloat(f64, x_str);
                        const y = try std.fmt.parseFloat(f64, y_str);
                        const z = try std.fmt.parseFloat(f64, z_str);

                        const sym = if (type_symbol_idx) |idx| row_vals.items[idx] else "C";
                        const atom_name = if (atom_id_idx) |idx| row_vals.items[idx] else "C";
                        const res_name = if (comp_id_idx) |idx| row_vals.items[idx] else "UNK";
                        const chain_name = if (asym_id_idx) |idx| row_vals.items[idx] else "A";
                        const seq_str = if (seq_id_idx) |idx| row_vals.items[idx] else "1";
                        const res_seq = std.fmt.parseInt(usize, seq_str, 10) catch 1;

                        var occupancy: f64 = 1.0;
                        if (occ_idx) |idx| {
                            occupancy = std.fmt.parseFloat(f64, row_vals.items[idx]) catch 1.0;
                        }

                        var b_factor: f64 = 0.0;
                        if (b_iso_idx) |idx| {
                            b_factor = std.fmt.parseFloat(f64, row_vals.items[idx]) catch 0.0;
                        }

                        var formal_charge: ?i8 = null;
                        if (charge_idx) |idx| {
                            const c_str = row_vals.items[idx];
                            if (!std.mem.eql(u8, c_str, "?") and !std.mem.eql(u8, c_str, ".")) {
                                formal_charge = std.fmt.parseInt(i8, c_str, 10) catch null;
                            }
                        }

                        try temp_atoms.append(allocator, .{
                            .id = id,
                            .name = try allocator.dupe(u8, atom_name),
                            .element = parseElement(sym),
                            .pos = Vec3.init(x, y, z),
                            .occupancy = occupancy,
                            .b_factor = b_factor,
                            .formal_charge = formal_charge,
                            .res_seq = res_seq,
                            .res_name = try allocator.dupe(u8, res_name),
                            .chain_id = try allocator.dupe(u8, chain_name),
                        });
                    }
                }
            }
        }
    }

    if (temp_atoms.items.len > 0) {
        // Group all into model 1 (or we can implement model support if loop_ has model id)
        const model = try buildModel(allocator, 1, temp_atoms.items);
        try models.append(allocator, model);
    }

    return try models.toOwnedSlice(allocator);
}

fn parseElement(sym: []const u8) atom_mod.Element {
    if (sym.len == 0) return .C;
    if (std.mem.eql(u8, sym, "H")) return .H;
    if (std.mem.eql(u8, sym, "C")) return .C;
    if (std.mem.eql(u8, sym, "N")) return .N;
    if (std.mem.eql(u8, sym, "O")) return .O;
    if (std.mem.eql(u8, sym, "P")) return .P;
    if (std.mem.eql(u8, sym, "S")) return .S;
    var gen = [_]u8{0} ** 2;
    @memcpy(gen[0..@min(sym.len, 2)], sym[0..@min(sym.len, 2)]);
    return .{ .generic = gen };
}

fn buildModel(allocator: std.mem.Allocator, id: usize, temp_atoms: []const TempAtom) !model_mod.Model {
    // 1. Group residues by chain_id + res_seq
    var chains_map = std.StringHashMap(std.ArrayList(TempAtom)).init(allocator);
    defer {
        var iter = chains_map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        chains_map.deinit();
    }

    for (temp_atoms) |ta| {
        var res = try chains_map.getOrPut(ta.chain_id);
        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(TempAtom).empty;
        }
        try res.value_ptr.append(allocator, ta);
    }

    var chains = std.ArrayList(chain_mod.Chain).empty;
    errdefer {
        for (chains.items) |*c| {
            for (c.residues) |*r| {
                allocator.free(r.atoms);
            }
            allocator.free(c.residues);
        }
        chains.deinit(allocator);
    }

    var chain_iter = chains_map.iterator();
    while (chain_iter.next()) |chain_entry| {
        const chain_id = chain_entry.key_ptr.*;
        const atoms_in_chain = chain_entry.value_ptr.items;

        var res_map = std.AutoHashMap(usize, std.ArrayList(TempAtom)).init(allocator);
        defer {
            var iter = res_map.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit(allocator);
            }
            res_map.deinit();
        }

        var res_seqs = std.ArrayList(usize).empty;
        defer res_seqs.deinit(allocator);

        for (atoms_in_chain) |ta| {
            var res = try res_map.getOrPut(ta.res_seq);
            if (!res.found_existing) {
                res.value_ptr.* = std.ArrayList(TempAtom).empty;
                try res_seqs.append(allocator, ta.res_seq);
            }
            try res.value_ptr.append(allocator, ta);
        }

        var residues = std.ArrayList(residue_mod.Residue).empty;
        errdefer {
            for (residues.items) |*r| {
                allocator.free(r.atoms);
            }
            residues.deinit(allocator);
        }

        for (res_seqs.items) |seq| {
            const list = res_map.get(seq).?;
            var atoms = try allocator.alloc(atom_mod.Atom, list.items.len);
            errdefer allocator.free(atoms);

            const res_name = list.items[0].res_name;

            for (list.items, 0..) |ta, a_idx| {
                atoms[a_idx] = try atom_mod.Atom.init(
                    ta.id,
                    ta.name,
                    ta.element,
                    ta.pos,
                    ta.occupancy,
                    ta.b_factor,
                    ta.formal_charge,
                );
            }

            const res = try residue_mod.Residue.init(seq, res_name, atoms);
            try residues.append(allocator, res);
        }

        const ch = try chain_mod.Chain.init(chain_id, try residues.toOwnedSlice(allocator));
        try chains.append(allocator, ch);
    }

    return model_mod.Model.init(id, try chains.toOwnedSlice(allocator));
}

/// Serializes models to mmCIF loop format
pub fn serializeMmcif(writer: anytype, models: []const model_mod.Model) !void {
    try writer.writeAll(
        \\loop_
        \\_atom_site.id
        \\_atom_site.type_symbol
        \\_atom_site.label_atom_id
        \\_atom_site.label_comp_id
        \\_atom_site.label_asym_id
        \\_atom_site.label_seq_id
        \\_atom_site.Cartn_x
        \\_atom_site.Cartn_y
        \\_atom_site.Cartn_z
        \\_atom_site.occupancy
        \\_atom_site.B_iso_or_equiv
        \\_atom_site.pdbx_formal_charge
        \\
    );

    for (models) |m| {
        for (m.chains) |c| {
            for (c.residues) |res| {
                for (res.atoms) |atom| {
                    var el_buf = [_]u8{0} ** 2;
                    const el_str = atom.element.toString(&el_buf);

                    try writer.print(
                        "{} {s} {s} {s} {s} {} {d:.3} {d:.3} {d:.3} {d:.2} {d:.2} {}\n",
                        .{
                            atom.id,
                            el_str,
                            atom.name[0..atom.name_len],
                            res.getName(),
                            c.getId(),
                            res.id,
                            atom.pos.x,
                            atom.pos.y,
                            atom.pos.z,
                            atom.occupancy,
                            atom.b_factor,
                            atom.formal_charge orelse 0,
                        },
                    );
                }
            }
        }
    }
}

pub fn parseMmcifCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\n');
    var in_atom_site = false;
    var x_idx: ?usize = null;
    var y_idx: ?usize = null;
    var z_idx: ?usize = null;
    var col_idx: usize = 0;

    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\r");
        if (std.mem.startsWith(u8, line, "loop_")) {
            in_atom_site = false;
        } else if (std.mem.startsWith(u8, line, "_atom_site.")) {
            in_atom_site = true;
            if (std.mem.eql(u8, line, "_atom_site.Cartn_x")) x_idx = col_idx;
            if (std.mem.eql(u8, line, "_atom_site.Cartn_y")) y_idx = col_idx;
            if (std.mem.eql(u8, line, "_atom_site.Cartn_z")) z_idx = col_idx;
            col_idx += 1;
        } else if (in_atom_site and (std.mem.startsWith(u8, line, "ATOM") or std.mem.startsWith(u8, line, "HETATM"))) {
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            var i: usize = 0;
            var x: f64 = 0;
            var y: f64 = 0;
            var z: f64 = 0;
            while (tokens.next()) |token| : (i += 1) {
                if (x_idx != null and i == x_idx.?) x = try std.fmt.parseFloat(f64, token);
                if (y_idx != null and i == y_idx.?) y = try std.fmt.parseFloat(f64, token);
                if (z_idx != null and i == z_idx.?) z = try std.fmt.parseFloat(f64, token);
            }
            try coords.append(allocator, Vec3.init(x, y, z));
        }
    }
    return try coords.toOwnedSlice(allocator);
}

test "mmcif zero-copy memory optimization" {
    const allocator = std.testing.allocator;
    const data =
        \\loop_
        \\_atom_site.group_PDB
        \\_atom_site.id
        \\_atom_site.type_symbol
        \\_atom_site.label_atom_id
        \\_atom_site.label_comp_id
        \\_atom_site.label_asym_id
        \\_atom_site.label_seq_id
        \\_atom_site.Cartn_x
        \\_atom_site.Cartn_y
        \\_atom_site.Cartn_z
        \\_atom_site.occupancy
        \\_atom_site.B_iso_or_equiv
        \\_atom_site.pdbx_formal_charge
        \\ATOM 1 N N ALA A 1 11.104 6.134 -6.504 1.00 0.00 ?
        \\ATOM 2 C CA ALA A 1 11.639 6.071 -5.147 1.00 0.00 ?
        \\ATOM 3 C C ALA A 1 10.825 5.052 -4.326 1.00 0.00 ?
    ;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const start_memory = arena.queryCapacity();

    const coords = try parseMmcifCoords(arena_allocator, data);
    try std.testing.expectEqual(@as(usize, 3), coords.len);
    try std.testing.expectEqual(@as(f64, 11.104), coords[0].x);

    const end_memory = arena.queryCapacity();
    try std.testing.expect(end_memory - start_memory < 500);
}
