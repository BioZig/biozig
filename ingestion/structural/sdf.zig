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

/// Streaming SDF parser. Can yield multiple Models (one for each molecule block in the SDF).
pub fn SdfIterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        allocator: std.mem.Allocator,
        line_buf: std.ArrayList(u8),
        eof: bool = false,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, reader: ReaderType) Self {
            return .{
                .reader = reader,
                .allocator = allocator,
                .line_buf = std.ArrayList(u8).empty,
            };
        }

    pub fn deinit(self: *Self) void {
        self.line_buf.deinit(self.allocator);
    }

    pub fn next(self: *Self) !?model_mod.Model {
        if (self.eof) return null;

        var temp_atoms = std.ArrayList(TempAtom).empty;
        defer {
            for (temp_atoms.items) |ta| {
                self.allocator.free(ta.name);
                self.allocator.free(ta.res_name);
                self.allocator.free(ta.chain_id);
            }
            temp_atoms.deinit(self.allocator);
        }

        // Header: 3 lines
        var line1 = std.ArrayList(u8).empty;
        defer line1.deinit(self.allocator);
        var line2 = std.ArrayList(u8).empty;
        defer line2.deinit(self.allocator);
        var line3 = std.ArrayList(u8).empty;
        defer line3.deinit(self.allocator);

        while (true) {
            const b = self.reader.readByte() catch |err| {
                if (err == error.EndOfStream) {
                    self.eof = true;
                    return null;
                }
                return err;
            };
            if (b == '\n') break;
            try line1.append(self.allocator, b);
        }
        while (true) {
            const b = self.reader.readByte() catch |err| {
                if (err == error.EndOfStream) return error.MalformedSdfTruncatedHeader;
                return err;
            };
            if (b == '\n') break;
            try line2.append(self.allocator, b);
        }
        while (true) {
            const b = self.reader.readByte() catch |err| {
                if (err == error.EndOfStream) return error.MalformedSdfTruncatedHeader;
                return err;
            };
            if (b == '\n') break;
            try line3.append(self.allocator, b);
        }

        // 4th line: Counts line (first 3 chars for num_atoms, next 3 for num_bonds)
        self.line_buf.clearRetainingCapacity();
        while (true) {
            const b = self.reader.readByte() catch |err| {
                if (err == error.EndOfStream) return error.MalformedSdfTruncatedCounts;
                return err;
            };
            if (b == '\n') break;
            try self.line_buf.append(self.allocator, b);
        }

        const counts_line = std.mem.trimEnd(u8, self.line_buf.items, "\r");
        if (counts_line.len < 6) return error.MalformedSdfCountsLineTooShort;

        const num_atoms_str = std.mem.trim(u8, counts_line[0..3], " ");
        const num_bonds_str = std.mem.trim(u8, counts_line[3..6], " ");

        const num_atoms = try std.fmt.parseInt(usize, num_atoms_str, 10);
        const num_bonds = try std.fmt.parseInt(usize, num_bonds_str, 10);

        // Read atoms
        var a_idx: usize = 0;
        while (a_idx < num_atoms) : (a_idx += 1) {
            self.line_buf.clearRetainingCapacity();
            while (true) {
                const b = self.reader.readByte() catch |err| {
                    if (err == error.EndOfStream) return error.MalformedSdfTruncatedAtoms;
                    return err;
                };
                if (b == '\n') break;
                try self.line_buf.append(self.allocator, b);
            }
            const atom_line = std.mem.trimEnd(u8, self.line_buf.items, "\r");
            if (atom_line.len < 34) return error.MalformedSdfAtomLineTooShort;

            const x_str = std.mem.trim(u8, atom_line[0..10], " ");
            const y_str = std.mem.trim(u8, atom_line[10..20], " ");
            const z_str = std.mem.trim(u8, atom_line[20..30], " ");
            const sym = std.mem.trim(u8, atom_line[31..34], " ");

            const x = try std.fmt.parseFloat(f64, x_str);
            const y = try std.fmt.parseFloat(f64, y_str);
            const z = try std.fmt.parseFloat(f64, z_str);

            var formal_charge: ?i8 = null;
            if (atom_line.len >= 37) {
                const charge_str = std.mem.trim(u8, atom_line[34..37], " ");
                if (charge_str.len > 0) {
                    const code = std.fmt.parseInt(u8, charge_str, 10) catch 0;
                    formal_charge = switch (code) {
                        1 => 3,
                        2 => 2,
                        3 => 1,
                        5 => -1,
                        6 => -2,
                        7 => -3,
                        else => null,
                    };
                }
            }

            try temp_atoms.append(self.allocator, .{
                .id = a_idx + 1,
                .name = try self.allocator.dupe(u8, sym),
                .element = parseElement(sym),
                .pos = Vec3.init(x, y, z),
                .occupancy = 1.0,
                .b_factor = 0.0,
                .formal_charge = formal_charge,
                .res_seq = 1,
                .res_name = try self.allocator.dupe(u8, "MOL"),
                .chain_id = try self.allocator.dupe(u8, "A"),
            });
        }

        // Skip bonds
        var b_idx: usize = 0;
        while (b_idx < num_bonds) : (b_idx += 1) {
            self.line_buf.clearRetainingCapacity();
            while (true) {
                const b = self.reader.readByte() catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };
                if (b == '\n') break;
                try self.line_buf.append(self.allocator, b);
            }
        }

        // Read remaining lines until "$$$$"
        main_loop: while (true) {
            self.line_buf.clearRetainingCapacity();
            while (true) {
                const b = self.reader.readByte() catch |err| {
                    if (err == error.EndOfStream) {
                        self.eof = true;
                        break :main_loop;
                    }
                    return err;
                };
                if (b == '\n') break;
                try self.line_buf.append(self.allocator, b);
            }
            const line = std.mem.trim(u8, self.line_buf.items, " \r\t");
            if (std.mem.eql(u8, line, "$$$$")) {
                break;
            }
        }

        return try buildModel(self.allocator, 1, temp_atoms.items);
    }
};
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

