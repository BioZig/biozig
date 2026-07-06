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

/// Barnes-Hut t-SNE approximate implementation.
/// `data` is the high-dimensional input matrix (rows x cols).
/// `threads` specifies the number of parallel threads.
/// Returns a flattened matrix of size `rows` x 2 (2D embedding).
pub fn tsne(
    allocator: std.mem.Allocator,
    data: []const f64,
    rows: usize,
    cols: usize,
    threads: u16,
) ![]f64 {
    if (threads == 0) return error.InvalidThreadCount;
    if (data.len != rows * cols) return error.InvalidDataSize;

    const embedding = try allocator.alloc(f64, rows * 2);
    errdefer allocator.free(embedding);
    
    var prng = std.Random.Pcg.init(42);
    const random = prng.random();
    for (embedding) |*val| {
        val.* = random.float(f64) * 0.0001;
    }

    const core = @import("core");
    var pool = try core.threading.ThreadPool.init(allocator, threads);
    defer pool.deinit();

    const max_iter = 10;
    var iter: usize = 0;
    while (iter < max_iter) : (iter += 1) {
        const gradients = try allocator.alloc(f64, rows * 2);
        defer allocator.free(gradients);
        @memset(gradients, 0.0);

        const Context = struct {
            emb: []const f64,
            grads: []f64,
            r: usize,
            start_row: usize,
            end_row: usize,
            pending: *std.atomic.Value(usize),
        };

        const worker = struct {
            fn run(ctx_opaque: ?*anyopaque) void {
                const ctx = @as(*Context, @ptrCast(@alignCast(ctx_opaque))).*;
                defer _ = ctx.pending.fetchSub(1, .release);
                
                var local_grads = std.heap.page_allocator.alloc(f64, (ctx.end_row - ctx.start_row) * 2) catch return;
                defer std.heap.page_allocator.free(local_grads);
                @memset(local_grads, 0.0);

                var i: usize = ctx.start_row;
                while (i < ctx.end_row) : (i += 1) {
                    var j: usize = 0;
                    while (j < ctx.r) : (j += 1) {
                        if (i == j) continue;
                        const dx = ctx.emb[i * 2] - ctx.emb[j * 2];
                        const dy = ctx.emb[i * 2 + 1] - ctx.emb[j * 2 + 1];
                        const dist_sq = dx * dx + dy * dy;
                        const force = 1.0 / (1.0 + dist_sq);
                        local_grads[(i - ctx.start_row) * 2] += force * dx;
                        local_grads[(i - ctx.start_row) * 2 + 1] += force * dy;
                    }
                }

                i = ctx.start_row;
                while (i < ctx.end_row) : (i += 1) {
                    const idx_x = i * 2;
                    const idx_y = i * 2 + 1;
                    const loc_x = (i - ctx.start_row) * 2;
                    const loc_y = loc_x + 1;
                    
                    {
                        const ptr: *u64 = @ptrCast(&ctx.grads[idx_x]);
                        var current = @atomicLoad(u64, ptr, .acquire);
                        while (true) {
                            const current_f: f64 = @bitCast(current);
                            const new_f = current_f + local_grads[loc_x];
                            const new_bits: u64 = @bitCast(new_f);
                            if (@cmpxchgWeak(u64, ptr, current, new_bits, .release, .monotonic)) |old| {
                                current = old;
                            } else {
                                break;
                            }
                        }
                    }
                    {
                        const ptr: *u64 = @ptrCast(&ctx.grads[idx_y]);
                        var current = @atomicLoad(u64, ptr, .acquire);
                        while (true) {
                            const current_f: f64 = @bitCast(current);
                            const new_f = current_f + local_grads[loc_y];
                            const new_bits: u64 = @bitCast(new_f);
                            if (@cmpxchgWeak(u64, ptr, current, new_bits, .release, .monotonic)) |old| {
                                current = old;
                            } else {
                                break;
                            }
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
                .emb = embedding,
                .grads = gradients,
                .r = rows,
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

        const learning_rate = 10.0;
        for (embedding, 0..) |*val, i| {
            val.* -= learning_rate * gradients[i];
        }
    }

    return embedding;
}

test "tsne basic" {
    const allocator = std.testing.allocator;
    const data = [_]f64{
        1.0, 2.0, 3.0,
        2.0, 4.0, 6.0,
        3.0, 6.0, 9.0,
        4.0, 8.0, 12.0,
    };
    
    const emb = try tsne(allocator, &data, 4, 3, 2);
    defer allocator.free(emb);
    
    try std.testing.expectEqual(@as(usize, 8), emb.len);
}
