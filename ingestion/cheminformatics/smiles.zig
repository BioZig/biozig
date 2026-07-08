const std = @import("std");

pub fn smilesStreamIterator(reader: anytype, buffer: []u8) SmilesStreamIterator(@TypeOf(reader)) {
    return SmilesStreamIterator(@TypeOf(reader)).init(reader, buffer);
}

pub fn SmilesStreamIterator(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        buffer: []u8,
        pos: usize = 0,
        valid_len: usize = 0,
        eof: bool = false,
        bytes_read: usize = 0,

        const Self = @This();

        pub fn init(reader: ReaderType, buffer: []u8) Self {
            return .{
                .reader = reader,
                .buffer = buffer,
            };
        }

        fn fill(self: *Self) !void {
            if (self.eof) return;
            if (self.pos > 0 and self.valid_len > self.pos) {
                std.mem.copyForwards(u8, self.buffer[0 .. self.valid_len - self.pos], self.buffer[self.pos .. self.valid_len]);
                self.valid_len -= self.pos;
            } else if (self.pos == self.valid_len) {
                self.valid_len = 0;
            }
            self.pos = 0;
            var data: [1][]u8 = .{ self.buffer[self.valid_len..] };
            const read_len = self.reader.readVec(&data) catch |err| switch (err) {
                error.EndOfStream => @as(usize, 0),
                else => return err,
            };
            if (read_len == 0) {
                self.eof = true;
            }
            self.valid_len += read_len;
            self.bytes_read += read_len;
        }

        pub fn nextChunk(self: *Self) !?[]const u8 {
            if (self.eof and self.pos == self.valid_len) return null;
            try self.fill();
            if (self.pos == self.valid_len) return null;
            const chunk = self.buffer[self.pos..self.valid_len];
            self.pos = self.valid_len;
            return chunk;
        }
    };
}
