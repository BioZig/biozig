const std = @import("std");
const core = @import("core");
const numerics = core.numerics;
const descriptive = @import("descriptive.zig");

/// Result of a correlation calculation including significance.
pub const CorrelationResult = struct {
    coefficient: f64,
    p_value: f64,
};

fn atomicAddF64(ptr: *f64, val: f64) void {
    const u64_ptr: *u64 = @ptrCast(ptr);
    var current = @atomicLoad(u64, u64_ptr, .acquire);
    while (true) {
        const current_f: f64 = @bitCast(current);
        const new_f = current_f + val;
        const new_bits: u64 = @bitCast(new_f);
        if (@cmpxchgWeak(u64, u64_ptr, current, new_bits, .release, .monotonic)) |old| {
            current = old;
        } else {
            break;
        }
    }
}

const PearsonCtx1 = struct {
    x: []const f64,
    y: []const f64,
    start: usize,
    end: usize,
    sx: *f64,
    sy: *f64,
    pending: *std.atomic.Value(usize),
    fn run(ctx_opaque: ?*anyopaque) void {
        const ctx = @as(*PearsonCtx1, @ptrCast(@alignCast(ctx_opaque))).*;
        defer _ = ctx.pending.fetchSub(1, .release);
        const VLen = 8;
        const V = @Vector(VLen, f64);
        var sx_v: V = @splat(0.0);
        var sy_v: V = @splat(0.0);
        var i = ctx.start;
        while (i + VLen <= ctx.end) : (i += VLen) {
            sx_v += ctx.x[i .. i + VLen][0..VLen].*;
            sy_v += ctx.y[i .. i + VLen][0..VLen].*;
        }
        var lsx: f64 = @reduce(.Add, sx_v);
        var lsy: f64 = @reduce(.Add, sy_v);
        while (i < ctx.end) : (i += 1) {
            lsx += ctx.x[i];
            lsy += ctx.y[i];
        }
        atomicAddF64(ctx.sx, lsx);
        atomicAddF64(ctx.sy, lsy);
    }
};

const PearsonCtx2 = struct {
    x: []const f64,
    y: []const f64,
    start: usize,
    end: usize,
    mx: f64,
    my: f64,
    cov: *f64,
    vx: *f64,
    vy: *f64,
    pending: *std.atomic.Value(usize),
    fn run(ctx_opaque: ?*anyopaque) void {
        const ctx = @as(*PearsonCtx2, @ptrCast(@alignCast(ctx_opaque))).*;
        defer _ = ctx.pending.fetchSub(1, .release);
        const VLen = 8;
        const V = @Vector(VLen, f64);
        var cov_v: V = @splat(0.0);
        var vx_v: V = @splat(0.0);
        var vy_v: V = @splat(0.0);
        const mx_v: V = @splat(ctx.mx);
        const my_v: V = @splat(ctx.my);
        var i = ctx.start;
        while (i + VLen <= ctx.end) : (i += VLen) {
            const dx = ctx.x[i .. i + VLen][0..VLen].* - mx_v;
            const dy = ctx.y[i .. i + VLen][0..VLen].* - my_v;
            cov_v += dx * dy;
            vx_v += dx * dx;
            vy_v += dy * dy;
        }
        var lcov: f64 = @reduce(.Add, cov_v);
        var lvx: f64 = @reduce(.Add, vx_v);
        var lvy: f64 = @reduce(.Add, vy_v);
        while (i < ctx.end) : (i += 1) {
            const dx = ctx.x[i] - ctx.mx;
            const dy = ctx.y[i] - ctx.my;
            lcov += dx * dy;
            lvx += dx * dx;
            lvy += dy * dy;
        }
        atomicAddF64(ctx.cov, lcov);
        atomicAddF64(ctx.vx, lvx);
        atomicAddF64(ctx.vy, lvy);
    }
};

