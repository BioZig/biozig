const std = @import("std");

pub const Match = struct {
    row: usize,
    col: usize,
};

/// Solves the linear assignment problem using the O(n^3) Hungarian algorithm with potentials.
/// Expects a square cost matrix of size (N x N).
pub fn hungarian(allocator: std.mem.Allocator, cost_matrix: anytype) ![]Match {
    const n = cost_matrix.len;
    if (n == 0) return &[_]Match{};

    // The algorithm uses 1-based indexing internally for the augmenting path logic
    const m = n + 1;

    var u = try allocator.alloc(f64, m);
    @memset(u, 0.0);
    defer allocator.free(u);

    var v = try allocator.alloc(f64, m);
    @memset(v, 0.0);
    defer allocator.free(v);

    var p = try allocator.alloc(usize, m);
    @memset(p, 0);
    defer allocator.free(p);

    var way = try allocator.alloc(usize, m);
    @memset(way, 0);
    defer allocator.free(way);

    var minv = try allocator.alloc(f64, m);
    defer allocator.free(minv);

    var used = try allocator.alloc(bool, m);
    defer allocator.free(used);

    for (1..m) |i| {
        p[0] = i;
        var j0: usize = 0;
        
        @memset(minv, std.math.inf(f64));
        @memset(used, false);
        
        while (true) {
            used[j0] = true;
            const i_0 = p[j0];
            var delta = std.math.inf(f64);
            var j1: usize = 0;

            for (1..m) |j| {
                if (!used[j]) {
                    const cur = cost_matrix[i_0 - 1][j - 1] - u[i_0] - v[j];
                    if (cur < minv[j]) {
                        minv[j] = cur;
                        way[j] = j0;
                    }
                    if (minv[j] < delta) {
                        delta = minv[j];
                        j1 = j;
                    }
                }
            }

            for (0..m) |j| {
                if (used[j]) {
                    u[p[j]] += delta;
                    v[j] -= delta;
                } else {
                    minv[j] -= delta;
                }
            }

            j0 = j1;
            if (p[j0] == 0) break;
        }

        // Augmenting path backtracking
        while (true) {
            const j1 = way[j0];
            p[j0] = p[j1];
            j0 = j1;
            if (j0 == 0) break;
        }
    }

    var temp_matches = try allocator.alloc(Match, m);
    defer allocator.free(temp_matches);
    var count: usize = 0;

    for (1..m) |j| {
        if (p[j] != 0) {
            temp_matches[count] = .{
                .row = p[j] - 1,
                .col = j - 1,
            };
            count += 1;
        }
    }

    return allocator.dupe(Match, temp_matches[0..count]);
}
