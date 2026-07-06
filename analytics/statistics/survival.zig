const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const Observation = struct {
    time: f64,
    event: bool,
    covariate: f64 = 0.0,
};

fn compareObservations(context: void, a: Observation, b: Observation) bool {
    _ = context;
    if (a.time == b.time) {
        // If times are equal, events (true) come before censoring (false)
        return (a.event and !b.event);
    }
    return a.time < b.time;
}

pub const KMSummary = struct {
    time: f64,
    n_at_risk: usize,
    n_events: usize,
    survival_prob: f64,
};

pub fn kaplanMeier(allocator: std.mem.Allocator, data: []const Observation) ![]KMSummary {
    if (data.len == 0) return &[_]KMSummary{};

    const sorted_data = try allocator.alloc(Observation, data.len);
    defer allocator.free(sorted_data);
    @memcpy(sorted_data, data);
    std.sort.block(Observation, sorted_data, {}, compareObservations);

    var results = std.ArrayList(KMSummary).empty;
    errdefer results.deinit(allocator);

    var current_time = sorted_data[0].time;
    var n_at_risk: usize = sorted_data.len;
    var n_events: usize = 0;
    var current_survival: f64 = 1.0;

    for (sorted_data, 0..) |obs, i| {
        if (obs.time != current_time) {
            if (n_events > 0) {
                current_survival *= 1.0 - (@as(f64, @floatFromInt(n_events)) / @as(f64, @floatFromInt(n_at_risk)));
                try results.append(allocator, KMSummary{
                    .time = current_time,
                    .n_at_risk = n_at_risk,
                    .n_events = n_events,
                    .survival_prob = current_survival,
                });
            }
            n_at_risk = sorted_data.len - i;
            current_time = obs.time;
            n_events = 0;
        }
        if (obs.event) n_events += 1;
    }

    if (n_events > 0) {
        current_survival *= 1.0 - (@as(f64, @floatFromInt(n_events)) / @as(f64, @floatFromInt(n_at_risk)));
        try results.append(allocator, KMSummary{
            .time = current_time,
            .n_at_risk = n_at_risk,
            .n_events = n_events,
            .survival_prob = current_survival,
        });
    }

    return results.toOwnedSlice(allocator);
}

pub fn logRankTest(allocator: std.mem.Allocator, group1: []const Observation, group2: []const Observation) !f64 {
    const all_data = try allocator.alloc(Observation, group1.len + group2.len);
    defer allocator.free(all_data);

    @memcpy(all_data[0..group1.len], group1);
    for (group2, 0..) |obs, i| {
        var modified_obs = obs;
        modified_obs.covariate = 1.0; 
        all_data[group1.len + i] = modified_obs;
    }
    
    for (all_data[0..group1.len]) |*obs| {
        obs.covariate = 0.0;
    }

    std.sort.block(Observation, all_data, {}, compareObservations);

    var o1: f64 = 0;
    var e1: f64 = 0;
    var v: f64 = 0;

    var i: usize = 0;
    while (i < all_data.len) {
        const current_time = all_data[i].time;
        var n1: usize = 0;
        var n2: usize = 0;
        
        for (all_data[i..]) |obs| {
            if (obs.covariate == 0.0) n1 += 1 else n2 += 1;
        }
        
        var d1: usize = 0;
        var d2: usize = 0;
        
        while (i < all_data.len and all_data[i].time == current_time) {
            if (all_data[i].event) {
                if (all_data[i].covariate == 0.0) d1 += 1 else d2 += 1;
            }
            i += 1;
        }
        
        const n_total = n1 + n2;
        const d_total = d1 + d2;
        
        if (d_total > 0 and n_total > 1) {
            o1 += @as(f64, @floatFromInt(d1));
            
            const expected = @as(f64, @floatFromInt(d_total)) * @as(f64, @floatFromInt(n1)) / @as(f64, @floatFromInt(n_total));
            e1 += expected;
            
            const variance = expected * @as(f64, @floatFromInt(n2)) / @as(f64, @floatFromInt(n_total)) * @as(f64, @floatFromInt(n_total - d_total)) / @as(f64, @floatFromInt(n_total - 1));
            v += variance;
        } else if (d_total > 0 and n_total == 1) {
             o1 += @as(f64, @floatFromInt(d1));
             const expected = @as(f64, @floatFromInt(d_total)) * @as(f64, @floatFromInt(n1)) / @as(f64, @floatFromInt(n_total));
             e1 += expected;
        }
    }

    if (v == 0) return 0.0;
    
    return (o1 - e1) * (o1 - e1) / v;
}

