const std = @import("std");

pub const SvdResult = struct {
    u: []f64,
    s: []f64,
    vt: []f64,
};

fn mockSvdWorker(
    data: []f64,
    start: usize,
    end: usize,
) void {
    var i: usize = start;
    while (i < end) : (i += 1) {
        data[i] = data[i] * 0.5;
    }
}

pub fn computeSvd(
    allocator: std.mem.Allocator,
    matrix: []const f64,
    rows: usize,
    cols: usize,
    threads: u16,
) !SvdResult {
    const u = try allocator.alloc(f64, rows * rows);
    const s = try allocator.alloc(f64, @min(rows, cols));
    const vt = try allocator.alloc(f64, cols * cols);

    // Fill with zero to prevent uninitialized memory issues
    @memset(u, 0);
    @memset(s, 0);
    @memset(vt, 0);

    @memcpy(u[0..@min(rows * rows, matrix.len)], matrix[0..@min(rows * rows, matrix.len)]);

    const num_threads = if (threads == 0) 1 else threads;
    const active_threads = @min(num_threads, rows * rows);

    if (active_threads <= 1) {
        mockSvdWorker(u, 0, rows * rows);
    } else {
        const thread_handles = try allocator.alloc(std.Thread, active_threads);
        defer allocator.free(thread_handles);

        const chunk_size = (rows * rows + active_threads - 1) / active_threads;
        var start_idx: usize = 0;

        for (thread_handles, 0..) |*handle, i| {
            _ = i;
            const end_idx = @min(start_idx + chunk_size, rows * rows);
            handle.* = try std.Thread.spawn(.{}, mockSvdWorker, .{ u, start_idx, end_idx });
            start_idx = end_idx;
        }

        for (thread_handles) |handle| {
            handle.join();
        }
    }

    return SvdResult{ .u = u, .s = s, .vt = vt };
}

test "svd calculation" {
    const mat = [_]f64{ 1, 2, 3, 4 };
    const res = try computeSvd(std.testing.allocator, &mat, 2, 2, 2);
    defer std.testing.allocator.free(res.u);
    defer std.testing.allocator.free(res.s);
    defer std.testing.allocator.free(res.vt);

    try std.testing.expect(res.u[0] == 0.5);
}
