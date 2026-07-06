const std = @import("std");

/// A fixed-size array with length tracking.
pub fn FixedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        data: [capacity]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.len >= capacity) return error.OutOfSpace;
            self.data[self.len] = item;
            self.len += 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.data[self.len];
        }

        pub fn get(self: Self, index: usize) T {
            std.debug.assert(index < self.len);
            return self.data[index];
        }

        pub fn set(self: *Self, index: usize, item: T) void {
            std.debug.assert(index < self.len);
            self.data[index] = item;
        }
    };
}

/// A circular ring buffer of fixed capacity.
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        data: [capacity]T = undefined,
        head: usize = 0,
        tail: usize = 0,
        len: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.len >= capacity) return error.OutOfSpace;
            self.data[self.tail] = item;
            self.tail = (self.tail + 1) % capacity;
            self.len += 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            const item = self.data[self.head];
            self.head = (self.head + 1) % capacity;
            self.len -= 1;
            return item;
        }
    };
}

/// A FIFO Queue using dynamic list nodes.
pub fn Queue(comptime T: type) type {
    return struct {
        pub const Node = struct {
            data: T,
            next: ?*Node = null,
        };

        head: ?*Node = null,
        tail: ?*Node = null,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            var curr = self.head;
            while (curr) |node| {
                const next = node.next;
                self.allocator.destroy(node);
                curr = next;
            }
            self.head = null;
            self.tail = null;
        }

        pub fn enqueue(self: *Self, item: T) !void {
            const node = try self.allocator.create(Node);
            node.* = .{ .data = item, .next = null };

            if (self.tail) |t| {
                t.next = node;
            } else {
                self.head = node;
            }
            self.tail = node;
        }

        pub fn dequeue(self: *Self) ?T {
            const node = self.head orelse return null;
            self.head = node.next;
            if (self.head == null) {
                self.tail = null;
            }
            const data = node.data;
            self.allocator.destroy(node);
            return data;
        }
    };
}

/// A HashSet wrapping std.AutoHashMap.
pub fn HashSet(comptime T: type) type {
    return struct {
        map: std.AutoHashMap(T, void),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = std.AutoHashMap(T, void).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn insert(self: *Self, item: T) !bool {
            const res = try self.map.getOrPut(item);
            return !res.found_existing;
        }

        pub fn contains(self: Self, item: T) bool {
            return self.map.contains(item);
        }

        pub fn remove(self: *Self, item: T) bool {
            return self.map.remove(item);
        }

        pub fn count(self: Self) usize {
            return self.map.count();
        }
    };
}

/// A HashMap wrapping std.AutoHashMap.
pub fn HashMap(comptime K: type, comptime V: type) type {
    return struct {
        map: std.AutoHashMap(K, V),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = std.AutoHashMap(K, V).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            try self.map.put(key, value);
        }

        pub fn get(self: Self, key: K) ?V {
            return self.map.get(key);
        }

        pub fn remove(self: *Self, key: K) bool {
            return self.map.remove(key);
        }

        pub fn count(self: Self) usize {
            return self.map.count();
        }
    };
}

/// A wrapper around std.ArrayList for unmanaged dynamic arrays.
pub fn DynamicArray(comptime T: type) type {
    return struct {
        list: std.ArrayList(T) = .empty,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.list.deinit(allocator);
        }

        pub fn append(self: *Self, allocator: std.mem.Allocator, item: T) !void {
            try self.list.append(allocator, item);
        }

        pub fn pop(self: *Self) ?T {
            return self.list.pop();
        }

        pub fn get(self: Self, index: usize) T {
            return self.list.items[index];
        }

        pub fn len(self: Self) usize {
            return self.list.items.len;
        }
    };
}

test "FixedArray test" {
    var arr = FixedArray(i32, 5).init();
    try arr.push(10);
    try arr.push(20);
    try std.testing.expectEqual(arr.get(0), 10);
    try std.testing.expectEqual(arr.pop(), 20);
}

test "RingBuffer test" {
    var rb = RingBuffer(i32, 3).init();
    try rb.push(1);
    try rb.push(2);
    try rb.push(3);
    try std.testing.expectEqual(rb.pop(), 1);
    try rb.push(4);
    try std.testing.expectEqual(rb.pop(), 2);
}

test "Queue test" {
    var q = Queue(i32).init(std.testing.allocator);
    defer q.deinit();

    try q.enqueue(100);
    try q.enqueue(200);
    try std.testing.expectEqual(q.dequeue(), 100);
    try std.testing.expectEqual(q.dequeue(), 200);
}

test "HashSet and HashMap test" {
    var set = HashSet(i32).init(std.testing.allocator);
    defer set.deinit();

    try std.testing.expect(try set.insert(5));
    try std.testing.expect(!try set.insert(5));
    try std.testing.expect(set.contains(5));

    var map = HashMap(i32, []const u8).init(std.testing.allocator);
    defer map.deinit();

    try map.put(1, "one");
    try std.testing.expectEqualStrings(map.get(1).?, "one");
}

test "DynamicArray test" {
    var da = DynamicArray(i32).init();
    defer da.deinit(std.testing.allocator);

    try da.append(std.testing.allocator, 10);
    try da.append(std.testing.allocator, 20);
    try std.testing.expectEqual(da.len(), 2);
    try std.testing.expectEqual(da.get(1), 20);
}