/// Computes Pearson correlation coefficient.
pub fn pearson(allocator_opt: ?std.mem.Allocator, x: []const f64, y: []const f64) !CorrelationResult {
    std.debug.assert(x.len == y.len);
    if (x.len < 2) return .{ .coefficient = 0.0, .p_value = 1.0 };
    const n = x.len;
    const nf = @as(f64, @floatFromInt(n));
    const cpu_count = std.Thread.getCpuCount() catch 1;

    if (allocator_opt == null or cpu_count <= 1 or n < 10000) {
        // Fallback to single-threaded
        const VLen = 8;
        const V = @Vector(VLen, f64);
        var sum_x_v: V = @splat(0.0);
        var sum_y_v: V = @splat(0.0);
        var i: usize = 0;
        while (i + VLen <= n) : (i += VLen) {
            sum_x_v += x[i .. i + VLen][0..VLen].*;
            sum_y_v += y[i .. i + VLen][0..VLen].*;
        }
        var sum_x: f64 = @reduce(.Add, sum_x_v);
        var sum_y: f64 = @reduce(.Add, sum_y_v);
        while (i < n) : (i += 1) {
            sum_x += x[i];
            sum_y += y[i];
        }
        const mean_x = sum_x / nf;
        const mean_y = sum_y / nf;

        var cov_v: V = @splat(0.0);
        var var_x_v: V = @splat(0.0);
        var var_y_v: V = @splat(0.0);
        const mean_x_v: V = @splat(mean_x);
        const mean_y_v: V = @splat(mean_y);
        i = 0;
        while (i + VLen <= n) : (i += VLen) {
            const dx = x[i .. i + VLen][0..VLen].* - mean_x_v;
            const dy = y[i .. i + VLen][0..VLen].* - mean_y_v;
            cov_v += dx * dy;
            var_x_v += dx * dx;
            var_y_v += dy * dy;
        }
        var cov: f64 = @reduce(.Add, cov_v);
        var var_x: f64 = @reduce(.Add, var_x_v);
        var var_y: f64 = @reduce(.Add, var_y_v);
        while (i < n) : (i += 1) {
            const dx = x[i] - mean_x;
            const dy = y[i] - mean_y;
            cov += dx * dy;
            var_x += dx * dx;
            var_y += dy * dy;
        }
        if (var_x == 0.0 or var_y == 0.0) return .{ .coefficient = 0.0, .p_value = 1.0 };
        const r = cov / @sqrt(var_x * var_y);
        const t = @abs(r) * @sqrt((nf - 2.0) / (1.0 - r * r));
        const p = @import("hypothesis.zig").tPValue(t, nf - 2.0);
        return .{ .coefficient = r, .p_value = p };
    }

    const allocator = allocator_opt.?;
    var pool = try core.threading.ThreadPool.init(allocator, cpu_count);
    defer pool.deinit();

    var sum_x: f64 = 0;
    var sum_y: f64 = 0;
    var pending1 = std.atomic.Value(usize).init(cpu_count);
    var ctxs1 = try allocator.alloc(PearsonCtx1, cpu_count);
    defer allocator.free(ctxs1);
    var tasks1 = try allocator.alloc(core.threading.Task, cpu_count);
    defer allocator.free(tasks1);

    const chunk_size = (n + cpu_count - 1) / cpu_count;
    for (0..cpu_count) |t| {
        const start = t * chunk_size;
        var end = start + chunk_size;
        if (end > n) end = n;
        if (start >= n) end = start;
        ctxs1[t] = .{ .x = x, .y = y, .start = start, .end = end, .sx = &sum_x, .sy = &sum_y, .pending = &pending1 };
        tasks1[t] = .{ .run = PearsonCtx1.run, .ctx = &ctxs1[t] };
        pool.spawnTask(&tasks1[t]);
    }
    while (pending1.load(.acquire) > 0) std.Thread.yield() catch {};

    const mean_x = sum_x / nf;
    const mean_y = sum_y / nf;

    var cov: f64 = 0;
    var var_x: f64 = 0;
    var var_y: f64 = 0;
    var pending2 = std.atomic.Value(usize).init(cpu_count);
    var ctxs2 = try allocator.alloc(PearsonCtx2, cpu_count);
    defer allocator.free(ctxs2);
    var tasks2 = try allocator.alloc(core.threading.Task, cpu_count);
    defer allocator.free(tasks2);

    for (0..cpu_count) |t| {
        const start = t * chunk_size;
        var end = start + chunk_size;
        if (end > n) end = n;
        if (start >= n) end = start;
        ctxs2[t] = .{ .x = x, .y = y, .start = start, .end = end, .mx = mean_x, .my = mean_y, .cov = &cov, .vx = &var_x, .vy = &var_y, .pending = &pending2 };
        tasks2[t] = .{ .run = PearsonCtx2.run, .ctx = &ctxs2[t] };
        pool.spawnTask(&tasks2[t]);
    }
    while (pending2.load(.acquire) > 0) std.Thread.yield() catch {};

    if (var_x == 0.0 or var_y == 0.0) return .{ .coefficient = 0.0, .p_value = 1.0 };
    const r = cov / @sqrt(var_x * var_y);
    const t = @abs(r) * @sqrt((nf - 2.0) / (1.0 - r * r));
    const p = @import("hypothesis.zig").tPValue(t, nf - 2.0);
    return .{ .coefficient = r, .p_value = p };
}

/// Computes Spearman's rank correlation coefficient.
pub fn spearman(x: []const f64, y: []const f64, allocator: std.mem.Allocator) !CorrelationResult {
    std.debug.assert(x.len == y.len);
    if (x.len < 2) return .{ .coefficient = 0.0, .p_value = 1.0 };

    const rx = try rank(x, allocator);
    defer allocator.free(rx);
    const ry = try rank(y, allocator);
    defer allocator.free(ry);

    return try pearson(allocator, rx, ry);
}

