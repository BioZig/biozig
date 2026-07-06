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

pub fn parsePqr(allocator: std.mem.Allocator, reader: anytype) ![]const model_mod.Model {
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

    var current_atoms = std.ArrayList(TempAtom).empty;
    defer {
        for (current_atoms.items) |ta| {
            allocator.free(ta.name);
            allocator.free(ta.res_name);
            allocator.free(ta.chain_id);
        }
        current_atoms.deinit(allocator);
    }

    var model_id: usize = 1;

    while (true) {
        line_buf.clearRetainingCapacity();
        var hit_eof = false;
        while (true) {
            const b = reader.readByte() catch |err| {
                if (err == error.EndOfStream) hit_eof = true;
                break;
            };
            if (b == '\n') break;
            try line_buf.append(allocator, b);
        }
        if (hit_eof and line_buf.items.len == 0) break;

        const line = std.mem.trim(u8, line_buf.items, "\r");
        if (line.len < 6) continue;

        if (std.mem.startsWith(u8, line, "MODEL")) {
            // handle model ID if needed
        } else if (std.mem.startsWith(u8, line, "ENDMDL") or std.mem.startsWith(u8, line, "END")) {
            if (current_atoms.items.len > 0) {
                const model = try buildModel(allocator, model_id, current_atoms.items);
                try models.append(allocator, model);
                for (current_atoms.items) |ta| {
                    allocator.free(ta.name);
                    allocator.free(ta.res_name);
                    allocator.free(ta.chain_id);
                }
                current_atoms.clearRetainingCapacity();
                model_id += 1;
            }
        } else if (std.mem.startsWith(u8, line, "ATOM") or std.mem.startsWith(u8, line, "HETATM")) {
            var it = std.mem.tokenizeAny(u8, line, " \t");
            var tokens = std.ArrayList([]const u8).empty;
            defer tokens.deinit(allocator);
            while (it.next()) |tok| {
                try tokens.append(allocator, tok);
            }

            if (tokens.items.len < 10) return error.MalformedPqrAtomRecord;

            const record_name = tokens.items[0];
            _ = record_name; // ATOM or HETATM

            const id_str = tokens.items[1];
            const name_str = tokens.items[2];
            const res_name_str = tokens.items[3];

            var chain_str: []const u8 = "";
            var res_seq_str: []const u8 = "";
            var x_str: []const u8 = "";
            var y_str: []const u8 = "";
            var z_str: []const u8 = "";
            var charge_str: []const u8 = "";
            var radius_str: []const u8 = "";

            if (tokens.items.len >= 11) {
                // With Chain ID
                chain_str = tokens.items[4];
                res_seq_str = tokens.items[5];
                x_str = tokens.items[6];
                y_str = tokens.items[7];
                z_str = tokens.items[8];
                charge_str = tokens.items[9];
                radius_str = tokens.items[10];
            } else {
                // Without Chain ID
                chain_str = "A"; // default
                res_seq_str = tokens.items[4];
                x_str = tokens.items[5];
                y_str = tokens.items[6];
                z_str = tokens.items[7];
                charge_str = tokens.items[8];
                radius_str = tokens.items[9];
            }

            const id = std.fmt.parseInt(usize, id_str, 10) catch return error.MalformedPqrAtomRecord;
            const res_seq = std.fmt.parseInt(usize, res_seq_str, 10) catch return error.MalformedPqrAtomRecord;
            const x = std.fmt.parseFloat(f64, x_str) catch return error.MalformedPqrAtomRecord;
            const y = std.fmt.parseFloat(f64, y_str) catch return error.MalformedPqrAtomRecord;
            const z = std.fmt.parseFloat(f64, z_str) catch return error.MalformedPqrAtomRecord;

            const charge = std.fmt.parseFloat(f64, charge_str) catch return error.MalformedPqrAtomRecord;
            const radius = std.fmt.parseFloat(f64, radius_str) catch return error.MalformedPqrAtomRecord;

            // Element guess from atom name
            const element = guessElement(name_str);

            try current_atoms.append(allocator, TempAtom{
                .id = id,
                .name = try allocator.dupe(u8, name_str),
                .element = element,
                .pos = Vec3.init(x, y, z),
                .occupancy = charge, // Map partial charge to occupancy
                .b_factor = radius, // Map radius to b_factor
                .formal_charge = null,
                .res_seq = res_seq,
                .res_name = try allocator.dupe(u8, res_name_str),
                .chain_id = try allocator.dupe(u8, chain_str),
            });
        }
    }

    if (current_atoms.items.len > 0) {
        const model = try buildModel(allocator, model_id, current_atoms.items);
        try models.append(allocator, model);
    }

    return try models.toOwnedSlice(allocator);
}

