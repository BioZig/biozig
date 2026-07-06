const std = @import("std");
const cellular = @import("cellular");
const expression = cellular.expression;

pub const MtxEntry = struct {
    row: usize, // 0-based row coordinate internally
    col: usize, // 0-based col coordinate internally
    val: f64,
};

pub const MtxMmapIterator = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn init(buffer: []const u8) MtxMmapIterator {
        return .{ .buffer = buffer };
    }

    pub fn next(self: *MtxMmapIterator) ?[]const u8 {
        if (self.pos >= self.buffer.len) return null;
        const start = self.pos;

        while (self.pos + 8 <= self.buffer.len) {
            const chunk = std.mem.readInt(u64, self.buffer[self.pos..][0..8], .little);
            const xor_mask = chunk ^ @as(u64, 0x0A0A0A0A0A0A0A0A);
            const has_zero = (xor_mask -% @as(u64, 0x0101010101010101)) & ~xor_mask & @as(u64, 0x8080808080808080);
            if (has_zero != 0) {
                const offset = @ctz(has_zero) / 8;
                self.pos += offset;
                const line = self.buffer[start..self.pos];
                self.pos += 1;
                if (line.len > 0 and line[line.len - 1] == '\r') {
                    return line[0 .. line.len - 1];
                }
                return line;
            }
            self.pos += 8;
        }

        if (self.pos < self.buffer.len) {
            var tmp: [8]u8 = undefined;
            const remain = self.buffer.len - self.pos;
            @memcpy(tmp[0..remain], self.buffer[self.pos..]);
            @memset(tmp[remain..], 0);

            const chunk = std.mem.readInt(u64, &tmp, .little);
            const xor_mask = chunk ^ @as(u64, 0x0A0A0A0A0A0A0A0A);
            const has_zero = (xor_mask -% @as(u64, 0x0101010101010101)) & ~xor_mask & @as(u64, 0x8080808080808080);
            if (has_zero != 0) {
                const offset = @ctz(has_zero) / 8;
                if (offset < remain) {
                    self.pos += offset;
                    const line = self.buffer[start..self.pos];
                    self.pos += 1;
                    if (line.len > 0 and line[line.len - 1] == '\r') {
                        return line[0 .. line.len - 1];
                    }
                    return line;
                }
            }
            self.pos = self.buffer.len;
        }

        const line = self.buffer[start..self.pos];
        if (line.len > 0 and line[line.len - 1] == '\r') {
            return line[0 .. line.len - 1];
        }
        return line;
    }

    pub fn reset(self: *MtxMmapIterator, pos: usize) void {
        self.pos = pos;
    }
};

fn sortRow(indices: []u32, data: []f64) void {
    if (indices.len <= 1) return;
    for (1..indices.len) |i| {
        var j = i;
        while (j > 0 and indices[j-1] > indices[j]) : (j -= 1) {
            std.mem.swap(u32, &indices[j-1], &indices[j]);
            std.mem.swap(f64, &data[j-1], &data[j]);
        }
    }
}

