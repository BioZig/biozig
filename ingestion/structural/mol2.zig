const std = @import("std");
const structural = @import("structural");
const atom_mod = structural.atom;
const residue_mod = structural.residue;
const chain_mod = structural.chain;
const model_mod = structural.model;
const geom = structural.geometry;
const Vec3 = geom.Vec3;

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

pub fn parseMol2(allocator: std.mem.Allocator, reader: anytype) ![]const model_mod.Model {
    var line_buf = std.ArrayList(u8).empty;
    defer line_buf.deinit(allocator);

    var temp_atoms = std.ArrayList(TempAtom).empty;
    defer {
        for (temp_atoms.items) |ta| {
            allocator.free(ta.name);
            allocator.free(ta.res_name);
            allocator.free(ta.chain_id);
        }
        temp_atoms.deinit(allocator);
    }

    var in_atom_block = false;

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
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "@<TRIPOS>")) {
            if (std.mem.eql(u8, line, "@<TRIPOS>ATOM")) {
                in_atom_block = true;
            } else {
                in_atom_block = false;
            }
            continue;
        }

        if (in_atom_block) {
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            const id_str = tokens.next() orelse return error.MalformedMol2Atom;
            const name_str = tokens.next() orelse return error.MalformedMol2Atom;
            const x_str = tokens.next() orelse return error.MalformedMol2Atom;
            const y_str = tokens.next() orelse return error.MalformedMol2Atom;
            const z_str = tokens.next() orelse return error.MalformedMol2Atom;
            const type_str = tokens.next() orelse return error.MalformedMol2Atom;
            
            const subst_id_str = tokens.next();
            const subst_name = tokens.next() orelse "SUB";
            const charge_str = tokens.next();

            const id = try std.fmt.parseInt(usize, id_str, 10);
            const x = try std.fmt.parseFloat(f64, x_str);
            const y = try std.fmt.parseFloat(f64, y_str);
            const z = try std.fmt.parseFloat(f64, z_str);

            const res_seq = if (subst_id_str) |s_id| std.fmt.parseInt(usize, s_id, 10) catch 1 else 1;

            var formal_charge: ?i8 = null;
            if (charge_str) |c_str| {
                const charge_val = std.fmt.parseFloat(f64, c_str) catch 0.0;
                formal_charge = @as(i8, @intFromFloat(charge_val));
            }

            // Element is prefix of type_str before dot '.'
            var element_name = type_str;
            if (std.mem.indexOfScalar(u8, type_str, '.')) |dot_idx| {
                element_name = type_str[0..dot_idx];
            }

            try temp_atoms.append(allocator, .{
                .id = id,
                .name = try allocator.dupe(u8, name_str),
                .element = parseElement(element_name),
                .pos = Vec3.init(x, y, z),
                .occupancy = 1.0,
                .b_factor = 0.0,
                .formal_charge = formal_charge,
                .res_seq = res_seq,
                .res_name = try allocator.dupe(u8, subst_name),
                .chain_id = try allocator.dupe(u8, "A"),
            });
        }
    }

    if (temp_atoms.items.len == 0) return error.Mol2NoAtoms;

    const model = try buildModel(allocator, 1, temp_atoms.items);
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
    try models.append(allocator, model);

    for (temp_atoms.items) |ta| {
        allocator.free(ta.name);
        allocator.free(ta.res_name);
        allocator.free(ta.chain_id);
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

/// Serializes models to MOL2 ATOM format
pub fn serializeMol2(writer: anytype, models: []const model_mod.Model) !void {
    try writer.writeAll("@<TRIPOS>MOLECULE\nBioZigMolecules\n");
    
    // Count total atoms
    var total_atoms: usize = 0;
    for (models) |m| {
        total_atoms += m.atomCount();
    }

    try writer.print("{} 0 0 0 0\nSMALL\nNO_CHARGES\n\n@<TRIPOS>ATOM\n", .{total_atoms});

    for (models) |m| {
        for (m.chains) |c| {
            for (c.residues) |res| {
                for (res.atoms) |atom| {
                    var el_buf = [_]u8{0} ** 2;
                    const el_str = atom.element.toString(&el_buf);

                    try writer.print(
                        "{} {s} {d:.4} {d:.4} {d:.4} {s}.3 {} {s} {d:.4}\n",
                        .{
                            atom.id,
                            atom.name[0..atom.name_len],
                            atom.pos.x,
                            atom.pos.y,
                            atom.pos.z,
                            el_str,
                            res.id,
                            res.getName(),
                            @as(f64, @floatFromInt(atom.formal_charge orelse 0)),
                        },
                    );
                }
            }
        }
    }
}

pub fn parseMol2Coords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\n');
    var in_atoms = false;
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \r");
        if (std.mem.startsWith(u8, line, "@<TRIPOS>ATOM")) {
            in_atoms = true;
            continue;
        } else if (std.mem.startsWith(u8, line, "@<TRIPOS>")) {
            in_atoms = false;
            continue;
        }

        if (in_atoms) {
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            _ = tokens.next(); // atom_id
            _ = tokens.next(); // atom_name
            const x_str = tokens.next() orelse continue;
            const y_str = tokens.next() orelse continue;
            const z_str = tokens.next() orelse continue;

            const x = try std.fmt.parseFloat(f64, x_str);
            const y = try std.fmt.parseFloat(f64, y_str);
            const z = try std.fmt.parseFloat(f64, z_str);
            try coords.append(allocator, Vec3.init(x, y, z));
        }
    }
    return try coords.toOwnedSlice(allocator);
}

test "mol2 zero-copy memory optimization" {
    const allocator = std.testing.allocator;
    const data = 
        \\@<TRIPOS>ATOM
        \\1 N 11.104 6.134 -6.504 N.am 1 ALA 0.0000
        \\2 CA 11.639 6.071 -5.147 C.3 1 ALA 0.0000
        \\3 C 10.825 5.052 -4.326 C.2 1 ALA 0.0000
        ;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const start_memory = arena.queryCapacity();
    
    const coords = try parseMol2Coords(arena_allocator, data);
    try std.testing.expectEqual(@as(usize, 3), coords.len);
    try std.testing.expectEqual(@as(f64, 11.104), coords[0].x);
    
    const end_memory = arena.queryCapacity();
    try std.testing.expect(end_memory - start_memory < 500);
}
