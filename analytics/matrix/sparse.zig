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
