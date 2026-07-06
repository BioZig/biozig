const std = @import("std");

pub fn PackedIntArray(comptime bits: usize) type {
    std.debug.assert(bits >= 1 and bits <= 8);
    return struct {
        bytes: []u8,
        len: usize,

        const Self = @This();

        pub fn init(bytes: []u8, len: usize) Self {
            std.debug.assert(bytes.len >= requiredBytes(len));
            return .{ .bytes = bytes, .len = len };
        }

        pub fn requiredBytes(element_count: usize) usize {
            const total_bits = element_count * bits;
            return (total_bits + 7) / 8;
        }

        pub fn get(self: Self, index: usize) u8 {
            std.debug.assert(index < self.len);
            const bit_offset = index * bits;
            const byte_index = bit_offset / 8;
            const bit_shift = @as(u3, @truncate(bit_offset % 8));

            const mask = @as(u32, (1 << bits) - 1);

            var val: u32 = self.bytes[byte_index];
            if (@as(usize, bit_shift) + bits > 8) {
                val |= @as(u32, self.bytes[byte_index + 1]) << 8;
            }

            return @as(u8, @truncate((val >> bit_shift) & mask));
        }

        pub fn set(self: Self, index: usize, value: u8) void {
            std.debug.assert(index < self.len);
            const bit_offset = index * bits;
            const byte_index = bit_offset / 8;
            const bit_shift = @as(u3, @truncate(bit_offset % 8));

            const mask = @as(u32, (1 << bits) - 1);
            const clean_val = @as(u32, value) & mask;

            if (@as(usize, bit_shift) + bits <= 8) {
                const byte_mask = @as(u8, @truncate(~(mask << bit_shift)));
                self.bytes[byte_index] = (self.bytes[byte_index] & byte_mask) | @as(u8, @truncate(clean_val << bit_shift));
            } else {
                var val: u32 = self.bytes[byte_index] | (@as(u32, self.bytes[byte_index + 1]) << 8);
                const span_mask = ~(mask << bit_shift);
                val = (val & span_mask) | (clean_val << bit_shift);
                self.bytes[byte_index] = @as(u8, @truncate(val & 0xFF));
                self.bytes[byte_index + 1] = @as(u8, @truncate((val >> 8) & 0xFF));
            }
        }
    };
}

pub const BitReader = struct {
    bytes: []const u8,
    bit_offset: usize = 0,

    pub fn init(bytes: []const u8) BitReader {
        return .{ .bytes = bytes };
    }

    pub fn readBits(self: *BitReader, comptime T: type, num_bits: usize) !T {
        if (num_bits == 0) return 0;
        if (self.bit_offset + num_bits > self.bytes.len * 8) {
            return error.EndOfStream;
        }

        const max_bits = @sizeOf(T) * 8;
        std.debug.assert(num_bits <= max_bits);

        var result: u64 = 0;
        var bits_read: usize = 0;

        while (bits_read < num_bits) {
            const byte_index = self.bit_offset / 8;
            const bit_shift = @as(usize, @intCast(self.bit_offset % 8));
            const bits_in_current_byte = 8 - bit_shift;
            const bits_to_take = @min(num_bits - bits_read, bits_in_current_byte);

            const byte_val = self.bytes[byte_index];
            const mask = (@as(u32, 1) << @as(u5, @intCast(bits_to_take))) - 1;
            const extracted = (byte_val >> @as(u3, @truncate(bit_shift))) & mask;

            result |= @as(u64, extracted) << @as(u6, @intCast(bits_read));

            self.bit_offset += bits_to_take;
            bits_read += bits_to_take;
        }

        const UnsignedT = std.meta.Int(.unsigned, max_bits);
        const casted = @as(UnsignedT, @truncate(result));
        return @bitCast(casted);
    }

    pub fn alignToByte(self: *BitReader) void {
        self.bit_offset = ((self.bit_offset + 7) / 8) * 8;
    }
};

