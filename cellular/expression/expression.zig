const std = @import("std");
const core = @import("core");
const serialization = core.serialization;

/// Represents a dense gene expression matrix.
/// Rows typically represent samples/cells, columns represent features/genes.
pub const DenseMatrix = struct {
    allocator: std.mem.Allocator,
    sample_names: []?[]const u8,
    feature_names: []?[]const u8,
    data: []f64,
    rows: usize,
    cols: usize,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !DenseMatrix {
        const data = try allocator.alloc(f64, rows * cols);
        @memset(data, 0.0);
        
        const sample_names = try allocator.alloc(?[]const u8, rows);
        @memset(sample_names, null);
        const feature_names = try allocator.alloc(?[]const u8, cols);
        @memset(feature_names, null);
        
        return .{
            .allocator = allocator,
            .sample_names = sample_names,
            .feature_names = feature_names,
            .data = data,
            .rows = rows,
            .cols = cols,
        };
    }

    pub fn deinit(self: *DenseMatrix) void {
        for (self.sample_names) |name| {
            if (name) |n| self.allocator.free(n);
        }
        for (self.feature_names) |name| {
            if (name) |n| self.allocator.free(n);
        }
        self.allocator.free(self.sample_names);
        self.allocator.free(self.feature_names);
        self.allocator.free(self.data);
    }

    pub fn set(self: *DenseMatrix, row: usize, col: usize, val: f64) void {
        std.debug.assert(row < self.rows and col < self.cols);
        self.data[row * self.cols + col] = val;
    }

    pub fn get(self: DenseMatrix, row: usize, col: usize) f64 {
        std.debug.assert(row < self.rows and col < self.cols);
        return self.data[row * self.cols + col];
    }

    pub fn rowSlice(self: DenseMatrix, row: usize) []f64 {
        std.debug.assert(row < self.rows);
        return self.data[row * self.cols .. (row + 1) * self.cols];
    }

    pub fn setSampleName(self: *DenseMatrix, row: usize, name: []const u8) !void {
        std.debug.assert(row < self.rows);
        self.sample_names[row] = try self.allocator.dupe(u8, name);
    }

    pub fn setFeatureName(self: *DenseMatrix, col: usize, name: []const u8) !void {
        std.debug.assert(col < self.cols);
        self.feature_names[col] = try self.allocator.dupe(u8, name);
    }

    /// Applies a normalization function to each row.
    pub fn applyRowNormalization(self: *DenseMatrix, func: *const fn (row: []f64) void) void {
        for (0..self.rows) |i| {
            func(self.rowSlice(i));
        }
    }

    pub fn serialize(self: DenseMatrix, writer: anytype) !void {
        try serialization.serialize(writer, self.rows);
        try serialization.serialize(writer, self.cols);
        try serialization.serialize(writer, self.sample_names);
        try serialization.serialize(writer, self.feature_names);
        try serialization.serialize(writer, self.data);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !DenseMatrix {
        const rows = try serialization.deserialize(reader, usize, allocator);
        const cols = try serialization.deserialize(reader, usize, allocator);
        const sample_names = try serialization.deserialize(reader, []?[]const u8, allocator);
        const feature_names = try serialization.deserialize(reader, []?[]const u8, allocator);
        const data = try serialization.deserialize(reader, []f64, allocator);

        return .{
            .allocator = allocator,
            .sample_names = sample_names,
            .feature_names = feature_names,
            .data = data,
            .rows = rows,
            .cols = cols,
        };
    }
};

pub const SparseFormat = enum {
    csr,
    csc,
};

/// Represents a sparse gene expression matrix in CSR or CSC format.
pub const SparseMatrix = struct {
    allocator: std.mem.Allocator,
    format: SparseFormat,
    sample_names: []?[]const u8,
    feature_names: []?[]const u8,
    data: []f64,
    indices: []u32,
    indptr: []u32,
    rows: usize,
    cols: usize,

    pub fn init(allocator: std.mem.Allocator, format: SparseFormat, rows: usize, cols: usize, nnz: usize) !SparseMatrix {
        const sample_names = try allocator.alloc(?[]const u8, rows);
        @memset(sample_names, null);
        const feature_names = try allocator.alloc(?[]const u8, cols);
        @memset(feature_names, null);
        
        const data = try allocator.alloc(f64, nnz);
        const indices = try allocator.alloc(u32, nnz);
        const indptr_len = if (format == .csr) rows + 1 else cols + 1;
        const indptr = try allocator.alloc(u32, indptr_len);
        @memset(indptr, 0);

        return .{
            .allocator = allocator,
            .format = format,
            .sample_names = sample_names,
            .feature_names = feature_names,
            .data = data,
            .indices = indices,
            .indptr = indptr,
            .rows = rows,
            .cols = cols,
        };
    }

    pub fn fromDense(allocator: std.mem.Allocator, dense: DenseMatrix, format: SparseFormat) !SparseMatrix {
        var nnz: usize = 0;
        for (dense.data) |val| {
            if (val != 0.0) nnz += 1;
        }

        var sparse = try SparseMatrix.init(allocator, format, dense.rows, dense.cols, nnz);
        
        for (0..dense.rows) |r| {
            if (dense.sample_names[r]) |name| {
                sparse.sample_names[r] = try allocator.dupe(u8, name);
            }
        }
        for (0..dense.cols) |c| {
            if (dense.feature_names[c]) |name| {
                sparse.feature_names[c] = try allocator.dupe(u8, name);
            }
        }

        var k: usize = 0;
        if (format == .csr) {
            for (0..dense.rows) |i| {
                sparse.indptr[i] = @as(u32, @intCast(k));
                for (0..dense.cols) |j| {
                    const val = dense.get(i, j);
                    if (val != 0.0) {
                        sparse.data[k] = val;
                        sparse.indices[k] = @as(u32, @intCast(j));
                        k += 1;
                    }
                }
            }
            sparse.indptr[dense.rows] = @as(u32, @intCast(nnz));
        } else {
            for (0..dense.cols) |j| {
                sparse.indptr[j] = @as(u32, @intCast(k));
                for (0..dense.rows) |i| {
                    const val = dense.get(i, j);
                    if (val != 0.0) {
                        sparse.data[k] = val;
                        sparse.indices[k] = @as(u32, @intCast(i));
                        k += 1;
                    }
                }
            }
            sparse.indptr[dense.cols] = @as(u32, @intCast(nnz));
        }

        return sparse;
    }

    pub fn deinit(self: *SparseMatrix) void {
        for (self.sample_names) |name| {
            if (name) |n| self.allocator.free(n);
        }
        for (self.feature_names) |name| {
            if (name) |n| self.allocator.free(n);
        }
        self.allocator.free(self.sample_names);
        self.allocator.free(self.feature_names);
        self.allocator.free(self.data);
        self.allocator.free(self.indices);
        self.allocator.free(self.indptr);
    }

    pub fn get(self: SparseMatrix, row: usize, col: usize) f64 {
        std.debug.assert(row < self.rows and col < self.cols);
        
        if (self.format == .csr) {
            const start = self.indptr[row];
            const end = self.indptr[row + 1];
            
            for (self.indices[start..end], 0..) |idx, i| {
                if (idx == @as(u32, @intCast(col))) {
                    return self.data[start + i];
                }
            }
            return 0.0;
        } else {
            const start = self.indptr[col];
            const end = self.indptr[col + 1];
            
            for (self.indices[start..end], 0..) |idx, i| {
                if (idx == @as(u32, @intCast(row))) {
                    return self.data[start + i];
                }
            }
            return 0.0;
        }
    }

    pub fn serialize(self: SparseMatrix, writer: anytype) !void {
        try serialization.serialize(writer, self.format);
        try serialization.serialize(writer, self.rows);
        try serialization.serialize(writer, self.cols);
        try serialization.serialize(writer, self.sample_names);
        try serialization.serialize(writer, self.feature_names);
        try serialization.serialize(writer, self.data);
        try serialization.serialize(writer, self.indices);
        try serialization.serialize(writer, self.indptr);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !SparseMatrix {
        const format = try serialization.deserialize(reader, SparseFormat, allocator);
        const rows = try serialization.deserialize(reader, usize, allocator);
        const cols = try serialization.deserialize(reader, usize, allocator);
        const sample_names = try serialization.deserialize(reader, []?[]const u8, allocator);
        const feature_names = try serialization.deserialize(reader, []?[]const u8, allocator);
        const data = try serialization.deserialize(reader, []f64, allocator);
        const indices = try serialization.deserialize(reader, []u32, allocator);
        const indptr = try serialization.deserialize(reader, []u32, allocator);

        return .{
            .allocator = allocator,
            .format = format,
            .sample_names = sample_names,
            .feature_names = feature_names,
            .data = data,
            .indices = indices,
            .indptr = indptr,
            .rows = rows,
            .cols = cols,
        };
    }
};

test "DenseMatrix basic operations" {
    const alloc = std.testing.allocator;
    var matrix = try DenseMatrix.init(alloc, 2, 3);
    defer matrix.deinit();

    try matrix.setSampleName(0, "Cell1");
    try matrix.setFeatureName(0, "GeneA");
    matrix.set(0, 0, 1.5);
    
    try std.testing.expectEqual(@as(f64, 1.5), matrix.get(0, 0));
    try std.testing.expectEqualStrings("Cell1", matrix.sample_names[0].?);
    try std.testing.expectEqualStrings("GeneA", matrix.feature_names[0].?);
}

test "DenseMatrix serialization" {
    const alloc = std.testing.allocator;
    var matrix = try DenseMatrix.init(alloc, 2, 2);
    defer matrix.deinit();
    
    try matrix.setSampleName(0, "S1");
    try matrix.setSampleName(1, "S2");
    try matrix.setFeatureName(0, "G1");
    try matrix.setFeatureName(1, "G2");
    matrix.set(0, 0, 1.0);
    matrix.set(1, 1, 2.0);

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    
    try matrix.serialize(&writer);
    
    var reader = std.Io.Reader.fixed(writer.buffered());
    var deserialized = try DenseMatrix.deserialize(&reader, alloc);
    defer deserialized.deinit();
    
    try std.testing.expectEqual(matrix.rows, deserialized.rows);
    try std.testing.expectEqual(matrix.cols, deserialized.cols);
    try std.testing.expectEqual(matrix.get(1, 1), deserialized.get(1, 1));
    try std.testing.expectEqualStrings(matrix.sample_names[0].?, deserialized.sample_names[0].?);
}

test "SparseMatrix CSR operations" {
    const alloc = std.testing.allocator;
    var dense = try DenseMatrix.init(alloc, 3, 3);
    defer dense.deinit();
    
    dense.set(0, 0, 1.0);
    dense.set(0, 2, 2.0);
    dense.set(1, 1, 3.0);
    dense.set(2, 0, 4.0);
    dense.set(2, 2, 5.0);

    var sparse = try SparseMatrix.fromDense(alloc, dense, .csr);
    defer sparse.deinit();

    try std.testing.expectEqual(@as(f64, 1.0), sparse.get(0, 0));
    try std.testing.expectEqual(@as(f64, 0.0), sparse.get(0, 1));
    try std.testing.expectEqual(@as(f64, 2.0), sparse.get(0, 2));
    try std.testing.expectEqual(@as(f64, 3.0), sparse.get(1, 1));
    try std.testing.expectEqual(@as(f64, 4.0), sparse.get(2, 0));
    try std.testing.expectEqual(@as(f64, 5.0), sparse.get(2, 2));
    
    try std.testing.expectEqual(@as(usize, 5), sparse.data.len);
    try std.testing.expectEqual(@as(u32, 0), sparse.indptr[0]);
    try std.testing.expectEqual(@as(u32, 2), sparse.indptr[1]);
    try std.testing.expectEqual(@as(u32, 3), sparse.indptr[2]);
    try std.testing.expectEqual(@as(u32, 5), sparse.indptr[3]);
}

test "SparseMatrix CSC operations" {
    const alloc = std.testing.allocator;
    var dense = try DenseMatrix.init(alloc, 3, 3);
    defer dense.deinit();
    
    dense.set(0, 0, 1.0);
    dense.set(0, 2, 2.0);
    dense.set(1, 1, 3.0);
    dense.set(2, 0, 4.0);
    dense.set(2, 2, 5.0);

    var sparse = try SparseMatrix.fromDense(alloc, dense, .csc);
    defer sparse.deinit();

    try std.testing.expectEqual(@as(f64, 1.0), sparse.get(0, 0));
    try std.testing.expectEqual(@as(f64, 0.0), sparse.get(0, 1));
    try std.testing.expectEqual(@as(f64, 2.0), sparse.get(0, 2));
    try std.testing.expectEqual(@as(f64, 3.0), sparse.get(1, 1));
    try std.testing.expectEqual(@as(f64, 4.0), sparse.get(2, 0));
    try std.testing.expectEqual(@as(f64, 5.0), sparse.get(2, 2));
    
    try std.testing.expectEqual(@as(usize, 5), sparse.data.len);
    try std.testing.expectEqual(@as(u32, 0), sparse.indptr[0]);
    try std.testing.expectEqual(@as(u32, 2), sparse.indptr[1]);
    try std.testing.expectEqual(@as(u32, 3), sparse.indptr[2]);
    try std.testing.expectEqual(@as(u32, 5), sparse.indptr[3]);
}
