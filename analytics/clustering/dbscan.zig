const std = @import("std");

pub const DBSCANResult = struct {
    labels: []isize, // -1 for noise, >= 0 for clusters

    pub fn deinit(self: DBSCANResult, allocator: std.mem.Allocator) void {
        allocator.free(self.labels);
    }
};

fn distance(a: []const f64, b: []const f64) f64 {
    var sum: f64 = 0.0;
    for (a, b) |va, vb| {
        const diff = va - vb;
        sum += diff * diff;
    }
    return sum; // squared euclidean
}

const NeighborsContext = struct {
    data: []const f64,
    dim: usize,
    eps_sq: f64,
    start_idx: usize,
    end_idx: usize,
    neighbors: [][]usize,
    allocator: std.mem.Allocator,
};

fn findNeighborsWorker(ctx: NeighborsContext) void {
    const num_points = ctx.data.len / ctx.dim;
    var i: usize = ctx.start_idx;

    while (i < ctx.end_idx) : (i += 1) {
        const p_i = ctx.data[i * ctx.dim .. (i + 1) * ctx.dim];
        var list = std.ArrayList(usize).empty;

        var j: usize = 0;
        while (j < num_points) : (j += 1) {
            const p_j = ctx.data[j * ctx.dim .. (j + 1) * ctx.dim];
            if (distance(p_i, p_j) <= ctx.eps_sq) {
                list.append(ctx.allocator, j) catch {}; // Ignore OOM in thread for simplicity in this example
            }
        }
        ctx.neighbors[i] = list.toOwnedSlice(ctx.allocator) catch &[_]usize{};
    }
}

pub fn dbscan(allocator: std.mem.Allocator, data: []const f64, dim: usize, eps: f64, min_pts: usize, threads: u16) !DBSCANResult {
    const num_points = data.len / dim;
    if (threads == 0) return error.InvalidThreadCount;

    const labels = try allocator.alloc(isize, num_points);
    errdefer allocator.free(labels);
    @memset(labels, -2); // -2 means unvisited

    const neighbors = try allocator.alloc([]usize, num_points);
    defer {
        for (neighbors) |n| {
            allocator.free(n);
        }
        allocator.free(neighbors);
    }

    const eps_sq = eps * eps;
    const thread_pool = try allocator.alloc(std.Thread, threads);
    defer allocator.free(thread_pool);

    const chunk_size = (num_points + threads - 1) / threads;
    var t: usize = 0;
    while (t < threads) : (t += 1) {
        const start = t * chunk_size;
        const end = @min(start + chunk_size, num_points);

        if (start >= end) {
            thread_pool[t] = try std.Thread.spawn(.{}, findNeighborsWorker, .{NeighborsContext{
                .data = data,
                .dim = dim,
                .eps_sq = eps_sq,
                .start_idx = 0,
                .end_idx = 0,
                .neighbors = neighbors,
                .allocator = allocator,
            }});
            continue;
        }

        thread_pool[t] = try std.Thread.spawn(.{}, findNeighborsWorker, .{NeighborsContext{
            .data = data,
            .dim = dim,
            .eps_sq = eps_sq,
            .start_idx = start,
            .end_idx = end,
            .neighbors = neighbors,
            .allocator = allocator,
        }});
    }

    for (thread_pool) |thread| {
        thread.join();
    }

    var cluster_id: isize = 0;
    var p: usize = 0;
    while (p < num_points) : (p += 1) {
        if (labels[p] != -2) continue; // Visited

        if (neighbors[p].len < min_pts) {
            labels[p] = -1; // Noise
            continue;
        }

        labels[p] = cluster_id;
        var seed_set = std.ArrayList(usize).empty;
        defer seed_set.deinit(allocator);

        for (neighbors[p]) |n| {
            if (n != p) try seed_set.append(allocator, n);
        }

        while (seed_set.pop()) |q| {
            if (labels[q] == -1) {
                labels[q] = cluster_id;
            }
            if (labels[q] != -2) continue;

            labels[q] = cluster_id;
            if (neighbors[q].len >= min_pts) {
                for (neighbors[q]) |n| {
                    try seed_set.append(allocator, n);
                }
            }
        }

        cluster_id += 1;
    }

    return DBSCANResult{ .labels = labels };
}

test "dbscan basic" {
    const data = [_]f64{
        1.0, 1.0,
        1.1, 1.1,
        1.0, 1.2, // cluster 0
        10.0, 10.0, // noise
        20.0, 20.0,
        20.1, 20.1,
        20.2, 20.2, // cluster 1
    };

    const res = try dbscan(std.testing.allocator, &data, 2, 1.0, 2, 2);
    defer res.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(isize, 0), res.labels[0]);
    try std.testing.expectEqual(@as(isize, -1), res.labels[3]);
    try std.testing.expectEqual(@as(isize, 1), res.labels[6]);
}
