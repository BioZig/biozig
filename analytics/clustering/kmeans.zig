const std = @import("std");

pub const KMeansResult = struct {
    centroids: []f64, // flat array: k * dim
    labels: []usize, // num_points

    pub fn deinit(self: KMeansResult, allocator: std.mem.Allocator) void {
        allocator.free(self.centroids);
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

const AssignContext = struct {
    data: []const f64,
    dim: usize,
    centroids: []const f64,
    labels: []usize,
    start_idx: usize,
    end_idx: usize,
    changed: *std.atomic.Value(usize),
};

fn assignWorker(ctx: AssignContext) void {
    const dim = ctx.dim;
    const k = ctx.centroids.len / dim;
    var i: usize = ctx.start_idx;
    var local_changed: usize = 0;

    while (i < ctx.end_idx) : (i += 1) {
        const point = ctx.data[i * dim .. (i + 1) * dim];
        var min_dist = std.math.inf(f64);
        var best_idx: usize = 0;

        var c: usize = 0;
        while (c < k) : (c += 1) {
            const centroid = ctx.centroids[c * dim .. (c + 1) * dim];
            const dist = distance(point, centroid);
            if (dist < min_dist) {
                min_dist = dist;
                best_idx = c;
            }
        }

        if (ctx.labels[i] != best_idx) {
            ctx.labels[i] = best_idx;
            local_changed += 1;
        }
    }

    if (local_changed > 0) {
        _ = ctx.changed.fetchAdd(local_changed, .monotonic);
    }
}

pub fn kmeans(allocator: std.mem.Allocator, data: []const f64, dim: usize, k: usize, max_iter: usize, threads: u16) !KMeansResult {
    const num_points = data.len / dim;
    if (num_points < k) return error.NotEnoughData;
    if (threads == 0) return error.InvalidThreadCount;

    const centroids = try allocator.alloc(f64, k * dim);
    errdefer allocator.free(centroids);

    const labels = try allocator.alloc(usize, num_points);
    errdefer allocator.free(labels);

    @memset(labels, std.math.maxInt(usize)); // initialize to invalid

    // Forgy initialization: pick first k points
    var i: usize = 0;
    while (i < k) : (i += 1) {
        @memcpy(centroids[i * dim .. (i + 1) * dim], data[i * dim .. (i + 1) * dim]);
    }

    var iter: usize = 0;
    var changed = std.atomic.Value(usize).init(0);

    const thread_pool = try allocator.alloc(std.Thread, threads);
    defer allocator.free(thread_pool);

    const cluster_counts = try allocator.alloc(usize, k);
    defer allocator.free(cluster_counts);
    const new_centroids = try allocator.alloc(f64, k * dim);
    defer allocator.free(new_centroids);

    while (iter < max_iter) : (iter += 1) {
        changed.store(0, .monotonic);

        const chunk_size = (num_points + threads - 1) / threads;
        var t: usize = 0;
        while (t < threads) : (t += 1) {
            const start = t * chunk_size;
            const end = @min(start + chunk_size, num_points);

            if (start >= end) {
                // Dummy thread if we have more threads than points chunked
                thread_pool[t] = try std.Thread.spawn(.{}, assignWorker, .{AssignContext{
                    .data = data,
                    .dim = dim,
                    .centroids = centroids,
                    .labels = labels,
                    .start_idx = 0,
                    .end_idx = 0,
                    .changed = &changed,
                }});
                continue;
            }

            thread_pool[t] = try std.Thread.spawn(.{}, assignWorker, .{AssignContext{
                .data = data,
                .dim = dim,
                .centroids = centroids,
                .labels = labels,
                .start_idx = start,
                .end_idx = end,
                .changed = &changed,
            }});
        }

        for (thread_pool) |thread| {
            thread.join();
        }

        if (changed.load(.monotonic) == 0) break;

        // Update centroids
        @memset(cluster_counts, 0);
        @memset(new_centroids, 0.0);

        var p: usize = 0;
        while (p < num_points) : (p += 1) {
            const cluster = labels[p];
            cluster_counts[cluster] += 1;

            const point = data[p * dim .. (p + 1) * dim];
            var d: usize = 0;
            while (d < dim) : (d += 1) {
                new_centroids[cluster * dim + d] += point[d];
            }
        }

        var c: usize = 0;
        while (c < k) : (c += 1) {
            if (cluster_counts[c] > 0) {
                var d: usize = 0;
                while (d < dim) : (d += 1) {
                    centroids[c * dim + d] = new_centroids[c * dim + d] / @as(f64, @floatFromInt(cluster_counts[c]));
                }
            }
        }
    }

    return KMeansResult{ .centroids = centroids, .labels = labels };
}

test "kmeans basic" {
    const data = [_]f64{
        1.0, 1.0,
        1.5, 2.0,
        3.0, 4.0,
        5.0, 7.0,
        3.5, 5.0,
        4.5, 5.0,
        3.5, 4.5,
    };

    const res = try kmeans(std.testing.allocator, &data, 2, 2, 10, 2);
    defer res.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), res.centroids.len / 2);
}
