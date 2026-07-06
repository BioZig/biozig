const std = @import("std");

pub const HierarchicalResult = struct {
    labels: []usize, // cluster assignments

    pub fn deinit(self: HierarchicalResult, allocator: std.mem.Allocator) void {
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

const DistContext = struct {
    data: []const f64,
    dim: usize,
    start_i: usize,
    end_i: usize,
    num_points: usize,
    dist_matrix: []f64,
};

fn distWorker(ctx: DistContext) void {
    var i: usize = ctx.start_i;
    while (i < ctx.end_i) : (i += 1) {
        const p_i = ctx.data[i * ctx.dim .. (i + 1) * ctx.dim];
        var j: usize = i + 1;
        while (j < ctx.num_points) : (j += 1) {
            const p_j = ctx.data[j * ctx.dim .. (j + 1) * ctx.dim];
            ctx.dist_matrix[i * ctx.num_points + j] = distance(p_i, p_j);
            ctx.dist_matrix[j * ctx.num_points + i] = ctx.dist_matrix[i * ctx.num_points + j];
        }
    }
}

pub fn agglomerative(allocator: std.mem.Allocator, data: []const f64, dim: usize, k: usize, threads: u16) !HierarchicalResult {
    const num_points = data.len / dim;
    if (num_points < k) return error.NotEnoughData;
    if (threads == 0) return error.InvalidThreadCount;

    const dist_matrix = try allocator.alloc(f64, num_points * num_points);
    defer allocator.free(dist_matrix);

    // Fill diagonal with infinity
    var i: usize = 0;
    while (i < num_points) : (i += 1) {
        dist_matrix[i * num_points + i] = std.math.inf(f64);
    }

    const thread_pool = try allocator.alloc(std.Thread, threads);
    defer allocator.free(thread_pool);

    const chunk_size = (num_points + threads - 1) / threads;
    var t: usize = 0;
    while (t < threads) : (t += 1) {
        const start = t * chunk_size;
        const end = @min(start + chunk_size, num_points);

        if (start >= end) {
            thread_pool[t] = try std.Thread.spawn(.{}, distWorker, .{DistContext{
                .data = data,
                .dim = dim,
                .start_i = 0,
                .end_i = 0,
                .num_points = num_points,
                .dist_matrix = dist_matrix,
            }});
            continue;
        }

        thread_pool[t] = try std.Thread.spawn(.{}, distWorker, .{DistContext{
            .data = data,
            .dim = dim,
            .start_i = start,
            .end_i = end,
            .num_points = num_points,
            .dist_matrix = dist_matrix,
        }});
    }

    for (thread_pool) |thread| {
        thread.join();
    }

    const active = try allocator.alloc(bool, num_points);
    defer allocator.free(active);
    @memset(active, true);

    const clusters = try allocator.alloc(usize, num_points);
    defer allocator.free(clusters);
    i = 0;
    while (i < num_points) : (i += 1) {
        clusters[i] = i;
    }

    var current_clusters = num_points;
    while (current_clusters > k) : (current_clusters -= 1) {
        var min_d = std.math.inf(f64);
        var min_u: usize = 0;
        var min_v: usize = 0;

        var u: usize = 0;
        while (u < num_points) : (u += 1) {
            if (!active[u]) continue;
            var v: usize = u + 1;
            while (v < num_points) : (v += 1) {
                if (!active[v]) continue;

                const d = dist_matrix[u * num_points + v];
                if (d < min_d) {
                    min_d = d;
                    min_u = u;
                    min_v = v;
                }
            }
        }

        // Merge min_v into min_u (Single Linkage)
        active[min_v] = false;
        var w: usize = 0;
        while (w < num_points) : (w += 1) {
            if (!active[w] or w == min_u) continue;
            const d_uw = dist_matrix[min_u * num_points + w];
            const d_vw = dist_matrix[min_v * num_points + w];
            const new_d = @min(d_uw, d_vw);

            dist_matrix[min_u * num_points + w] = new_d;
            dist_matrix[w * num_points + min_u] = new_d;
        }

        // Update clusters array
        var p: usize = 0;
        while (p < num_points) : (p += 1) {
            if (clusters[p] == clusters[min_v]) {
                clusters[p] = clusters[min_u];
            }
        }
    }

    const labels = try allocator.alloc(usize, num_points);
    errdefer allocator.free(labels);

    // Compress cluster IDs to 0..k-1
    var id_map = std.AutoHashMap(usize, usize).init(allocator);
    defer id_map.deinit();

    var next_id: usize = 0;
    i = 0;
    while (i < num_points) : (i += 1) {
        const c = clusters[i];
        if (!id_map.contains(c)) {
            try id_map.put(c, next_id);
            next_id += 1;
        }
        labels[i] = id_map.get(c).?;
    }

    return HierarchicalResult{ .labels = labels };
}

test "hierarchical basic" {
    const data = [_]f64{
        1.0,  1.0,
        1.1,  1.1,
        10.0, 10.0,
        10.1, 10.1,
    };

    const res = try agglomerative(std.testing.allocator, &data, 2, 2, 2);
    defer res.deinit(std.testing.allocator);

    try std.testing.expectEqual(res.labels[0], res.labels[1]);
    try std.testing.expectEqual(res.labels[2], res.labels[3]);
    try std.testing.expect(res.labels[0] != res.labels[2]);
}
