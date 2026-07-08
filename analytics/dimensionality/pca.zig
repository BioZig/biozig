const std = @import("std");

const SpinLock = struct {
    v: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    pub fn lock(self: *@This()) void {
        while (self.v.swap(true, .acquire)) {}
    }
    pub fn unlock(self: *@This()) void {
        self.v.store(false, .release);
    }
};

/// Computes the first `n_components` principal components using the power iteration method.
/// `data` is a flattened row-major matrix of size `rows` x `cols`.
/// `threads` specifies the number of threads to use for parallel operations.
/// Returns a flattened matrix of size `cols` x `n_components` containing the principal components.
pub fn pca(
    allocator: std.mem.Allocator,
    data: []const f64,
    rows: usize,
    cols: usize,
    n_components: usize,
    threads: u16,
) ![]f64 {
    if (threads == 0) return error.InvalidThreadCount;
    if (data.len != rows * cols) return error.InvalidDataSize;
    if (n_components == 0 or n_components > cols) return error.InvalidComponentCount;

    var components = try allocator.alloc(f64, cols * n_components);
    errdefer allocator.free(components);
    const core = @import("core");
    var pool = try core.threading.ThreadPool.init(allocator, threads);
    defer pool.deinit();

    var current_comp: usize = 0;
    while (current_comp < n_components) : (current_comp += 1) {
        var v = try allocator.alloc(f64, cols);
        defer allocator.free(v);

        for (v, 0..) |*val, i| {
            val.* = @as(f64, @floatFromInt(i % 3)) - 1.0;
        }

        var v_norm: f64 = 0;
        for (v) |val| v_norm += val * val;
        v_norm = @sqrt(v_norm);
        if (v_norm > 0) {
            for (v) |*val| val.* /= v_norm;
        } else {
            v[0] = 1.0;
        }

        var iter: usize = 0;
        const max_iter = 100;
        while (iter < max_iter) : (iter += 1) {
            var next_v = try allocator.alloc(f64, cols);
            defer allocator.free(next_v);
            @memset(next_v, 0.0);

            const Context = struct {
                data_slice: []const f64,
                v: []const f64,
                next_v: []f64,
                r: usize,
                c: usize,
                start_row: usize,
                end_row: usize,
                pending: *std.atomic.Value(usize),
            };

            const worker = struct {
                fn run(ctx_opaque: ?*anyopaque) void {
                    const ctx = @as(*Context, @ptrCast(@alignCast(ctx_opaque))).*;
                    defer _ = ctx.pending.fetchSub(1, .release);
                    var local_next_v = std.heap.page_allocator.alloc(f64, ctx.c) catch return;
                    defer std.heap.page_allocator.free(local_next_v);
                    @memset(local_next_v, 0.0);

                    var i: usize = ctx.start_row;
                    while (i < ctx.end_row) : (i += 1) {
                        var dot: f64 = 0;
                        var j: usize = 0;
                        while (j < ctx.c) : (j += 1) {
                            dot += ctx.data_slice[i * ctx.c + j] * ctx.v[j];
                        }
                        j = 0;
                        while (j < ctx.c) : (j += 1) {
                            local_next_v[j] += ctx.data_slice[i * ctx.c + j] * dot;
                        }
                    }

                    var j: usize = 0;
                    while (j < ctx.c) : (j += 1) {
                        const ptr: *u64 = @ptrCast(&ctx.next_v[j]);
                        var current = @atomicLoad(u64, ptr, .acquire);
                        while (true) {
                            const current_f: f64 = @bitCast(current);
                            const new_f = current_f + local_next_v[j];
                            const new_bits: u64 = @bitCast(new_f);
                            if (@cmpxchgWeak(u64, ptr, current, new_bits, .release, .monotonic)) |old| {
                                current = old;
                            } else {
                                break;
                            }
                        }
                    }
                }
            };

            var pending = std.atomic.Value(usize).init(threads);
            var contexts = try allocator.alloc(Context, threads);
            defer allocator.free(contexts);
            var tasks = try allocator.alloc(core.threading.Task, threads);
            defer allocator.free(tasks);

            const rows_per_thread = (rows + threads - 1) / threads;
            var t: usize = 0;
            while (t < threads) : (t += 1) {
                const start = t * rows_per_thread;
                var end = start + rows_per_thread;
                if (end > rows) end = rows;
                if (start >= rows) end = start;

                contexts[t] = Context{
                    .data_slice = data,
                    .v = v,
                    .next_v = next_v,
                    .r = rows,
                    .c = cols,
                    .start_row = start,
                    .end_row = end,
                    .pending = &pending,
                };
                tasks[t] = core.threading.Task{
                    .run = worker.run,
                    .ctx = &contexts[t],
                };
                pool.spawnTask(&tasks[t]);
            }

            while (pending.load(.acquire) > 0) {
                std.Thread.yield() catch {};
            }

            var prev_comp: usize = 0;
            while (prev_comp < current_comp) : (prev_comp += 1) {
                var dot: f64 = 0;
                var j: usize = 0;
                while (j < cols) : (j += 1) {
                    dot += next_v[j] * components[j * n_components + prev_comp];
                }
                j = 0;
                while (j < cols) : (j += 1) {
                    next_v[j] -= dot * components[j * n_components + prev_comp];
                }
            }

            var norm: f64 = 0;
            for (next_v) |val| norm += val * val;
            norm = @sqrt(norm);
            if (norm > 1e-12) {
                for (next_v) |*val| val.* /= norm;
            }

            var diff: f64 = 0;
            for (v, 0..) |val, j| diff += @abs(val - next_v[j]);
            @memcpy(v, next_v);
            if (diff < 1e-6) break;
        }

        var j: usize = 0;
        while (j < cols) : (j += 1) {
            components[j * n_components + current_comp] = v[j];
        }
    }

    return components;
}

test "pca basic" {
    const allocator = std.testing.allocator;
    const data = [_]f64{
        1.0, 2.0, 3.0,
        2.0, 4.0, 6.0,
        3.0, 6.0, 9.0,
        4.0, 8.0, 12.0,
    };

    const comps = try pca(allocator, &data, 4, 3, 1, 2);
    defer allocator.free(comps);

    try std.testing.expectEqual(@as(usize, 3), comps.len);
    const norm = @sqrt(1.0 + 4.0 + 9.0);
    try std.testing.expectApproxEqAbs(comps[0], 1.0 / norm, 1e-4);
}

pub const BackboneStats = struct {
    total_atoms: usize,
    ca_atoms: usize,
};

pub fn streamingPcaBackbone(iterator: anytype) !BackboneStats {
    var stats = BackboneStats{ .total_atoms = 0, .ca_atoms = 0 };
    while (try iterator.nextLine()) |line| {
        if (std.mem.startsWith(u8, line, "ATOM  ") or std.mem.startsWith(u8, line, "HETATM")) {
            stats.total_atoms += 1;
            if (line.len >= 16) {
                if (std.mem.eql(u8, line[13..15], "CA")) {
                    stats.ca_atoms += 1;
                }
            }
        }
    }
    return stats;
}
