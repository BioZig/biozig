const std = @import("std");

/// A task within the dependency-aware scheduler.
pub const SchedTask = struct {
    id: usize,
    run: *const fn (ctx: ?*anyopaque) void,
    ctx: ?*anyopaque,
    dependencies: []const usize,
    dependents: std.ArrayList(usize) = .empty,
};

/// A dependency-aware task scheduler.
pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    tasks: std.AutoHashMap(usize, SchedTask),

    pub fn init(allocator: std.mem.Allocator) Scheduler {
        return .{
            .allocator = allocator,
            .tasks = std.AutoHashMap(usize, SchedTask).init(allocator),
        };
    }

    pub fn deinit(self: *Scheduler) void {
        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.dependents.deinit(self.allocator);
        }
        self.tasks.deinit();
    }

    pub fn addTask(
        self: *Scheduler,
        id: usize,
        dependencies: []const usize,
        run: *const fn (ctx: ?*anyopaque) void,
        ctx: ?*anyopaque,
    ) !void {
        const t = SchedTask{
            .id = id,
            .run = run,
            .ctx = ctx,
            .dependencies = dependencies,
        };
        try self.tasks.put(id, t);
    }

    /// Runs all tasks in a deterministic, topologically sorted order.
    /// Returns error.CircularDependency if a cycle is detected.
    pub fn runDeterministic(self: *Scheduler) !void {
        try self.resolveDependents();
        defer self.resetDependents();

        var order = std.ArrayList(usize).empty;
        defer order.deinit(self.allocator);

        var visited = std.AutoHashMap(usize, u8).init(self.allocator);
        defer visited.deinit();

        var iter = self.tasks.keyIterator();
        while (iter.next()) |id_ptr| {
            try self.topologicalSortVisit(id_ptr.*, &order, &visited);
        }

        for (order.items) |task_id| {
            const task = self.tasks.get(task_id).?;
            task.run(task.ctx);
        }
    }

    fn resolveDependents(self: *Scheduler) !void {
        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            const task = entry.value_ptr;
            for (task.dependencies) |dep_id| {
                if (!self.tasks.contains(dep_id)) return error.MissingDependency;
                const dep_task = self.tasks.getPtr(dep_id).?;
                try dep_task.dependents.append(self.allocator, task.id);
            }
        }
    }

    fn resetDependents(self: *Scheduler) void {
        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.dependents.clearAndFree(self.allocator);
        }
    }

    fn topologicalSortVisit(
        self: *Scheduler,
        id: usize,
        order: *std.ArrayList(usize),
        visited: *std.AutoHashMap(usize, u8),
    ) !void {
        const state = visited.get(id) orelse 0;
        if (state == 1) return error.CircularDependency;
        if (state == 2) return;

        try visited.put(id, 1);

        const task = self.tasks.get(id).?;
        for (task.dependencies) |dep_id| {
            try self.topologicalSortVisit(dep_id, order, visited);
        }

        try visited.put(id, 2);
        try order.append(self.allocator, id);
    }
};

const SchedTestCtx = struct {
    id: usize,
    order: *std.ArrayList(usize),
    allocator: std.mem.Allocator,

    pub fn run(ctx: ?*anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.order.append(self.allocator, self.id) catch unreachable;
    }
};

test "deterministic task scheduling DAG" {
    var sched = Scheduler.init(std.testing.allocator);
    defer sched.deinit();

    var order = std.ArrayList(usize).empty;
    defer order.deinit(std.testing.allocator);

    var c1 = SchedTestCtx{ .id = 1, .order = &order, .allocator = std.testing.allocator };
    var c2 = SchedTestCtx{ .id = 2, .order = &order, .allocator = std.testing.allocator };
    var c3 = SchedTestCtx{ .id = 3, .order = &order, .allocator = std.testing.allocator };
    var c4 = SchedTestCtx{ .id = 4, .order = &order, .allocator = std.testing.allocator };

    // Task 4 depends on 2 and 3. Task 2 and 3 depend on 1.
    // Order: 1 -> (2, 3) -> 4
    try sched.addTask(4, &[_]usize{ 2, 3 }, SchedTestCtx.run, &c4);
    try sched.addTask(2, &[_]usize{ 1 }, SchedTestCtx.run, &c2);
    try sched.addTask(3, &[_]usize{ 1 }, SchedTestCtx.run, &c3);
    try sched.addTask(1, &[_]usize{}, SchedTestCtx.run, &c1);

    try sched.runDeterministic();

    try std.testing.expectEqual(order.items.len, 4);
    try std.testing.expectEqual(order.items[0], 1);
    try std.testing.expect(order.items[1] == 2 or order.items[1] == 3);
    try std.testing.expect(order.items[2] == 2 or order.items[2] == 3);
    try std.testing.expectEqual(order.items[3], 4);
}

test "circular dependency detection" {
    var sched = Scheduler.init(std.testing.allocator);
    defer sched.deinit();

    var order = std.ArrayList(usize).empty;
    defer order.deinit(std.testing.allocator);

    var c1 = SchedTestCtx{ .id = 1, .order = &order, .allocator = std.testing.allocator };
    var c2 = SchedTestCtx{ .id = 2, .order = &order, .allocator = std.testing.allocator };

    try sched.addTask(1, &[_]usize{ 2 }, SchedTestCtx.run, &c1);
    try sched.addTask(2, &[_]usize{ 1 }, SchedTestCtx.run, &c2);

    try std.testing.expectError(error.CircularDependency, sched.runDeterministic());
}