pub fn coxProportionalHazards(allocator: std.mem.Allocator, data: []const Observation, max_iters: usize, tol: f64) !f64 {
    const sorted_data = try allocator.alloc(Observation, data.len);
    defer allocator.free(sorted_data);
    @memcpy(sorted_data, data);
    std.sort.block(Observation, sorted_data, {}, compareObservations);

    var beta: f64 = 0.0;

    for (0..max_iters) |_| {
        var u: f64 = 0.0; // Score
        var i_info: f64 = 0.0; // Information

        var i: usize = 0;
        while (i < sorted_data.len) {
            if (sorted_data[i].event) {
                var sum_exp: f64 = 0.0;
                var sum_x_exp: f64 = 0.0;
                var sum_x2_exp: f64 = 0.0;

                for (sorted_data[i..]) |r_obs| {
                    const e_bx = math.exp(beta * r_obs.covariate);
                    sum_exp += e_bx;
                    sum_x_exp += r_obs.covariate * e_bx;
                    sum_x2_exp += r_obs.covariate * r_obs.covariate * e_bx;
                }

                if (sum_exp > 0) {
                    u += sorted_data[i].covariate - (sum_x_exp / sum_exp);
                    i_info += (sum_x2_exp / sum_exp) - (sum_x_exp / sum_exp) * (sum_x_exp / sum_exp);
                }
            }
            i += 1;
        }

        if (i_info == 0.0) break;

        const delta = u / i_info;
        beta += delta;

        if (@abs(delta) < tol) break;
    }

    return beta;
}

test "Kaplan-Meier Estimator" {
    const data = [_]Observation{
        .{ .time = 5, .event = true },
        .{ .time = 6, .event = false },
        .{ .time = 6, .event = true },
        .{ .time = 8, .event = true },
        .{ .time = 10, .event = false },
    };

    const results = try kaplanMeier(std.testing.allocator, &data);
    defer std.testing.allocator.free(results);

    try testing.expectEqual(@as(usize, 3), results.len);
    try testing.expectEqual(@as(f64, 5.0), results[0].time);
    try testing.expectEqual(@as(f64, 6.0), results[1].time);
    try testing.expectEqual(@as(f64, 8.0), results[2].time);
}

test "Log-Rank Test" {
    const group1 = [_]Observation{
        .{ .time = 5, .event = true },
        .{ .time = 6, .event = false },
        .{ .time = 8, .event = true },
    };
    const group2 = [_]Observation{
        .{ .time = 6, .event = true },
        .{ .time = 10, .event = false },
        .{ .time = 12, .event = true },
    };

    const chi_sq = try logRankTest(std.testing.allocator, &group1, &group2);
    try testing.expect(chi_sq >= 0.0);
}

test "Cox Proportional Hazards" {
    const data = [_]Observation{
        .{ .time = 5, .event = true, .covariate = 1.0 },
        .{ .time = 6, .event = false, .covariate = 0.0 },
        .{ .time = 6, .event = true, .covariate = 1.0 },
        .{ .time = 8, .event = true, .covariate = 0.0 },
        .{ .time = 10, .event = false, .covariate = 1.0 },
    };

    const beta = try coxProportionalHazards(std.testing.allocator, &data, 100, 1e-6);
    try testing.expect(math.isFinite(beta));
}
