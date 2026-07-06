const std = @import("std");
const cellular = @import("cellular");
const expression = cellular.expression;

pub const MatrixMmapIterator = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn init(buffer: []const u8) MatrixMmapIterator {
        return .{ .buffer = buffer };
    }

    pub fn next(self: *MatrixMmapIterator) ?[]const u8 {
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
                self.pos += 1; // skip '\n'
                return std.mem.trimEnd(u8, line, "\r");
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
                    self.pos += 1; // skip '\n'
                    return std.mem.trimEnd(u8, line, "\r");
                }
            }
            self.pos = self.buffer.len;
        }

        const line = self.buffer[start..self.pos];
        return std.mem.trimEnd(u8, line, "\r");
    }

    pub fn reset(self: *MatrixMmapIterator, pos: usize) void {
        self.pos = pos;
    }
};

pub fn parseMatrixMmap(
    allocator: std.mem.Allocator,
    buffer: []const u8,
    delimiter: u8,
) !expression.DenseMatrix {
    var iter = MatrixMmapIterator.init(buffer);

    // 1. Read header line
    const header_line = iter.next() orelse return error.MalformedMatrixEmpty;
    const header = std.mem.trimEnd(u8, header_line, "\r");
    if (header.len == 0) return error.MalformedMatrixHeaderEmpty;

    var header_toks = std.mem.splitScalar(u8, header, delimiter);
    _ = header_toks.next() orelse return error.MalformedMatrixHeaderEmpty; // Skip first field (e.g., "SampleID")

    var features = std.ArrayList([]const u8).init(allocator);
    defer {
        for (features.items) |f| allocator.free(f);
        features.deinit();
    }
    while (header_toks.next()) |tok| {
        const trimmed = std.mem.trim(u8, tok, " \t\"");
        try features.append(try allocator.dupe(u8, trimmed));
    }

    if (features.items.len == 0) return error.MalformedMatrixNoFeatures;

    const cols = features.items.len;
    const data_start_pos = iter.pos;

    // 2. Count rows
    var rows: usize = 0;
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        rows += 1;
    }

    if (rows == 0) return error.MalformedMatrixNoSamples;

    // 3. Construct DenseMatrix
    var dense = try expression.DenseMatrix.init(allocator, rows, cols);
    errdefer dense.deinit();

    for (features.items, 0..) |f, c| {
        try dense.setFeatureName(c, f);
    }

    // 4. Fill DenseMatrix
    iter.reset(data_start_pos);
    var current_row: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var tokens = std.mem.splitScalar(u8, line, delimiter);
        const sample_name = tokens.next() orelse return error.MalformedMatrixRowNameMissing;
        const trimmed_sample = std.mem.trim(u8, sample_name, " \t\"");
        try dense.setSampleName(current_row, trimmed_sample);

        var val_count: usize = 0;
        while (tokens.next()) |tok| {
            if (val_count >= cols) return error.MatrixRowColMismatch;
            const trimmed_val = std.mem.trim(u8, tok, " \t");
            const val = try std.fmt.parseFloat(f64, trimmed_val);
            dense.set(current_row, val_count, val);
            val_count += 1;
        }

        if (val_count != cols) return error.MatrixRowColMismatch;
        current_row += 1;
    }

    return dense;
}

