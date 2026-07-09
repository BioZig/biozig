const std = @import("std");
const structural = @import("structural");
const geom = structural.geometry;
const Vec3 = geom.Vec3;

pub const PdbCoordinateStream = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn next(self: *PdbCoordinateStream) !?Vec3 {
        while (self.pos < self.buffer.len) {
            const nl = std.mem.indexOfScalarPos(u8, self.buffer, self.pos, '\n') orelse self.buffer.len;
            const line_raw = self.buffer[self.pos..nl];
            self.pos = nl + 1;

            const line = std.mem.trimEnd(u8, line_raw, "\r");
            if (line.len < 54) continue;

            if (std.mem.startsWith(u8, line, "ATOM  ") or std.mem.startsWith(u8, line, "HETATM")) {
                const x_str = std.mem.trim(u8, line[30..38], " ");
                const y_str = std.mem.trim(u8, line[38..46], " ");
                const z_str = std.mem.trim(u8, line[46..54], " ");

                const x = try std.fmt.parseFloat(f64, x_str);
                const y = try std.fmt.parseFloat(f64, y_str);
                const z = try std.fmt.parseFloat(f64, z_str);
                return Vec3.init(x, y, z);
            }
        }
        return null;
    }
};

pub fn parsePdbCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]Vec3 {
    var coords = std.ArrayList(Vec3).empty;
    defer coords.deinit(allocator);

    var stream = PdbCoordinateStream{ .buffer = buffer };
    while (try stream.next()) |vec| {
        try coords.append(allocator, vec);
    }
    return try coords.toOwnedSlice(allocator);
}

pub const CaAtom = struct {
    res_seq: i32,
    chain_id: u8,
    aa: u8,
    coords: Vec3,
};

pub fn resNameToChar(res: []const u8) u8 {
    if (std.mem.eql(u8, res, "ALA")) return 'A';
    if (std.mem.eql(u8, res, "ARG")) return 'R';
    if (std.mem.eql(u8, res, "ASN")) return 'N';
    if (std.mem.eql(u8, res, "ASP")) return 'D';
    if (std.mem.eql(u8, res, "CYS")) return 'C';
    if (std.mem.eql(u8, res, "GLU")) return 'E';
    if (std.mem.eql(u8, res, "GLN")) return 'Q';
    if (std.mem.eql(u8, res, "GLY")) return 'G';
    if (std.mem.eql(u8, res, "HIS")) return 'H';
    if (std.mem.eql(u8, res, "ILE")) return 'I';
    if (std.mem.eql(u8, res, "LEU")) return 'L';
    if (std.mem.eql(u8, res, "LYS")) return 'K';
    if (std.mem.eql(u8, res, "MET")) return 'M';
    if (std.mem.eql(u8, res, "PHE")) return 'F';
    if (std.mem.eql(u8, res, "PRO")) return 'P';
    if (std.mem.eql(u8, res, "SER")) return 'S';
    if (std.mem.eql(u8, res, "THR")) return 'T';
    if (std.mem.eql(u8, res, "TRP")) return 'W';
    if (std.mem.eql(u8, res, "TYR")) return 'Y';
    if (std.mem.eql(u8, res, "VAL")) return 'V';
    return 'X';
}

pub fn parsePdbCalphaCoords(allocator: std.mem.Allocator, buffer: []const u8) ![]CaAtom {
    var coords = std.ArrayList(CaAtom).empty;
    defer coords.deinit(allocator);

    var pos: usize = 0;
    while (pos < buffer.len) {
        const nl = std.mem.indexOfScalarPos(u8, buffer, pos, '\n') orelse buffer.len;
        const line_raw = buffer[pos..nl];
        pos = nl + 1;

        const line = std.mem.trimEnd(u8, line_raw, "\r");
        if (line.len < 54) continue;

        if (std.mem.startsWith(u8, line, "ATOM  ")) {
            if (line.len > 54 and std.mem.eql(u8, line[13..15], "CA")) {
                const res_name = std.mem.trim(u8, line[17..20], " ");
                const chain_id = line[21];
                const res_seq_str = std.mem.trim(u8, line[22..26], " ");
                const x_str = std.mem.trim(u8, line[30..38], " ");
                const y_str = std.mem.trim(u8, line[38..46], " ");
                const z_str = std.mem.trim(u8, line[46..54], " ");

                const aa = resNameToChar(res_name);
                const res_seq = std.fmt.parseInt(i32, res_seq_str, 10) catch -1;
                if (res_seq != -1) {
                    const x = try std.fmt.parseFloat(f64, x_str);
                    const y = try std.fmt.parseFloat(f64, y_str);
                    const z = try std.fmt.parseFloat(f64, z_str);
                    try coords.append(allocator, CaAtom{ .res_seq = res_seq, .chain_id = chain_id, .aa = aa, .coords = Vec3.init(x, y, z) });
                }
            }
        }
    }
    return try coords.toOwnedSlice(allocator);
}