const KendallCtx = struct {
    x: []const f64,
    y: []const f64,
    start_i: usize,
    end_i: usize,
    n: usize,
    conc: *std.atomic.Value(usize),
    disc: *std.atomic.Value(usize),
    pending: *std.atomic.Value(usize),
    fn run(ctx_opaque: ?*anyopaque) void {
        const ctx = @as(*KendallCtx, @ptrCast(@alignCast(ctx_opaque))).*;
        defer _ = ctx.pending.fetchSub(1, .release);
        var lc: usize = 0;
        var ld: usize = 0;
        for (ctx.start_i..ctx.end_i) |i| {
            for (i + 1..ctx.n) |j| {
                const x_diff = ctx.x[i] - ctx.x[j];
                const y_diff = ctx.y[i] - ctx.y[j];
                const product = x_diff * y_diff;
                if (product > 0) lc += 1 else if (product < 0) ld += 1;
            }
        }
        _ = ctx.conc.fetchAdd(lc, .monotonic);
        _ = ctx.disc.fetchAdd(ld, .monotonic);
    }
};

/// Computes Kendall Tau rank correlation.
pub fn kendallTau(allocator_opt: ?std.mem.Allocator, x: []const f64, y: []const f64) !CorrelationResult {
    std.debug.assert(x.len == y.len);
    if (x.len < 2) return .{ .coefficient = 0.0, .p_value = 1.0 };
    const n = x.len;
    const cpu_count = std.Thread.getCpuCount() catch 1;

    var concordant: usize = 0;
    var discordant: usize = 0;

    if (allocator_opt == null or cpu_count <= 1 or n < 1000) {
        for (0..n) |i| {
            for (i + 1..n) |j| {
                const x_diff = x[i] - x[j];
                const y_diff = y[i] - y[j];
                const product = x_diff * y_diff;
                if (product > 0) concordant += 1 else if (product < 0) discordant += 1;
            }
        }
    } else {
        const allocator = allocator_opt.?;
        var pool = try core.threading.ThreadPool.init(allocator, cpu_count);
        defer pool.deinit();

        var conc = std.atomic.Value(usize).init(0);
        var disc = std.atomic.Value(usize).init(0);
        var pending = std.atomic.Value(usize).init(cpu_count);

        var ctxs = try allocator.alloc(KendallCtx, cpu_count);
        defer allocator.free(ctxs);
        var tasks = try allocator.alloc(core.threading.Task, cpu_count);
        defer allocator.free(tasks);

        const chunk_size = (n + cpu_count - 1) / cpu_count;
        for (0..cpu_count) |t| {
            const start = t * chunk_size;
            var end = start + chunk_size;
            if (end > n) end = n;
            if (start >= n) end = start;
            ctxs[t] = .{ .x = x, .y = y, .start_i = start, .end_i = end, .n = n, .conc = &conc, .disc = &disc, .pending = &pending };
            tasks[t] = .{ .run = KendallCtx.run, .ctx = &ctxs[t] };
            pool.spawnTask(&tasks[t]);
        }
        while (pending.load(.acquire) > 0) std.Thread.yield() catch {};
        concordant = conc.load(.acquire);
        discordant = disc.load(.acquire);
    }

    const n_f = @as(f64, @floatFromInt(n));
    const denominator = n_f * (n_f - 1.0) / 2.0;
    const tau = @as(f64, @floatFromInt(concordant)) / denominator - @as(f64, @floatFromInt(discordant)) / denominator;

    // Significance (Normal approximation for large n)
    const z = tau / @sqrt((2.0 * (2.0 * n_f + 5.0)) / (9.0 * n_f * (n_f - 1.0)));
    const p = 2.0 * (1.0 - (@import("distributions.zig").Normal{ .mu = 0.0, .sigma = 1.0 }).cdf(@abs(z)));
    return .{ .coefficient = tau, .p_value = p };
}

/// Helper function to compute ranks of a slice.
fn rank(slice: []const f64, allocator: std.mem.Allocator) ![]f64 {
    const Item = struct {
        val: f64,
        orig_idx: usize,
    };
    var items = try allocator.alloc(Item, slice.len);
    defer allocator.free(items);

    for (0..slice.len) |i| {
        items[i] = .{ .val = slice[i], .orig_idx = i };
    }

    std.sort.block(Item, items, {}, struct {
        fn lessThan(_: void, a: Item, b: Item) bool {
            return a.val < b.val;
        }
    }.lessThan);

    var ranks = try allocator.alloc(f64, slice.len);
    var i: usize = 0;
    while (i < slice.len) {
        var j = i + 1;
        while (j < slice.len and items[j].val == items[i].val) {
            j += 1;
        }

        // Average rank for ties
        const avg_rank = @as(f64, @floatFromInt(i + j + 1)) / 2.0;
        for (i..j) |k| {
            ranks[items[k].orig_idx] = avg_rank;
        }
        i = j;
    }
    return ranks;
}

test "pearson correlation" {
    const x = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const y = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const res = try pearson(null, &x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), res.coefficient, 1e-10);
}

test "spearman correlation" {
    const x = [_]f64{ 10.0, 20.0, 30.0, 40.0, 50.0 };
    const y = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const res = try spearman(&x, &y, std.testing.allocator);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), res.coefficient, 1e-10);
}

test "kendall tau correlation" {
    const x = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const y = [_]f64{ 5.0, 4.0, 3.0, 2.0, 1.0 };
    const res = try kendallTau(null, &x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, -1.0), res.coefficient, 1e-10);
}