pub fn parseSparseMmap(
    allocator: std.mem.Allocator,
    buffer: []const u8,
    delimiter: u8,
) !expression.SparseMatrix {
    var iter = MatrixMmapIterator.init(buffer);

    // 1. Read header line
    const header_line = iter.next() orelse return error.MalformedMatrixEmpty;
    const header = std.mem.trimEnd(u8, header_line, "\r");
    if (header.len == 0) return error.MalformedMatrixHeaderEmpty;

    var header_toks = std.mem.splitScalar(u8, header, delimiter);
    _ = header_toks.next() orelse return error.MalformedMatrixHeaderEmpty;

    var features = std.ArrayList([]const u8).init(allocator);
    defer {
        for (features.items) |f| allocator.free(f);
        features.deinit();
    }
    while (header_toks.next()) |tok| {
        const trimmed = std.mem.trim(u8, tok, " \t\"");
        try features.append(try allocator.dupe(u8, trimmed));
    }

    if (features.items.len == 0) return error.MalformedMatrixNoFeatures;

    const cols = features.items.len;
    const data_start_pos = iter.pos;

    // 2. Count rows and non-zeros
    var rows: usize = 0;
    var nnz: usize = 0;
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.splitScalar(u8, line, delimiter);
        _ = tokens.next(); // Skip sample name

        var val_count: usize = 0;
        while (tokens.next()) |tok| {
            if (val_count >= cols) return error.MatrixRowColMismatch;
            const trimmed_val = std.mem.trim(u8, tok, " \t");
            const val = try std.fmt.parseFloat(f64, trimmed_val);
            if (val != 0.0) {
                nnz += 1;
            }
            val_count += 1;
        }
        if (val_count != cols) return error.MatrixRowColMismatch;
        rows += 1;
    }

    if (rows == 0) return error.MalformedMatrixNoSamples;

    // 3. Construct SparseMatrix
    var sample_names = try allocator.alloc(?[]const u8, rows);
    errdefer allocator.free(sample_names);
    @memset(sample_names, null);

    var feature_names = try allocator.alloc(?[]const u8, cols);
    errdefer allocator.free(feature_names);
    for (features.items, 0..) |f, c| {
        feature_names[c] = try allocator.dupe(u8, f);
    }

    var indptr = try allocator.alloc(u32, rows + 1);
    errdefer allocator.free(indptr);
    var indices = try allocator.alloc(u32, nnz);
    errdefer allocator.free(indices);
    var data = try allocator.alloc(f64, nnz);
    errdefer allocator.free(data);

    // 4. Fill SparseMatrix
    iter.reset(data_start_pos);
    var current_row: usize = 0;
    var current_nnz: usize = 0;

    indptr[0] = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var tokens = std.mem.splitScalar(u8, line, delimiter);
        const sample_name = tokens.next() orelse return error.MalformedMatrixRowNameMissing;
        const trimmed_sample = std.mem.trim(u8, sample_name, " \t\"");
        sample_names[current_row] = try allocator.dupe(u8, trimmed_sample);

        var val_count: usize = 0;
        while (tokens.next()) |tok| {
            const trimmed_val = std.mem.trim(u8, tok, " \t");
            const val = std.fmt.parseFloat(f64, trimmed_val) catch 0.0;
            if (val != 0.0) {
                data[current_nnz] = val;
                indices[current_nnz] = @as(u32, @intCast(val_count));
                current_nnz += 1;
            }
            val_count += 1;
        }

        current_row += 1;
        indptr[current_row] = @as(u32, @intCast(current_nnz));
    }

    return expression.SparseMatrix{
        .allocator = allocator,
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

pub fn parseSparse(
    allocator: std.mem.Allocator,
    reader: anytype,
    delimiter: u8,
) !expression.SparseMatrix {
    const buf = try reader.readAllAlloc(allocator, 1024 * 1024 * 1024);
    defer allocator.free(buf);
    return parseSparseMmap(allocator, buf, delimiter);
}

pub fn parseMatrix(
    allocator: std.mem.Allocator,
    reader: anytype,
    delimiter: u8,
) !expression.DenseMatrix {
    const buf = try reader.readAllAlloc(allocator, 1024 * 1024 * 1024);
    defer allocator.free(buf);
    return parseMatrixMmap(allocator, buf, delimiter);
}

pub fn serializeMatrix(writer: anytype, mat: expression.DenseMatrix, delimiter: u8) !void {
    try writer.writeAll("SampleID");
    for (mat.feature_names) |f| {
        try writer.print("{c}{s}", .{ delimiter, f orelse "UnknownFeature" });
    }
    try writer.writeAll("\n");

    for (0..mat.rows) |r| {
        try writer.print("{s}", .{mat.sample_names[r] orelse "UnknownSample"});
        const row_data = mat.rowSlice(r);
        for (row_data) |val| {
            try writer.print("{c}{d:.6}", .{ delimiter, val });
        }
        try writer.writeAll("\n");
    }
}
