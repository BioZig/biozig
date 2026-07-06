const std = @import("std");

pub const mmap = @import("mmap.zig");

/// A custom high-performance buffered reader.
pub fn BufferedReader(comptime ReaderType: type, comptime buffer_size: usize) type {
    return struct {
        inner_reader: ReaderType,
        buffer: [buffer_size]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        const Self = @This();

        pub fn init(reader: ReaderType) Self {
            return .{
                .inner_reader = reader,
            };
        }

        pub fn read(self: *Self, dest: []u8) !usize {
            var dest_idx: usize = 0;
            while (dest_idx < dest.len) {
                if (self.start == self.end) {
                    self.start = 0;
                    const Child = case: {
                        const info = @typeInfo(ReaderType);
                        break :case if (info == .pointer) info.pointer.child else ReaderType;
                    };
                    const n = if (comptime @hasDecl(Child, "readSliceShort"))
                        try self.inner_reader.readSliceShort(&self.buffer)
                    else
                        try self.inner_reader.read(&self.buffer);

                    self.end = n;
                    if (n == 0) break;
                }
                const available = self.end - self.start;
                const to_copy = @min(dest.len - dest_idx, available);
                @memcpy(dest[dest_idx..][0..to_copy], self.buffer[self.start..][0..to_copy]);
                self.start += to_copy;
                dest_idx += to_copy;
            }
            return dest_idx;
        }

        pub fn readByte(self: *Self) !u8 {
            var b: [1]u8 = undefined;
            const n = try self.read(&b);
            if (n == 0) return error.EndOfStream;
            return b[0];
        }
    };
}

/// A custom high-performance buffered writer.
pub fn BufferedWriter(comptime WriterType: type, comptime buffer_size: usize) type {
    return struct {
        inner_writer: WriterType,
        buffer: [buffer_size]u8 = undefined,
        pos: usize = 0,

        const Self = @This();

        pub fn init(writer: WriterType) Self {
            return .{
                .inner_writer = writer,
            };
        }

        pub fn write(self: *Self, src: []const u8) !usize {
            var src_idx: usize = 0;
            while (src_idx < src.len) {
                const available = buffer_size - self.pos;
                const to_copy = @min(src.len - src_idx, available);
                @memcpy(self.buffer[self.pos..][0..to_copy], src[src_idx..][0..to_copy]);
                self.pos += to_copy;
                src_idx += to_copy;

                if (self.pos == buffer_size) {
                    try self.flush();
                }
            }
            return src.len;
        }

        pub fn writeByte(self: *Self, b: u8) !void {
            const src = [1]u8{b};
            _ = try self.write(&src);
        }

        pub fn flush(self: *Self) !void {
            if (self.pos > 0) {
                const Child = case: {
                    const info = @typeInfo(WriterType);
                    break :case if (info == .pointer) info.pointer.child else WriterType;
                };
                if (comptime @hasDecl(Child, "writeAll")) {
                    try self.inner_writer.writeAll(self.buffer[0..self.pos]);
                } else {
                    var written: usize = 0;
                    while (written < self.pos) {
                        written += try self.inner_writer.write(self.buffer[written..self.pos]);
                    }
                }
                self.pos = 0;
            }
        }
    };
}

test "buffered reader basic test" {
    const data = "Hello, world! This is a test for the custom buffered reader.";
    var reader = std.Io.Reader.fixed(data);
    var buf_reader = BufferedReader(*std.Io.Reader, 8).init(&reader);

    var dest: [64]u8 = undefined;
    const n = try buf_reader.read(&dest);
    try std.testing.expectEqual(n, data.len);
    try std.testing.expectEqualStrings(dest[0..n], data);
}

test "buffered writer basic test" {
    var dest_buffer: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&dest_buffer);
    var buf_writer = BufferedWriter(*std.Io.Writer, 8).init(&writer);

    const message = "Custom buffered writer verification message.";
    _ = try buf_writer.write(message);
    try buf_writer.flush();

    const written = writer.buffered();
    try std.testing.expectEqualStrings(written, message);
}