pub const BitWriter = struct {
    bytes: []u8,
    bit_offset: usize = 0,

    pub fn init(bytes: []u8) BitWriter {
        @memset(bytes, 0);
        return .{ .bytes = bytes };
    }

    pub fn writeBits(self: *BitWriter, value: anytype, num_bits: usize) !void {
        if (num_bits == 0) return;
        if (self.bit_offset + num_bits > self.bytes.len * 8) {
            return error.NoSpaceLeft;
        }

        const T = @TypeOf(value);
        const max_bits = @sizeOf(T) * 8;
        std.debug.assert(num_bits <= max_bits);

        const casted_val = @as(std.meta.Int(.unsigned, max_bits), @bitCast(value));
        const mask = if (num_bits == 64) 0xFFFFFFFFFFFFFFFF else (@as(u64, 1) << @as(u6, @intCast(num_bits))) - 1;
        const clean_val = @as(u64, casted_val) & mask;
        var bits_written: usize = 0;

        while (bits_written < num_bits) {
            const byte_index = self.bit_offset / 8;
            const bit_shift = @as(usize, @intCast(self.bit_offset % 8));
            const bits_in_current_byte = 8 - bit_shift;
            const bits_to_write = @min(num_bits - bits_written, bits_in_current_byte);

            const write_mask = @as(u8, @truncate((@as(u32, 1) << @as(u5, @intCast(bits_to_write))) - 1));
            const chunk = @as(u8, @truncate((clean_val >> @as(u6, @intCast(bits_written))) & write_mask));

            self.bytes[byte_index] &= ~(@as(u8, write_mask) << @as(u3, @truncate(bit_shift)));
            self.bytes[byte_index] |= chunk << @as(u3, @truncate(bit_shift));

            self.bit_offset += bits_to_write;
            bits_written += bits_to_write;
        }
    }

    pub fn flush(self: *BitWriter) void {
        self.bit_offset = ((self.bit_offset + 7) / 8) * 8;
    }
};

test "packed int array 1-bit (bit array)" {
    var buffer: [2]u8 = undefined;
    const array = PackedIntArray(1).init(&buffer, 16);

    array.set(0, 1);
    array.set(1, 0);
    array.set(15, 1);

    try std.testing.expectEqual(array.get(0), 1);
    try std.testing.expectEqual(array.get(1), 0);
    try std.testing.expectEqual(array.get(15), 1);
}

test "packed int array 2-bit, 4-bit, 5-bit, 8-bit" {
    var buffer: [10]u8 = undefined;

    // 2-bit
    const arr2 = PackedIntArray(2).init(&buffer, 20);
    arr2.set(0, 3);
    arr2.set(5, 2);
    try std.testing.expectEqual(arr2.get(0), 3);
    try std.testing.expectEqual(arr2.get(5), 2);

    // 5-bit
    const arr5 = PackedIntArray(5).init(&buffer, 10);
    arr5.set(0, 31);
    arr5.set(1, 15);
    arr5.set(9, 7);
    try std.testing.expectEqual(arr5.get(0), 31);
    try std.testing.expectEqual(arr5.get(1), 15);
    try std.testing.expectEqual(arr5.get(9), 7);
}

test "bit reader and bit writer roundtrip" {
    var buffer: [16]u8 = undefined;
    var writer = BitWriter.init(&buffer);

    try writer.writeBits(@as(u32, 0x12345678), 32);
    try writer.writeBits(@as(u8, 5), 3);
    try writer.writeBits(@as(u8, 27), 5);
    try writer.writeBits(@as(u64, 0xDEADBEEFCAFEBABE), 64);

    var reader = BitReader.init(&buffer);
    try std.testing.expectEqual(try reader.readBits(u32, 32), 0x12345678);
    try std.testing.expectEqual(try reader.readBits(u8, 3), 5);
    try std.testing.expectEqual(try reader.readBits(u8, 5), 27);
    try std.testing.expectEqual(try reader.readBits(u64, 64), 0xDEADBEEFCAFEBABE);
}
