const std = @import("std");
const bzip2 = @import("core/bzip2.zig");

const DummyReader = struct {
    data: []const u8,
    pos: usize,
    
    pub fn init(data: []const u8) DummyReader {
        return .{ .data = data, .pos = 0 };
    }
    
    pub fn readByte(self: *DummyReader) !u8 {
        if (self.pos >= self.data.len) return error.EndOfStream;
        const b = self.data[self.pos];
        self.pos += 1;
        return b;
    }
};

const DummyWriter = struct {
    buffer: []u8,
    pos: usize,

    pub fn writeByte(self: *DummyWriter, byte: u8) !void {
        if (self.pos >= self.buffer.len) return error.BufferOverflow;
        self.buffer[self.pos] = byte;
        self.pos += 1;
    }
};

const test_data = @import("test_data.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const compressed = &test_data.compressed_data;
    const original = &test_data.original_data;

    var reader = DummyReader.init(compressed);
    var decompressor = bzip2.Bzip2Decompressor(*DummyReader).init(allocator, &reader);

    const out_buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(out_buffer);

    var writer = DummyWriter{ .buffer = out_buffer, .pos = 0 };

    decompressor.decompress(&writer) catch |err| {
        std.debug.print("Decompression failed with error: {}\n", .{err});
        std.debug.print("Writer pos: {}\nGot: {s}\n", .{writer.pos, out_buffer[0..writer.pos]});
        std.process.exit(1);
    };

    if (std.mem.eql(u8, original, out_buffer[0..writer.pos])) {
        std.debug.print("SUCCESS: Decompressed data perfectly matches original.\n", .{});
    } else {
        std.debug.print("FAILED: Output mismatch. Writer pos: {}\nExpected: {s}\nGot: {s}\n", .{writer.pos, original, out_buffer[0..writer.pos]});
        std.process.exit(1);
    }
}