test "pdb zero-copy memory optimization" {
    const allocator = std.testing.allocator;
    const pdb_data =
        \\ATOM      1  N   ALA A   1      11.104   6.134  -6.504  1.00  0.00           N  
        \\ATOM      2  CA  ALA A   1      11.639   6.071  -5.147  1.00  0.00           C  
        \\ATOM      3  C   ALA A   1      10.825   5.052  -4.326  1.00  0.00           C  
    ;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const start_memory = arena.queryCapacity();

    const coords = try parsePdbCoords(arena_allocator, pdb_data);
    try std.testing.expectEqual(@as(usize, 3), coords.len);
    try std.testing.expectEqual(@as(f64, 11.104), coords[0].x);
    try std.testing.expectEqual(@as(f64, 6.134), coords[0].y);
    try std.testing.expectEqual(@as(f64, -6.504), coords[0].z);

    // Prove memory optimization: Memory allocated should be strictly for the ArrayList of 3 Vec3s, no strings allocated.
    const end_memory = arena.queryCapacity();
    // Assuming Vec3 is 3 * 8 = 24 bytes. ArrayList might allocate 8 items capacity -> 192 bytes.
    // It should definitely be small.
    try std.testing.expect(end_memory - start_memory < 500);
}

pub fn pdbStreamIterator(reader: anytype, buffer: []u8) PdbStreamIterator(@TypeOf(reader)) {
    return PdbStreamIterator(@TypeOf(reader)).init(reader, buffer);
}

pub fn PdbStreamIterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        buffer: []u8,
        pos: usize = 0,
        valid_len: usize = 0,
        eof: bool = false,

        const Self = @This();

        pub fn init(reader: ReaderType, buffer: []u8) Self {
            return .{
                .reader = reader,
                .buffer = buffer,
            };
        }

        fn fill(self: *Self) !void {
            if (self.eof) return;
            if (self.pos > 0 and self.valid_len > self.pos) {
                std.mem.copyForwards(u8, self.buffer[0 .. self.valid_len - self.pos], self.buffer[self.pos .. self.valid_len]);
                self.valid_len -= self.pos;
            } else if (self.pos == self.valid_len) {
                self.valid_len = 0;
            }
            self.pos = 0;
            var data: [1][]u8 = .{ self.buffer[self.valid_len..] };
            const read_len = self.reader.readVec(&data) catch |err| switch (err) {
                error.EndOfStream => @as(usize, 0),
                else => return err,
            };
            if (read_len == 0) {
                self.eof = true;
            }
            self.valid_len += read_len;
        }

        pub fn nextLine(self: *Self) !?[]const u8 {
            while (true) {
                if (self.pos == self.valid_len) {
                    if (self.eof) return null;
                    try self.fill();
                    if (self.pos == self.valid_len) return null;
                }

                const nl = std.mem.indexOfScalarPos(u8, self.buffer[0..self.valid_len], self.pos, '\n');
                if (nl) |idx| {
                    const line = self.buffer[self.pos..idx];
                    self.pos = idx + 1;
                    return std.mem.trimEnd(u8, line, "\r");
                } else {
                    if (self.eof) {
                        const line = self.buffer[self.pos..self.valid_len];
                        self.pos = self.valid_len;
                        if (line.len == 0) return null;
                        return std.mem.trimEnd(u8, line, "\r");
                    }
                    if (self.pos == 0 and self.valid_len == self.buffer.len) {
                        const line = self.buffer[0..self.valid_len];
                        self.pos = self.valid_len;
                        return line;
                    }
                    try self.fill();
                }
            }
        }
    };
}
