const std = @import("std");
const core = @import("core");
const MMapReader = core.io.mmap.MMapReader;
const testing = std.testing;

test "MMap Edge Case: Empty file (0 bytes)" {
    const tmp_path = "empty_mmap.txt";
    
    // Create empty file
    {
        var threaded = std.Io.Threaded.init(testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        const file = try std.Io.Dir.createFile(cwd, io, tmp_path, .{});
        std.Io.File.close(file, io);
    }
    defer {
        var threaded = std.Io.Threaded.init(testing.allocator, .{});
        defer threaded.deinit();
        std.Io.Dir.deleteFile(std.Io.Dir.cwd(), threaded.io(), tmp_path) catch {};
    }

    var reader = try MMapReader.init(testing.allocator, tmp_path);
    defer reader.deinit();
    
    // Should be successfully mapped but have 0 length
    try testing.expectEqual(@as(usize, 0), reader.data.len);
}

test "MMap Edge Case: File does not exist" {
    // Should return FileNotFound error
    try testing.expectError(error.FileNotFound, MMapReader.init(testing.allocator, "does_not_exist_at_all_12345.xyz"));
}

test "MMap Edge Case: Null byte file" {
    const tmp_path = "null_byte.txt";
    
    // Create file with just \0
    {
        var threaded = std.Io.Threaded.init(testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        const file = try std.Io.Dir.createFile(cwd, io, tmp_path, .{});
        defer std.Io.File.close(file, io);
        try std.Io.File.writePositionalAll(file, io, "\x00", 0);
    }
    defer {
        var threaded = std.Io.Threaded.init(testing.allocator, .{});
        defer threaded.deinit();
        std.Io.Dir.deleteFile(std.Io.Dir.cwd(), threaded.io(), tmp_path) catch {};
    }

    var reader = try MMapReader.init(testing.allocator, tmp_path);
    defer reader.deinit();
    
    try testing.expectEqual(@as(usize, 1), reader.data.len);
    try testing.expectEqual(@as(u8, 0), reader.data[0]);
}

test "MMap Edge Case: Read Only Protection" {
    const tmp_path = "readonly_mmap.txt";
    
    {
        var threaded = std.Io.Threaded.init(testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        const file = try std.Io.Dir.createFile(cwd, io, tmp_path, .{});
        defer std.Io.File.close(file, io);
        try std.Io.File.writePositionalAll(file, io, "test", 0);
    }
    defer {
        var threaded = std.Io.Threaded.init(testing.allocator, .{});
        defer threaded.deinit();
        std.Io.Dir.deleteFile(std.Io.Dir.cwd(), threaded.io(), tmp_path) catch {};
    }

    var reader = try MMapReader.init(testing.allocator, tmp_path);
    defer reader.deinit();
    
    // The data is a []const u8 slice. The compiler statically enforces read-only.
    // If we tried to cast it and mutate it, it would segfault in OS since the protection
    // is set to { .read = true, .write = false }.
    try testing.expectEqualStrings("test", reader.data);
}