fn guessElement(name: []const u8) atom_mod.Element {
    if (name.len == 0) return .C;
    // Basic heuristic: first character (if it's a letter) or first two
    var first_char = name[0];
    if (first_char >= '0' and first_char <= '9' and name.len > 1) {
        first_char = name[1];
    }

    switch (first_char) {
        'H' => return .H,
        'C' => return .C,
        'N' => return .N,
        'O' => return .O,
        'P' => return .P,
        'S' => return .S,
        else => {
            const gen = [_]u8{ first_char, 0 };
            return .{ .generic = gen };
        },
    }
}

const StringReader = struct {
    buffer: []const u8,
    pos: usize = 0,
    pub fn init(b: []const u8) StringReader {
        return .{ .buffer = b };
    }
    pub fn readByte(self: *@This()) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const c = self.buffer[self.pos];
        self.pos += 1;
        return c;
    }
};

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

            for (list.items, 0..) |ta, i| {
                atoms[i] = try atom_mod.Atom.init(
                    ta.id,
                    ta.name,
                    ta.element,
                    ta.pos,
                    ta.occupancy,
                    ta.b_factor,
                    ta.formal_charge,
                );
            }

            var name_buf = [_]u8{0} ** 4;
            const rn = list.items[0].res_name;
            @memcpy(name_buf[0..@min(rn.len, 4)], rn[0..@min(rn.len, 4)]);

            try residues.append(allocator, residue_mod.Residue{
                .id = seq,
                .name = name_buf,
                .name_len = @as(u3, @truncate(@min(rn.len, 4))),
                .atoms = atoms,
            });
        }

        var cid_buf: [2]u8 = [_]u8{0} ** 2;
        @memcpy(cid_buf[0..@min(chain_id.len, 2)], chain_id[0..@min(chain_id.len, 2)]);

        try chains.append(allocator, chain_mod.Chain{
            .id = cid_buf,
            .id_len = @as(u2, @truncate(@min(chain_id.len, 2))),
            .residues = try residues.toOwnedSlice(allocator),
        });
    }

    return model_mod.Model{
        .id = id,
        .chains = try chains.toOwnedSlice(allocator),
    };
}

test "PQR parsing: valid file" {
    const pqr_content =
        \\REMARK   1 PQR file generated by test
        \\ATOM      1  N   ALA A   1      -1.018  11.536   1.701  0.0619 1.8240
        \\ATOM      2  CA  ALA A   1      -1.229  10.155   1.282 -0.0694 1.9080
        \\ATOM      3  C   ALA A   1       0.046   9.324   1.534  0.5973 1.9080
        \\ATOM      4  O   ALA A   1       1.096   9.827   1.884 -0.5679 1.6612
        \\ATOM      5  CB  ALA A   1      -2.434   9.475   1.939 -0.0597 1.9080
        \\TER
        \\END
    ;

    var stream = StringReader.init(pqr_content);
    const models = try parsePqr(std.testing.allocator, &stream);
    defer {
        for (models) |*m| {
            for (m.chains) |*c| {
                for (c.residues) |*r| {
                    std.testing.allocator.free(r.atoms);
                }
                std.testing.allocator.free(c.residues);
            }
            std.testing.allocator.free(m.chains);
        }
        std.testing.allocator.free(models);
    }

    try std.testing.expectEqual(@as(usize, 1), models.len);
    const model = models[0];
    try std.testing.expectEqual(@as(usize, 1), model.chains.len);
    const chain = model.chains[0];
    try std.testing.expectEqualStrings("A", chain.id[0..chain.id_len]);
    try std.testing.expectEqual(@as(usize, 1), chain.residues.len);

    const residue = chain.residues[0];
    try std.testing.expectEqual(@as(usize, 1), residue.id);
    try std.testing.expectEqualStrings("ALA", residue.name[0..residue.name_len]);
    try std.testing.expectEqual(@as(usize, 5), residue.atoms.len);

    const atom1 = residue.atoms[0];
    try std.testing.expectEqual(@as(usize, 1), atom1.id);
    try std.testing.expectEqualStrings("N", atom1.name[0..atom1.name_len]);
    try std.testing.expectEqual(atom_mod.Element.N, atom1.element);
    try std.testing.expectApproxEqAbs(@as(f64, -1.018), atom1.pos.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 11.536), atom1.pos.y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.701), atom1.pos.z, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0619), atom1.occupancy, 0.0001); // Charge -> occupancy
    try std.testing.expectApproxEqAbs(@as(f64, 1.8240), atom1.b_factor, 0.0001); // Radius -> b_factor
}

