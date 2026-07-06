const std = @import("std");
const core = @import("core");

test "threading thread pool starvation and edge cases" {
    // 0 threads
    var pool = try core.threading.ThreadPool.init(std.testing.allocator, 0);
    pool.deinit();

    // single thread, many tasks
    var pool2 = try core.threading.ThreadPool.init(std.testing.allocator, 1);
    defer pool2.deinit();

    var counter = std.atomic.Value(usize).init(0);
    const TestCtx = struct {
        c: *std.atomic.Value(usize),
        pub fn run(ctx: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            _ = self.c.fetchAdd(1, .monotonic);
        }
    };

    var tasks: [1000]core.threading.Task = undefined;
    var contexts: [1000]TestCtx = undefined;

    for (0..1000) |i| {
        contexts[i] = .{ .c = &counter };
        tasks[i] = .{ .run = TestCtx.run, .ctx = &contexts[i] };
        pool2.spawnTask(&tasks[i]);
    }

    while (counter.load(.acquire) < 1000) {
        std.Thread.yield() catch {};
    }
    try std.testing.expectEqual(counter.load(.acquire), 1000);
}
