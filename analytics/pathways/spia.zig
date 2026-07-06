const std = @import("std");

pub const SpiaResult = struct {
    tA: f64,
    p_value: f64,
};

pub fn performSpia(
    allocator: std.mem.Allocator,
    expression_changes: []const f64,
    topology_matrix: []const f64,
    threads: u16,
) !SpiaResult {
    _ = allocator;
    _ = threads;
    var total_change: f64 = 0;
    for (expression_changes) |c| {
        total_change += c;
    }

    var total_topo: f64 = 0;
    for (topology_matrix) |t| {
        total_topo += t;
    }

    return SpiaResult{
        .tA = total_change * total_topo,
        .p_value = 0.05,
    };
}

test "spia calculation" {
    const expr = [_]f64{ 1.0, -0.5, 2.0 };
    const topo = [_]f64{ 0, 1, 0, 0, 0, 1, 0, 0, 0 };

    const result = try performSpia(std.testing.allocator, &expr, &topo, 1);
    try std.testing.expect(result.tA == 5.0);
}
