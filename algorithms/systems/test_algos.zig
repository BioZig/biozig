const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const PQEntry = struct {
        u: usize,
        d: f64,
        fn lessThan(context: void, a: @This(), b: @This()) std.math.Order {
            _ = context;
            return std.math.order(a.d, b.d);
        }
    };
    var pq = std.PriorityQueue(PQEntry, void, PQEntry.lessThan).initContext({});
    try pq.push(allocator, .{ .u = 0, .d = 0.0 });
    _ = pq.pop();
    pq.deinit(allocator);
    std.debug.print("PQ Test Passed\n", .{});
}
