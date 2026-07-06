const std = @import("std");

pub const MMapReader = struct {
    file: std.Io.File,
    mmap: std.Io.File.MemoryMap,
    threaded: std.Io.Threaded,
    data: []const u8,
    is_empty: bool,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !MMapReader {
        var threaded = std.Io.Threaded.init(allocator, .{});
        errdefer threaded.deinit();

        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        const file = try std.Io.Dir.openFile(cwd, io, path, .{ .mode = .read_only });
        errdefer std.Io.File.close(file, io);

        const stat = try std.Io.File.stat(file, io);
        const size = stat.size;

        if (size == 0) {
            return MMapReader{
                .file = file,
                .mmap = undefined,
                .threaded = threaded,
                .data = &[_]u8{},
                .is_empty = true,
            };
        }

        var mm = try std.Io.File.createMemoryMap(file, io, .{
            .len = size,
            .protection = .{ .read = true, .write = false },
        });
        try std.Io.File.MemoryMap.read(&mm, io);

        return MMapReader{
            .file = file,
            .mmap = mm,
            .threaded = threaded,
            .data = mm.memory[0..size],
            .is_empty = false,
        };
    }

    pub fn deinit(self: *MMapReader) void {
        const io = self.threaded.io();
        if (!self.is_empty) {
            std.Io.File.MemoryMap.destroy(&self.mmap, io);
        }
        std.Io.File.close(self.file, io);
        self.threaded.deinit();
    }
};

test "MMapReader basic" {
    const tmp_file_path = "mmap_test_file.txt";
    const content = "Hello, world! This is a test for mmap.";

    {
        var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        const file = try std.Io.Dir.createFile(cwd, io, tmp_file_path, .{});
        defer std.Io.File.close(file, io);
        try std.Io.File.writePositionalAll(file, io, content, 0);
    }
    defer {
        var threaded = std.Io.Threaded.init(std.testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        std.Io.Dir.deleteFile(cwd, io, tmp_file_path) catch {};
    }

    var reader = try MMapReader.init(std.testing.allocator, tmp_file_path);
    defer reader.deinit();

    try std.testing.expectEqualStrings(content, reader.data);
}
