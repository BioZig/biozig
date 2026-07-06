const std = @import("std");

/// Aligns a value up to the next multiple of alignment.
/// Alignment must be a power of two.
pub fn alignUp(addr: usize, alignment: usize) usize {
    std.debug.assert(std.math.isPowerOfTwo(alignment));
    return (addr + (alignment - 1)) & ~(alignment - 1);
}

/// Aligns a value down to the previous multiple of alignment.
/// Alignment must be a power of two.
pub fn alignDown(addr: usize, alignment: usize) usize {
    std.debug.assert(std.math.isPowerOfTwo(alignment));
    return addr & ~(alignment - 1);
}

/// Checks if an address or pointer is aligned.
pub fn isAligned(addr: usize, alignment: usize) bool {
    std.debug.assert(std.math.isPowerOfTwo(alignment));
    return (addr & (alignment - 1)) == 0;
}

/// A read/write view over a byte slice with explicit endianness.
pub const MemoryView = struct {
    bytes: []u8,

    pub fn init(bytes: []u8) MemoryView {
        return .{ .bytes = bytes };
    }

    pub fn readInt(self: MemoryView, comptime T: type, offset: usize, endian: std.builtin.Endian) T {
        const size = @sizeOf(T);
        std.debug.assert(offset + size <= self.bytes.len);
        const sub = self.bytes[offset..][0..size];
        return std.mem.readInt(T, sub, endian);
    }

    pub fn writeInt(self: MemoryView, comptime T: type, offset: usize, value: T, endian: std.builtin.Endian) void {
        const size = @sizeOf(T);
        std.debug.assert(offset + size <= self.bytes.len);
        const sub = self.bytes[offset..][0..size];
        std.mem.writeInt(T, sub, value, endian);
    }

    pub fn readFloat(self: MemoryView, comptime T: type, offset: usize, endian: std.builtin.Endian) T {
        const IntT = std.meta.Int(.unsigned, @sizeOf(T) * 8);
        const int_val = self.readInt(IntT, offset, endian);
        return @bitCast(int_val);
    }

    pub fn writeFloat(self: MemoryView, comptime T: type, offset: usize, value: T, endian: std.builtin.Endian) void {
        const IntT = std.meta.Int(.unsigned, @sizeOf(T) * 8);
        const int_val: IntT = @bitCast(value);
        self.writeInt(IntT, offset, int_val, endian);
    }
};

/// A read-only view over a byte slice.
pub const ReadOnlyMemoryView = struct {
    bytes: []const u8,

    pub fn init(bytes: []const u8) ReadOnlyMemoryView {
        return .{ .bytes = bytes };
    }

    pub fn readInt(self: ReadOnlyMemoryView, comptime T: type, offset: usize, endian: std.builtin.Endian) T {
        const size = @sizeOf(T);
        std.debug.assert(offset + size <= self.bytes.len);
        const sub = self.bytes[offset..][0..size];
        return std.mem.readInt(T, sub, endian);
    }

    pub fn readFloat(self: ReadOnlyMemoryView, comptime T: type, offset: usize, endian: std.builtin.Endian) T {
        const IntT = std.meta.Int(.unsigned, @sizeOf(T) * 8);
        const int_val = self.readInt(IntT, offset, endian);
        return @bitCast(int_val);
    }
};

/// Safely casts a byte slice to a slice of type T, verifying alignment and length.
pub fn bytesAsSlice(comptime T: type, bytes: []u8) ![]T {
    const alignment = @alignOf(T);
    const ptr_val = @intFromPtr(bytes.ptr);
    if (!isAligned(ptr_val, alignment)) {
        return error.MisalignedPointer;
    }
    if (bytes.len % @sizeOf(T) != 0) {
        return error.InvalidLength;
    }
    const count = bytes.len / @sizeOf(T);
    return @as([*]T, @ptrCast(@alignCast(bytes.ptr)))[0..count];
}

/// Safely casts a const byte slice to a const slice of type T.
pub fn bytesAsConstSlice(comptime T: type, bytes: []const u8) ![]const T {
    const alignment = @alignOf(T);
    const ptr_val = @intFromPtr(bytes.ptr);
    if (!isAligned(ptr_val, alignment)) {
        return error.MisalignedPointer;
    }
    if (bytes.len % @sizeOf(T) != 0) {
        return error.InvalidLength;
    }
    const count = bytes.len / @sizeOf(T);
    return @as([*]const T, @ptrCast(@alignCast(bytes.ptr)))[0..count];
}

test "alignment helpers" {
    try std.testing.expectEqual(alignUp(5, 4), 8);
    try std.testing.expectEqual(alignUp(8, 4), 8);
    try std.testing.expectEqual(alignDown(7, 4), 4);
    try std.testing.expectEqual(alignDown(8, 4), 8);
    try std.testing.expect(isAligned(16, 8));
    try std.testing.expect(!isAligned(15, 8));
}

test "memory view read and write" {
    var buffer: [32]u8 = undefined;
    const view = MemoryView.init(&buffer);

    view.writeInt(u32, 0, 0x12345678, .little);
    try std.testing.expectEqual(view.readInt(u32, 0, .little), 0x12345678);

    view.writeInt(u32, 4, 0x12345678, .big);
    try std.testing.expectEqual(view.readInt(u32, 4, .big), 0x12345678);

    view.writeFloat(f32, 8, 3.14159, .little);
    try std.testing.expectApproxEqAbs(view.readFloat(f32, 8, .little), 3.14159, 1e-5);
}

test "read-only memory view" {
    const raw_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    const view = ReadOnlyMemoryView.init(&raw_data);
    try std.testing.expectEqual(view.readInt(u32, 0, .little), 0x12345678);
}

test "bytesAsSlice casts" {
    var buffer align(@alignOf(u32)) = [_]u8{ 1, 0, 0, 0, 2, 0, 0, 0 };
    const slice = try bytesAsSlice(u32, &buffer);
    try std.testing.expectEqual(slice.len, 2);
    try std.testing.expectEqual(slice[0], 1);
    try std.testing.expectEqual(slice[1], 2);

    const const_slice = try bytesAsConstSlice(u32, &buffer);
    try std.testing.expectEqual(const_slice.len, 2);
    try std.testing.expectEqual(const_slice[0], 1);
}
