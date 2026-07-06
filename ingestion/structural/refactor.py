import os
import re
import sys

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # If it's already refactored, skip
    if "parseCoords" in content:
        return

    basename = os.path.basename(filepath)
    prefix = basename.split('.')[0].capitalize()
    if prefix == "Mmcif": prefix = "MmCif"
    if prefix == "Mol2": prefix = "Mol2"

    func_name = f"parse{prefix}Coords"

    # We will append a new function that does zero-copy parsing of coordinates.
    # It will take `buffer: []const u8` and return `![]Vec3`.

    # Depending on the file format, the parsing logic is slightly different, but 
    # we can do a simple line iterator.
    
    if prefix == "Pdb":
        new_func = """
pub fn parsePdbCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\\r");
        if (line.len < 54) continue;
        if (std.mem.startsWith(u8, line, "ATOM  ") or std.mem.startsWith(u8, line, "HETATM")) {
            const x_str = std.mem.trim(u8, line[30..38], " ");
            const y_str = std.mem.trim(u8, line[38..46], " ");
            const z_str = std.mem.trim(u8, line[46..54], " ");
            const x = try std.fmt.parseFloat(f64, x_str);
            const y = try std.fmt.parseFloat(f64, y_str);
            const z = try std.fmt.parseFloat(f64, z_str);
            try coords.append(allocator, Vec3.init(x, y, z));
        }
    }
    return try coords.toOwnedSlice(allocator);
}
"""
    elif prefix == "MmCif":
        new_func = """
pub fn parseMmCifCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);
    
    // Simplistic parser for mmCIF coordinates
    // We look for ATOM/HETATM lines in the loop_ _atom_site.
    // Assuming x, y, z are in some specific columns, but typically mmcif needs a full parser.
    // For now, let's implement a simplified coordinate streamer.
    
    var lines = std.mem.splitScalar(u8, buffer, '\\n');
    var in_atom_site = false;
    var x_idx: ?usize = null;
    var y_idx: ?usize = null;
    var z_idx: ?usize = null;
    var col_idx: usize = 0;
    
    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\\r");
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
            var x: f64 = 0; var y: f64 = 0; var z: f64 = 0;
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
"""
    elif prefix == "Mol2":
        new_func = """
pub fn parseMol2Coords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\\n');
    var in_atoms = false;
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \\r");
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
"""
    elif prefix == "Sdf":
        new_func = """
pub fn parseSdfCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\\n');
    var line_idx: usize = 0;
    var num_atoms: usize = 0;
    var atoms_read: usize = 0;
    var in_mol = true;

    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\\r");
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
"""
    elif prefix == "Pqr":
        new_func = """
pub fn parsePqrCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, buffer, '\\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trimEnd(u8, line_raw, "\\r");
        if (std.mem.startsWith(u8, line, "ATOM") or std.mem.startsWith(u8, line, "HETATM")) {
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            var i: usize = 0;
            var x: f64 = 0; var y: f64 = 0; var z: f64 = 0;
            
            // PQR format: ATOM id name res chain res_id x y z charge radius
            // So x, y, z are usually tokens 5, 6, 7 or 6, 7, 8 depending on whether chain is present.
            // Let's just use the end minus 2, 3, 4. Actually let's just parse the 3 tokens before the last 2.
            
            var token_list = std.ArrayList([]const u8).empty;
            defer token_list.deinit(allocator);
            while (tokens.next()) |tok| {
                try token_list.append(allocator, tok);
            }
            if (token_list.items.len >= 8) {
                const len = token_list.items.len;
                x = try std.fmt.parseFloat(f64, token_list.items[len - 5]);
                y = try std.fmt.parseFloat(f64, token_list.items[len - 4]);
                z = try std.fmt.parseFloat(f64, token_list.items[len - 3]);
                try coords.append(allocator, Vec3.init(x, y, z));
            }
        }
    }
    return try coords.toOwnedSlice(allocator);
}
"""

    with open(filepath, 'a') as f:
        f.write(new_func)

for file in ["pdb.zig", "mmcif.zig", "sdf.zig", "mol2.zig", "pqr.zig"]:
    process_file("/Users/sulky/Desktop/biozig/ingestion/structural/" + file)