/// Helper constructor for SdfIterator
pub fn sdfIterator(allocator: std.mem.Allocator, reader: anytype) SdfIterator(@TypeOf(reader)) {
    return SdfIterator(@TypeOf(reader)).init(allocator, reader);
}

/// Serializes model to SDF format
pub fn serializeSdf(writer: anytype, m: model_mod.Model) !void {
    const num_atoms = m.atomCount();
    try writer.print("BioZigSdfMolecule\n  BioZig Ingestion\n\n", .{});
    try writer.print("{: >3}{: >3}  0  0  0  0  0  0  0  0999 V2000\n", .{ num_atoms, @as(usize, 0) });

    for (m.chains) |c| {
        for (c.residues) |res| {
            for (res.atoms) |atom| {
                var el_buf = [_]u8{0} ** 2;
                const el_str = atom.element.toString(&el_buf);

                const code: u8 = switch (atom.formal_charge orelse 0) {
                    3 => 1,
                    2 => 2,
                    1 => 3,
                    -1 => 5,
                    -2 => 6,
                    -3 => 7,
                    else => 0,
                };

                try writer.print(
                    "{: >10.4}{: >10.4}{: >10.4} {: <3} 0  {: >3}  0  0  0  0  0  0  0  0  0  0\n",
                    .{
                        atom.pos.x,
                        atom.pos.y,
                        atom.pos.z,
                        el_str,
                        code,
                    },
                );
            }
        }
    }

    try writer.writeAll("M  END\n$$$$\n");
}

pub fn parseSdfCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\n');
    var line_idx: usize = 0;
    var num_atoms: usize = 0;
    var atoms_read: usize = 0;
    var in_mol = true;

    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\r");
        if (std.mem.startsWith(u8, line, "$$$$")) {
            line_idx = 0;
            num_atoms = 0;
            atoms_read = 0;
            in_mol = true;
            continue;
        }

        if (in_mol) {
            if (line_idx == 3) {
                if (line.len >= 3) {
                    const num_str = std.mem.trim(u8, line[0..3], " ");
                    num_atoms = std.fmt.parseInt(usize, num_str, 10) catch 0;
                }
            } else if (line_idx > 3 and atoms_read < num_atoms) {
                if (line.len >= 30) {
                    const x_str = std.mem.trim(u8, line[0..10], " ");
                    const y_str = std.mem.trim(u8, line[10..20], " ");
                    const z_str = std.mem.trim(u8, line[20..30], " ");
                    const x = try std.fmt.parseFloat(f64, x_str);
                    const y = try std.fmt.parseFloat(f64, y_str);
                    const z = try std.fmt.parseFloat(f64, z_str);
                    try coords.append(allocator, Vec3.init(x, y, z));
                    atoms_read += 1;
                }
            }
        }
        line_idx += 1;
    }
    return try coords.toOwnedSlice(allocator);
}

test "sdf zero-copy memory optimization" {
    const allocator = std.testing.allocator;
    const data = 
        \\Molecule
        \\  Comments
        \\
        \\  3  2  0  0  0  0  0  0  0  0999 V2000
        \\   11.1040    6.1340   -6.5040 N   0  0  0  0  0  0  0  0  0  0  0  0
        \\   11.6390    6.0710   -5.1470 C   0  0  0  0  0  0  0  0  0  0  0  0
        \\   10.8250    5.0520   -4.3260 C   0  0  0  0  0  0  0  0  0  0  0  0
        \\$$$$
        ;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const start_memory = arena.queryCapacity();
    
    const coords = try parseSdfCoords(arena_allocator, data);
    try std.testing.expectEqual(@as(usize, 3), coords.len);
    try std.testing.expectEqual(@as(f64, 11.104), coords[0].x);
    
    const end_memory = arena.queryCapacity();
    try std.testing.expect(end_memory - start_memory < 500);
}