pub const MtxParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MtxParser {
        return .{ .allocator = allocator };
    }

    pub fn parseSparseMmap(self: MtxParser, buffer: []const u8) !expression.SparseMatrix {
        var iter = MtxMmapIterator.init(buffer);

        var header_seen = false;
        var dims_line: ?[]const u8 = null;
        
        while (iter.next()) |line| {
            const trimmed = std.mem.trimEnd(u8, line, "\r");
            if (trimmed.len == 0) continue;
            if (trimmed[0] == '%') {
                if (std.mem.startsWith(u8, trimmed, "%%MatrixMarket")) {
                    header_seen = true;
                    if (!std.mem.containsAtLeast(u8, trimmed, 1, "matrix") or
                        !std.mem.containsAtLeast(u8, trimmed, 1, "coordinate") or
                        !std.mem.containsAtLeast(u8, trimmed, 1, "real")) {
                        return error.UnsupportedMtxFormat;
                    }
                }
                continue;
            }
            dims_line = line;
            break;
        }

        if (!header_seen) return error.MtxHeaderMissing;
        const dims_str = dims_line orelse return error.MtxMissingRows;

        var dims = std.mem.tokenizeScalar(u8, dims_str, ' ');
        const rows_str = dims.next() orelse return error.MtxMissingRows;
        const cols_str = dims.next() orelse return error.MtxMissingCols;
        const entries_str = dims.next() orelse return error.MtxMissingEntries;

        const rows = try std.fmt.parseInt(usize, rows_str, 10);
        const cols = try std.fmt.parseInt(usize, cols_str, 10);
        const entries = try std.fmt.parseInt(usize, entries_str, 10);

        if (rows == 0 or cols == 0 or entries == 0) return error.InvalidMtxDimensions;

        var indptr = try self.allocator.alloc(u32, rows + 1);
        errdefer self.allocator.free(indptr);
        @memset(indptr, 0);

        const data_start_pos = iter.pos;
        var actual_entries: usize = 0;

        while (iter.next()) |entry_line| {
            if (entry_line.len == 0 or entry_line[0] == '%') continue;
            
            var tokens = std.mem.tokenizeScalar(u8, entry_line, ' ');
            const r_str = tokens.next() orelse return error.MtxRecordMalformed;
            const r = try std.fmt.parseInt(usize, r_str, 10);
            if (r == 0 or r > rows) return error.MtxIndexOutOfBounds;
            
            indptr[r] += 1;
            actual_entries += 1;
        }

        if (actual_entries != entries) return error.MtxEntryCountMismatch;

        var sum: u32 = 0;
        for (1..rows + 1) |i| {
            const count = indptr[i];
            indptr[i-1] = sum;
            sum += count;
        }
        indptr[rows] = sum;

        var data = try self.allocator.alloc(f64, entries);
        errdefer self.allocator.free(data);
        var indices = try self.allocator.alloc(u32, entries);
        errdefer self.allocator.free(indices);

        var current_pos = try self.allocator.dupe(u32, indptr[0..rows]);
        defer self.allocator.free(current_pos);

        iter.reset(data_start_pos);

        while (iter.next()) |entry_line| {
            if (entry_line.len == 0 or entry_line[0] == '%') continue;
            
            var tokens = std.mem.tokenizeScalar(u8, entry_line, ' ');
            const r_str = tokens.next().?;
            const c_str = tokens.next() orelse return error.MtxRecordMalformed;
            const v_str = tokens.next() orelse return error.MtxRecordMalformed;

            const r = try std.fmt.parseInt(usize, r_str, 10);
            const c = try std.fmt.parseInt(usize, c_str, 10);
            const v = try std.fmt.parseFloat(f64, v_str);

            if (c == 0 or c > cols) return error.MtxIndexOutOfBounds;

            const row_idx = r - 1;
            const pos = current_pos[row_idx];
            data[pos] = v;
            indices[pos] = @as(u32, @intCast(c - 1));
            current_pos[row_idx] += 1;
        }

        for (0..rows) |r| {
            const start = indptr[r];
            const end = indptr[r + 1];
            sortRow(indices[start..end], data[start..end]);
        }

        const sample_names = try self.allocator.alloc(?[]const u8, rows);
        errdefer self.allocator.free(sample_names);
        @memset(sample_names, null);

        const feature_names = try self.allocator.alloc(?[]const u8, cols);
        errdefer self.allocator.free(feature_names);
        @memset(feature_names, null);

        return expression.SparseMatrix{
            .allocator = self.allocator,
            .format = .csr,
            .sample_names = sample_names,
            .feature_names = feature_names,
            .data = data,
            .indices = indices,
            .indptr = indptr,
            .rows = rows,
            .cols = cols,
        };
    }

    pub fn parseSparse(self: MtxParser, reader: anytype) !expression.SparseMatrix {
        const buf = try reader.readAllAlloc(self.allocator, 1024 * 1024 * 1024);
        defer self.allocator.free(buf);
        return self.parseSparseMmap(buf);
    }

    pub fn parseDenseMmap(self: MtxParser, buffer: []const u8) !expression.DenseMatrix {
        var sparse = try self.parseSparseMmap(buffer);
        defer sparse.deinit();

        var dense = try expression.DenseMatrix.init(self.allocator, sparse.rows, sparse.cols);
        errdefer dense.deinit();

        for (0..sparse.rows) |r| {
            const start = sparse.indptr[r];
            const end = sparse.indptr[r + 1];
            for (sparse.indices[start..end], 0..) |col_idx, idx| {
                dense.set(r, @as(usize, @intCast(col_idx)), sparse.data[start + idx]);
            }
        }

        return dense;
    }

    pub fn parseDense(self: MtxParser, reader: anytype) !expression.DenseMatrix {
        const buf = try reader.readAllAlloc(self.allocator, 1024 * 1024 * 1024);
        defer self.allocator.free(buf);
        return self.parseDenseMmap(buf);
    }
};

