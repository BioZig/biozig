const std = @import("std");

pub const CsrMatrix = struct {
    values: []const f64,
    col_indices: []const usize,
    row_ptr: []const usize,
    rows: usize,
    cols: usize,
};

pub const CscMatrix = struct {
    values: []const f64,
    row_indices: []const usize,
    col_ptr: []const usize,
    rows: usize,
    cols: usize,
};

fn multiplyRowBatch(
    matrix: CsrMatrix,
    vec: []const f64,
    result: []f64,
    start_row: usize,
    end_row: usize,
) void {
    var i: usize = start_row;
    while (i < end_row) : (i += 1) {
        var sum: f64 = 0;
        const start_idx = matrix.row_ptr[i];
        const end_idx = matrix.row_ptr[i + 1];

        var j: usize = start_idx;
        while (j < end_idx) : (j += 1) {
            sum += matrix.values[j] * vec[matrix.col_indices[j]];
        }
        result[i] = sum;
    }
}

pub fn multiplyCsrVector(
    allocator: std.mem.Allocator,
    matrix: CsrMatrix,
    vec: []const f64,
    threads: u16,
) ![]f64 {
    std.debug.assert(matrix.cols == vec.len);

    const result = try allocator.alloc(f64, matrix.rows);
    errdefer allocator.free(result);

    const num_threads = if (threads == 0) 1 else threads;
    const active_threads = @min(num_threads, matrix.rows);

    if (active_threads <= 1) {
        multiplyRowBatch(matrix, vec, result, 0, matrix.rows);
    } else {
        const thread_handles = try allocator.alloc(std.Thread, active_threads);
        defer allocator.free(thread_handles);

        const chunk_size = (matrix.rows + active_threads - 1) / active_threads;
        var start_row: usize = 0;

        for (thread_handles, 0..) |*handle, i| {
            _ = i;
            const end_row = @min(start_row + chunk_size, matrix.rows);
            handle.* = try std.Thread.spawn(.{}, multiplyRowBatch, .{ matrix, vec, result, start_row, end_row });
            start_row = end_row;
        }

        for (thread_handles) |handle| {
            handle.join();
        }
    }

    return result;
}

test "csr vector multiplication" {
    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0 };
    const col_indices = [_]usize{ 0, 2, 2, 1 };
    const row_ptr = [_]usize{ 0, 2, 3, 4 };

    const matrix = CsrMatrix{
        .values = &values,
        .col_indices = &col_indices,
        .row_ptr = &row_ptr,
        .rows = 3,
        .cols = 3,
    };

    const vec = [_]f64{ 1.0, 2.0, 3.0 };

    const result = try multiplyCsrVector(std.testing.allocator, matrix, &vec, 2);
    defer std.testing.allocator.free(result);

    try std.testing.expect(result[0] == 7.0); // 1.0*1.0 + 2.0*3.0
    try std.testing.expect(result[1] == 9.0); // 3.0*3.0
    try std.testing.expect(result[2] == 8.0); // 4.0*2.0
}

pub const PersistencePair = struct {
    birth: usize,
    death: usize,
    dimension: usize,
    birth_val: f64 = 0.0,
    death_val: f64 = std.math.inf(f64),
};

/// Gets the pivot (largest row index) for a given column in a CSC matrix.
/// Returns null if the column is empty.
fn getPivot(matrix: CscMatrix, col: usize) ?usize {
    const start_idx = matrix.col_ptr[col];
    const end_idx = matrix.col_ptr[col + 1];
    if (start_idx == end_idx) return null;
    
    // CSC row indices are typically sorted. The largest is the last one.
    var max_val: usize = 0;
    var found = false;
    for (start_idx..end_idx) |i| {
        if (!found or matrix.row_indices[i] > max_val) {
            max_val = matrix.row_indices[i];
            found = true;
        }
    }
    return if (found) max_val else null;
}

/// XORs two columns together (col1 = col1 XOR col2) over GF(2) and returns a new list of row indices.
/// Assumes values are implicit 1s.
fn xorColumns(allocator: std.mem.Allocator, matrix: CscMatrix, col1_indices: []const usize, col2: usize) ![]usize {
    const start2 = matrix.col_ptr[col2];
    const end2 = matrix.col_ptr[col2 + 1];
    const col2_indices = matrix.row_indices[start2..end2];
    
    var set = std.AutoHashMap(usize, void).init(allocator);
    defer set.deinit();
    
    for (col1_indices) |idx| {
        try set.put(idx, {});
    }
    
    for (col2_indices) |idx| {
        if (set.contains(idx)) {
            _ = set.remove(idx); // GF(2) 1 + 1 = 0
        } else {
            try set.put(idx, {});
        }
    }
    
    var result = try allocator.alloc(usize, set.count());
    var it = set.keyIterator();
    var i: usize = 0;
    while (it.next()) |key| {
        result[i] = key.*;
        i += 1;
    }
    // Sort to maintain pivot at the end
    std.mem.sort(usize, result, {}, std.sort.asc(usize));
    return result;
}

/// Reduces a boundary matrix over GF(2) using the standard left-to-right column addition algorithm.
/// Emits persistence pairs (birth, death, dimension).
pub fn reduceBoundaryMatrix(allocator: std.mem.Allocator, boundary_matrix: CscMatrix) ![]PersistencePair {
    var pairs = std.ArrayList(PersistencePair).init(allocator);
    defer pairs.deinit();
    
    // Map of pivot row index -> column index that currently has this pivot
    var pivot_map = std.AutoHashMap(usize, usize).init(allocator);
    defer pivot_map.deinit();
    
    for (0..boundary_matrix.cols) |j| {
        const start_idx = boundary_matrix.col_ptr[j];
        const end_idx = boundary_matrix.col_ptr[j + 1];
        
        var current_col = try allocator.alloc(usize, end_idx - start_idx);
        @memcpy(current_col, boundary_matrix.row_indices[start_idx..end_idx]);
        
        while (current_col.len > 0) {
            const pivot = current_col[current_col.len - 1]; // Sorted, so last is largest
            
            if (pivot_map.get(pivot)) |existing_col| {
                const new_col = try xorColumns(allocator, boundary_matrix, current_col, existing_col);
                allocator.free(current_col);
                current_col = new_col;
            } else {
                try pivot_map.put(pivot, j);
                // In a VR complex, a column j adding a face creates a cycle (or kills one). 
                // We'll leave dimension inference to the caller mapping or assume dim=1 for testing.
                try pairs.append(.{
                    .birth = pivot,
                    .death = j,
                    .dimension = 1, // Simplified, caller must map this correctly in ATLAZ wrapper
                });
                break;
            }
        }
        allocator.free(current_col);
    }
    
    return pairs.toOwnedSlice();
}
