const std = @import("std");
const builtin = @import("builtin");

extern "c" fn pthread_mach_thread_np(thread: std.c.pthread_t) u32;
extern "c" fn thread_policy_set(thread: u32, policy: i32, base: *anyopaque, count: u32) i32;

pub fn pinThreadToCore(core_id: usize) void {
    if (builtin.os.tag == .macos) {
        const thread_port = pthread_mach_thread_np(std.c.pthread_self());
        var policy = extern struct {
            affinity_tag: i32,
        }{
            .affinity_tag = @as(i32, @intCast(core_id + 1)),
        };
        _ = thread_policy_set(thread_port, 4, &policy, 1);
    } else if (builtin.os.tag == .linux) {
        var set = std.mem.zeroes([16]usize);
        const int_bits = @typeInfo(usize).int.bits;
        const idx = core_id / int_bits;
        const bit = core_id % int_bits;
        if (idx < set.len) {
            set[idx] |= @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(bit));
        }
        _ = std.os.linux.sched_setaffinity(0, &set) catch {};
    }
}

/// A thread-safe spin mutex.
pub const SpinMutex = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *SpinMutex) void {
        while (self.state.swap(true, .acquire)) {
            std.Thread.yield() catch {};
        }
    }

    pub fn unlock(self: *SpinMutex) void {
        self.state.store(false, .release);
    }

    pub fn tryLock(self: *SpinMutex) bool {
        return !self.state.swap(true, .acquire);
    }
};

/// Represents a single task to be executed by the thread pool.
pub const Task = struct {
    run: *const fn (ctx: ?*anyopaque) void,
    ctx: ?*anyopaque,
    next: ?*Task = null,
};

/// A thread-safe task queue.
pub const TaskQueue = struct {
    head: ?*Task = null,
    tail: ?*Task = null,
    mutex: SpinMutex = .{},
    len: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    pub fn push(self: *TaskQueue, task: *Task) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        task.next = null;
        if (self.tail) |t| {
            t.next = task;
        } else {
            self.head = task;
        }
        self.tail = task;
        _ = self.len.fetchAdd(1, .release);
    }

    pub fn pop(self: *TaskQueue) ?*Task {
        if (self.len.load(.acquire) == 0) return null;

        self.mutex.lock();
        defer self.mutex.unlock();

        const task = self.head orelse return null;
        self.head = task.next;
        if (self.head == null) {
            self.tail = null;
        }
        _ = self.len.fetchSub(1, .release);
        return task;
    }
};

/// A high-performance thread pool.
pub const ThreadPool = struct {
    allocator: std.mem.Allocator,
    threads: []std.Thread,
    queue: TaskQueue = .{},
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),

    pub fn init(allocator: std.mem.Allocator, num_threads: usize) !*ThreadPool {
        const self = try allocator.create(ThreadPool);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .threads = try allocator.alloc(std.Thread, num_threads),
        };

        var spawned: usize = 0;
        errdefer {
            self.running.store(false, .release);
            for (0..spawned) |i| {
                self.threads[i].join();
            }
            allocator.free(self.threads);
        }

        for (0..num_threads) |i| {
            self.threads[i] = try std.Thread.spawn(.{}, workerLoop, .{ self, i });
            spawned += 1;
        }

        return self;
    }

    pub fn deinit(self: *ThreadPool) void {
        self.running.store(false, .release);
        for (self.threads) |t| {
            t.join();
        }
        self.allocator.free(self.threads);
        self.allocator.destroy(self);
    }

    pub fn spawnTask(self: *ThreadPool, task: *Task) void {
        self.queue.push(task);
    }

    fn workerLoop(self: *ThreadPool, core_id: usize) void {
        pinThreadToCore(core_id);
        while (self.running.load(.acquire) or self.queue.len.load(.acquire) > 0) {
            if (self.queue.pop()) |task| {
                task.run(task.ctx);
            } else {
                std.Thread.yield() catch {};
            }
        }
    }
};

const TestCtx = struct {
    counter: *std.atomic.Value(usize),
    pub fn run(ctx: ?*anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        _ = self.counter.fetchAdd(1, .monotonic);
    }
};

test "thread pool basic operations" {
    var pool = try ThreadPool.init(std.testing.allocator, 4);
    defer pool.deinit();

    var counter = std.atomic.Value(usize).init(0);
    var tasks: [100]Task = undefined;
    var contexts: [100]TestCtx = undefined;

    for (0..100) |i| {
        contexts[i] = .{ .counter = &counter };
        tasks[i] = .{
            .run = TestCtx.run,
            .ctx = &contexts[i],
        };
        pool.spawnTask(&tasks[i]);
    }

    while (counter.load(.acquire) < 100) {
        std.Thread.yield() catch {};
    }

    try std.testing.expectEqual(counter.load(.acquire), 100);
}