pub fn serializeSparse(writer: anytype, mat: expression.SparseMatrix) !void {
    try writer.writeAll("%%MatrixMarket matrix coordinate real general\n");
    
    var entries: usize = 0;
    for (0..mat.rows) |r| {
        entries += mat.indptr[r + 1] - mat.indptr[r];
    }

    try writer.print("{} {} {}\n", .{ mat.rows, mat.cols, entries });

    for (0..mat.rows) |r| {
        const start = mat.indptr[r];
        const end = mat.indptr[r + 1];
        for (mat.indices[start..end], 0..) |col_idx, idx| {
            const val = mat.data[start + idx];
            try writer.print("{} {} {d:.6}\n", .{ r + 1, col_idx + 1, val });
        }
    }
}

test "mtx mmap parser memory usage" {
    const testing = std.testing;
    const mtx_content =
        \\%%MatrixMarket matrix coordinate real general
        \\% A test matrix
        \\4 4 6
        \\1 1 1.0
        \\2 2 2.0
        \\3 3 3.0
        \\4 4 4.0
        \\2 1 0.5
        \\3 2 1.5
    ;

    var parser = MtxParser.init(testing.allocator);
    var sparse = try parser.parseSparseMmap(mtx_content);
    defer sparse.deinit();

    try testing.expectEqual(@as(usize, 4), sparse.rows);
    try testing.expectEqual(@as(usize, 4), sparse.cols);

    // Check data
    // Row 1: col 1
    // Row 2: col 1, 2
    // Row 3: col 2, 3
    // Row 4: col 4
    try testing.expectEqual(@as(usize, 0), sparse.indptr[0]);
    try testing.expectEqual(@as(usize, 1), sparse.indptr[1]);
    try testing.expectEqual(@as(usize, 3), sparse.indptr[2]);
    try testing.expectEqual(@as(usize, 5), sparse.indptr[3]);
    try testing.expectEqual(@as(usize, 6), sparse.indptr[4]);

    try testing.expectEqual(@as(f64, 1.0), sparse.data[0]);
    try testing.expectEqual(@as(u32, 0), sparse.indices[0]);

    try testing.expectEqual(@as(f64, 0.5), sparse.data[1]);
    try testing.expectEqual(@as(u32, 0), sparse.indices[1]);
    try testing.expectEqual(@as(f64, 2.0), sparse.data[2]);
    try testing.expectEqual(@as(u32, 1), sparse.indices[2]);

    try testing.expectEqual(@as(f64, 1.5), sparse.data[3]);
    try testing.expectEqual(@as(u32, 1), sparse.indices[3]);
    try testing.expectEqual(@as(f64, 3.0), sparse.data[4]);
    try testing.expectEqual(@as(u32, 2), sparse.indices[4]);

    try testing.expectEqual(@as(f64, 4.0), sparse.data[5]);
    try testing.expectEqual(@as(u32, 3), sparse.indices[5]);
}
