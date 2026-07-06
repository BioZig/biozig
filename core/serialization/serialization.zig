const std = @import("std");

/// Recursively serializes a value to the writer in a deterministic format.
pub fn serialize(writer: anytype, value: anytype) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .bool => {
            try writer.writeByte(if (value) 1 else 0);
        },
        .int => {
            var bytes: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &bytes, value, .little);
            try writer.writeAll(&bytes);
        },
        .float => {
            const IntT = std.meta.Int(.unsigned, @sizeOf(T) * 8);
            const bits: IntT = @bitCast(value);
            try serialize(writer, bits);
        },
        .@"enum" => {
            const Tag = @typeInfo(T).@"enum".tag_type;
            try serialize(writer, @as(Tag, @intFromEnum(value)));
        },
        .array => {
            for (value) |elem| {
                try serialize(writer, elem);
            }
        },
        .pointer => |ptr_info| {
            switch (ptr_info.size) {
                .slice => {
                    const len = @as(u64, value.len);
                    try serialize(writer, len);
                    for (value) |elem| {
                        try serialize(writer, elem);
                    }
                },
                .one => {
                    try serialize(writer, value.*);
                },
                else => @compileError("Unsupported pointer type for serialization: " ++ @typeName(T)),
            }
        },
        .optional => {
            if (value) |val| {
                try writer.writeByte(1);
                try serialize(writer, val);
            } else {
                try writer.writeByte(0);
            }
        },
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |f| {
                try serialize(writer, @field(value, f.name));
            }
        },
        else => @compileError("Unsupported type for serialization: " ++ @typeName(T)),
    }
}

/// Recursively deserializes a value of type T from the reader.
pub fn deserialize(reader: anytype, comptime T: type, allocator: std.mem.Allocator) !T {
    switch (@typeInfo(T)) {
        .bool => {
            var b: [1]u8 = undefined;
            try reader.readSliceAll(&b);
            if (b[0] == 0) return false;
            if (b[0] == 1) return true;
            return error.InvalidBoolean;
        },
        .int => {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try reader.readSliceAll(&bytes);
            return std.mem.readInt(T, &bytes, .little);
        },
        .float => {
            const IntT = std.meta.Int(.unsigned, @sizeOf(T) * 8);
            const bits = try deserialize(reader, IntT, allocator);
            return @bitCast(bits);
        },
        .@"enum" => |enum_info| {
            const Tag = enum_info.tag_type;
            const tag_val = try deserialize(reader, Tag, allocator);
            return @enumFromInt(tag_val);
        },
        .array => |arr_info| {
            var result: T = undefined;
            for (&result) |*elem| {
                elem.* = try deserialize(reader, arr_info.child, allocator);
            }
            return result;
        },
        .pointer => |ptr_info| {
            switch (ptr_info.size) {
                .slice => {
                    const len = try deserialize(reader, u64, allocator);
                    const slice = try allocator.alloc(ptr_info.child, len);
                    errdefer allocator.free(slice);
                    for (slice) |*elem| {
                        elem.* = try deserialize(reader, ptr_info.child, allocator);
                    }
                    return slice;
                },
                else => @compileError("Unsupported pointer type for deserialization: " ++ @typeName(T)),
            }
        },
        .optional => |opt_info| {
            var present: [1]u8 = undefined;
            try reader.readSliceAll(&present);
            if (present[0] == 0) {
                return null;
            } else if (present[0] == 1) {
                return try deserialize(reader, opt_info.child, allocator);
            } else {
                return error.InvalidOptionalHeader;
            }
        },
        .@"struct" => |struct_info| {
            var result: T = undefined;
            inline for (struct_info.fields) |f| {
                @field(result, f.name) = try deserialize(reader, f.type, allocator);
            }
            return result;
        },
        else => @compileError("Unsupported type for deserialization: " ++ @typeName(T)),
    }
}

/// Recursively frees any memory allocated during deserialization.
pub fn free(allocator: std.mem.Allocator, value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .pointer => |ptr_info| {
            switch (ptr_info.size) {
                .slice => {
                    for (value) |elem| {
                        free(allocator, elem);
                    }
                    allocator.free(value);
                },
                else => {},
            }
        },
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |f| {
                free(allocator, @field(value, f.name));
            }
        },
        .optional => {
            if (value) |val| {
                free(allocator, val);
            }
        },
        else => {},
    }
}

const Color = enum(u8) {
    Red,
    Green,
    Blue,
};

const TestStruct = struct {
    id: u32,
    score: f64,
    color: Color,
    active: bool,
    description: []const u8,
    maybe_value: ?u16,
};

test "binary serialization roundtrip" {
    const original = TestStruct{
        .id = 12345,
        .score = 98.76,
        .color = .Green,
        .active = true,
        .description = "BioZig Serialization Test",
        .maybe_value = 42,
    };

    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try serialize(&writer, original);

    const serialized_slice = writer.buffered();

    var reader = std.Io.Reader.fixed(serialized_slice);
    const deserialized = try deserialize(&reader, TestStruct, std.testing.allocator);
    defer free(std.testing.allocator, deserialized);

    try std.testing.expectEqual(deserialized.id, original.id);
    try std.testing.expectApproxEqAbs(deserialized.score, original.score, 1e-5);
    try std.testing.expectEqual(deserialized.color, original.color);
    try std.testing.expectEqual(deserialized.active, original.active);
    try std.testing.expectEqualStrings(deserialized.description, original.description);
    try std.testing.expectEqual(deserialized.maybe_value, original.maybe_value);
}
