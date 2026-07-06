const std = @import("std");
const io = std.Io;

pub const ChunkStreamer = struct {
    file: io.File,
    threaded: io.Threaded,
    buffer: []u8,
    buffer_pos: usize,
    buffer_end: usize,
    file_offset: u64,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, buffer_size: usize) !ChunkStreamer {
        var threaded = io.Threaded.init(allocator, .{});
        errdefer threaded.deinit();

        const _io = threaded.io();
        const cwd = io.Dir.cwd();
        
        const file = try io.Dir.openFile(cwd, _io, path, .{ .mode = .read_only });
        errdefer io.File.close(file, _io);

        const buffer = try allocator.alloc(u8, buffer_size);
        errdefer allocator.free(buffer);

        return ChunkStreamer{
            .file = file,
            .threaded = threaded,
            .buffer = buffer,
            .buffer_pos = 0,
            .buffer_end = 0,
            .file_offset = 0,
        };
    }

    pub fn deinit(self: *ChunkStreamer, allocator: std.mem.Allocator) void {
        const _io = self.threaded.io();
        allocator.free(self.buffer);
        io.File.close(self.file, _io);
        self.threaded.deinit();
    }

    pub fn nextChunk(self: *ChunkStreamer, max_bytes: usize) !?[]const u8 {
        if (self.buffer_pos == self.buffer_end) {
            self.buffer_pos = 0;
            const _io = self.threaded.io();
            const bytes_read = try io.File.readPositionalAll(self.file, _io, self.buffer, self.file_offset);
            if (bytes_read == 0) return null;
            self.buffer_end = bytes_read;
            self.file_offset += bytes_read;
        }

        const chunk_size = @min(self.buffer_end - self.buffer_pos, max_bytes);
        const chunk = self.buffer[self.buffer_pos .. self.buffer_pos + chunk_size];
        self.buffer_pos += chunk_size;
        return chunk;
    }
};

test "ChunkStreamer basic" {
    const tmp_file_path = "streamer_test_file.txt";
    const content = "1234567890ABCDEF";
    
    {
        var threaded = io.Threaded.init(std.testing.allocator, .{});
        defer threaded.deinit();
        const _io = threaded.io();
        const cwd = io.Dir.cwd();
        
        const file = try io.Dir.createFile(cwd, _io, tmp_file_path, .{});
        defer io.File.close(file, _io);
        try io.File.writePositionalAll(file, _io, content, 0);
    }
    defer {
        var threaded = io.Threaded.init(std.testing.allocator, .{});
        defer threaded.deinit();
        const _io = threaded.io();
        const cwd = io.Dir.cwd();
        io.Dir.deleteFile(cwd, _io, tmp_file_path) catch {};
    }

    var streamer = try ChunkStreamer.init(std.testing.allocator, tmp_file_path, 8);
    defer streamer.deinit(std.testing.allocator);

    const chunk1 = (try streamer.nextChunk(5)).?;
    try std.testing.expectEqualStrings("12345", chunk1);
    
    const chunk2 = (try streamer.nextChunk(5)).?;
    try std.testing.expectEqualStrings("678", chunk2);

    const chunk3 = (try streamer.nextChunk(5)).?;
    try std.testing.expectEqualStrings("90ABC", chunk3);

    const chunk4 = (try streamer.nextChunk(5)).?;
    try std.testing.expectEqualStrings("DEF", chunk4);

    const chunk5 = try streamer.nextChunk(5);
    try std.testing.expect(chunk5 == null);
}
