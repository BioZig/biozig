const std = @import("std");
pub const SpinMutex = @import("../threading/threading.zig").SpinMutex;

pub const TrackingAllocator = struct {
    parent: std.mem.Allocator,
    stats: Stats = .{},
    mutex: SpinMutex = .{},

    pub const Stats = struct {
        allocations: usize = 0,
        frees: usize = 0,
        bytes_allocated: usize = 0,
        bytes_freed: usize = 0,
    };

    pub fn init(parent: std.mem.Allocator) TrackingAllocator {
        return .{
            .parent = parent,
        };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    pub fn getAllocationCount(self: *TrackingAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.allocations;
    }

    pub fn getFreeCount(self: *TrackingAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.frees;
    }

    pub fn getBytesAllocated(self: *TrackingAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.bytes_allocated;
    }

    pub fn getBytesFreed(self: *TrackingAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.bytes_freed;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.parent.rawAlloc(len, alignment, ret_addr);
        if (result) |_| {
            self.stats.allocations += 1;
            self.stats.bytes_allocated += len;
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const old_len = buf.len;
        if (self.parent.rawResize(buf, alignment, new_len, ret_addr)) {
            if (new_len > old_len) {
                self.stats.bytes_allocated += (new_len - old_len);
            } else {
                self.stats.bytes_freed += (old_len - new_len);
            }
            return true;
        }
        return false;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const old_len = buf.len;
        const result = self.parent.rawRemap(buf, alignment, new_len, ret_addr);
        if (result) |_| {
            if (new_len > old_len) {
                self.stats.bytes_allocated += (new_len - old_len);
            } else {
                self.stats.bytes_freed += (old_len - new_len);
            }
        }
        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        self.parent.rawFree(buf, alignment, ret_addr);
        self.stats.frees += 1;
        self.stats.bytes_freed += buf.len;
    }
};

/// An ArenaAllocator wrapper that supports statistics tracking.
pub const ArenaAllocator = struct {
    arena: std.heap.ArenaAllocator,
    stats: TrackingAllocator.Stats = .{},
    mutex: SpinMutex = .{},

    pub fn init(child_allocator: std.mem.Allocator) ArenaAllocator {
        return .{
            .arena = std.heap.ArenaAllocator.init(child_allocator),
        };
    }

    pub fn deinit(self: *ArenaAllocator) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *ArenaAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    pub fn reset(self: *ArenaAllocator, mode: std.heap.ArenaAllocator.ResetMode) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const res = self.arena.reset(mode);
        self.stats = .{};
        return res;
    }

    pub fn getAllocationCount(self: *ArenaAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.allocations;
    }

    pub fn getFreeCount(self: *ArenaAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.frees;
    }

    pub fn getBytesAllocated(self: *ArenaAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.bytes_allocated;
    }

    pub fn getBytesFreed(self: *ArenaAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.bytes_freed;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.arena.allocator().rawAlloc(len, alignment, ret_addr);
        if (result) |_| {
            self.stats.allocations += 1;
            self.stats.bytes_allocated += len;
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const old_len = buf.len;
        if (self.arena.allocator().rawResize(buf, alignment, new_len, ret_addr)) {
            if (new_len > old_len) {
                self.stats.bytes_allocated += (new_len - old_len);
            } else {
                self.stats.bytes_freed += (old_len - new_len);
            }
            return true;
        }
        return false;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const old_len = buf.len;
        const result = self.arena.allocator().rawRemap(buf, alignment, new_len, ret_addr);
        if (result) |_| {
            if (new_len > old_len) {
                self.stats.bytes_allocated += (new_len - old_len);
            } else {
                self.stats.bytes_freed += (old_len - new_len);
            }
        }
        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        self.arena.allocator().rawFree(buf, alignment, ret_addr);
        self.stats.frees += 1;
        self.stats.bytes_freed += buf.len;
    }
};

/// A FixedBufferAllocator wrapper that supports statistics tracking.
pub const FixedBufferAllocator = struct {
    fba: std.heap.FixedBufferAllocator,
    stats: TrackingAllocator.Stats = .{},
    mutex: SpinMutex = .{},

    pub fn init(buf: []u8) FixedBufferAllocator {
        return .{
            .fba = std.heap.FixedBufferAllocator.init(buf),
        };
    }

    pub fn allocator(self: *FixedBufferAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    pub fn reset(self: *FixedBufferAllocator) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.fba.reset();
        self.stats = .{};
    }

    pub fn getAllocationCount(self: *FixedBufferAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.allocations;
    }

    pub fn getFreeCount(self: *FixedBufferAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.frees;
    }

    pub fn getBytesAllocated(self: *FixedBufferAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.bytes_allocated;
    }

    pub fn getBytesFreed(self: *FixedBufferAllocator) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.bytes_freed;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.fba.allocator().rawAlloc(len, alignment, ret_addr);
        if (result) |_| {
            self.stats.allocations += 1;
            self.stats.bytes_allocated += len;
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const old_len = buf.len;
        if (self.fba.allocator().rawResize(buf, alignment, new_len, ret_addr)) {
            if (new_len > old_len) {
                self.stats.bytes_allocated += (new_len - old_len);
            } else {
                self.stats.bytes_freed += (old_len - new_len);
            }
            return true;
        }
        return false;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        const old_len = buf.len;
        const result = self.fba.allocator().rawRemap(buf, alignment, new_len, ret_addr);
        if (result) |_| {
            if (new_len > old_len) {
                self.stats.bytes_allocated += (new_len - old_len);
            } else {
                self.stats.bytes_freed += (old_len - new_len);
            }
        }
        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        self.fba.allocator().rawFree(buf, alignment, ret_addr);
        self.stats.frees += 1;
        self.stats.bytes_freed += buf.len;
    }
};

test "tracking allocator stats and functionality" {
    var tracker = TrackingAllocator.init(std.testing.allocator);
    const alloc = tracker.allocator();

    const p = try alloc.alloc(u8, 50);
    try std.testing.expectEqual(@as(usize, 1), tracker.getAllocationCount());
    try std.testing.expectEqual(@as(usize, 50), tracker.getBytesAllocated());
    try std.testing.expectEqual(@as(usize, 0), tracker.getBytesFreed());

    const p2 = try alloc.realloc(p, 100);
    // bytes allocated should be either 100 (if resized in place) or 150 (if reallocated)
    const allocated = tracker.getBytesAllocated();
    const freed = tracker.getBytesFreed();
    try std.testing.expect(allocated == 100 or allocated == 150);
    try std.testing.expectEqual(allocated - freed, @as(usize, 100));

    alloc.free(p2);
    try std.testing.expectEqual(tracker.getBytesAllocated(), tracker.getBytesFreed());
}

test "arena allocator tracking" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    const p1 = try alloc.alloc(u8, 10);
    const p2 = try alloc.alloc(u8, 20);
    _ = p1;
    _ = p2;

    try std.testing.expectEqual(@as(usize, 2), arena.getAllocationCount());
    try std.testing.expectEqual(@as(usize, 30), arena.getBytesAllocated());

    _ = arena.reset(.free_all);
    try std.testing.expectEqual(@as(usize, 0), arena.getAllocationCount());
    try std.testing.expectEqual(@as(usize, 0), arena.getBytesAllocated());
}

test "fixed buffer allocator tracking" {
    var buffer: [512]u8 = undefined;
    var fba = FixedBufferAllocator.init(&buffer);

    const alloc = fba.allocator();
    const p1 = try alloc.alloc(u8, 64);
    _ = p1;

    try std.testing.expectEqual(@as(usize, 1), fba.getAllocationCount());
    try std.testing.expectEqual(@as(usize, 64), fba.getBytesAllocated());

    fba.reset();
    try std.testing.expectEqual(@as(usize, 0), fba.getAllocationCount());
}