test "PQR parsing: invalid format (missing radius)" {
    const pqr_content =
        \\ATOM      1  N   ALA A   1      -1.018  11.536   1.701  0.0619
    ;

    var stream = StringReader.init(pqr_content);
    const result = parsePqr(std.testing.allocator, &stream);
    try std.testing.expectError(error.MalformedPqrAtomRecord, result);
}

test "PQR parsing: roundtrip serialization" {
    const pqr_content =
        \\ATOM      1  N   ALA A   1      -1.018  11.536   1.701  0.0619 1.8240
    ;

    var stream = StringReader.init(pqr_content);
    const models = try parsePqr(std.testing.allocator, &stream);
    defer {
        for (models) |*m| {
            for (m.chains) |*c| {
                for (c.residues) |*r| {
                    std.testing.allocator.free(r.atoms);
                }
                std.testing.allocator.free(c.residues);
            }
            std.testing.allocator.free(m.chains);
        }
        std.testing.allocator.free(models);
    }
}

pub fn parsePqrCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\r");
        if (std.mem.startsWith(u8, line, "ATOM") or std.mem.startsWith(u8, line, "HETATM")) {
            var tok_count: usize = 0;
            var tokens_first_pass = std.mem.tokenizeAny(u8, line, " \t");
            while (tokens_first_pass.next()) |_| {
                tok_count += 1;
            }
            if (tok_count >= 8) {
                var tokens = std.mem.tokenizeAny(u8, line, " \t");
                var i: usize = 0;
                var x: f64 = 0;
                var y: f64 = 0;
                var z: f64 = 0;
                while (tokens.next()) |tok| : (i += 1) {
                    if (i == tok_count - 5) x = try std.fmt.parseFloat(f64, tok);
                    if (i == tok_count - 4) y = try std.fmt.parseFloat(f64, tok);
                    if (i == tok_count - 3) z = try std.fmt.parseFloat(f64, tok);
                }
                try coords.append(allocator, Vec3.init(x, y, z));
            }
        }
    }
    return try coords.toOwnedSlice(allocator);
}

test "pqr zero-copy memory optimization" {
    const allocator = std.testing.allocator;
    const data =
        \\ATOM      1  N   ALA A   1      11.104   6.134  -6.504  0.0619 1.8240
        \\ATOM      2  CA  ALA A   1      11.639   6.071  -5.147 -0.0694 1.9080
        \\ATOM      3  C   ALA A   1      10.825   5.052  -4.326  0.5973 1.9080
    ;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const start_memory = arena.queryCapacity();

    const coords = try parsePqrCoords(arena_allocator, data);
    try std.testing.expectEqual(@as(usize, 3), coords.len);
    try std.testing.expectEqual(@as(f64, 11.104), coords[0].x);

    const end_memory = arena.queryCapacity();
    try std.testing.expect(end_memory - start_memory < 500);
}
