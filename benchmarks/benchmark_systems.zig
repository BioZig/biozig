const std = @import("std");
const ingestion = @import("ingestion");
const systems = @import("systems");

pub const FileReader = struct {
    file: std.Io.File,
    io: std.Io,
    buffer: [4096]u8 = undefined,
    pos: usize = 0,
    len: usize = 0,

    pub fn readByte(self: *FileReader) !u8 {
        if (self.pos >= self.len) {
            const buffers = &[_][]u8{&self.buffer};
            self.len = try self.file.readStreaming(self.io, buffers);
            if (self.len == 0) return error.EndOfStream;
            self.pos = 0;
        }
        const b = self.buffer[self.pos];
        self.pos += 1;
        return b;
    }

    // For when the parser needs to read everything into memory (e.g. gpml parses from `[]const u8`)
    pub fn readAllAlloc(self: *FileReader, allocator: std.mem.Allocator, max_bytes: usize) ![]u8 {
        var list = std.ArrayList(u8).empty;
        errdefer list.deinit(allocator);
        var bytes_read: usize = 0;
        while (true) {
            const b = self.readByte() catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };
            if (bytes_read >= max_bytes) return error.FileTooLarge;
            try list.append(allocator, b);
            bytes_read += 1;
        }
        return try list.toOwnedSlice(allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe

    const format_name = args.next() orelse return error.MissingFormat;
    const filepath = args.next() orelse return error.MissingFilepath;

    const file = try std.Io.Dir.openFileAbsolute(init.io, filepath, .{});
    defer file.close(init.io);
    var reader = FileReader{ .file = file, .io = init.io };

    var accuracy_pass = false;

    if (std.mem.eql(u8, format_name, "GPML")) {
        const file_content = try reader.readAllAlloc(allocator, 1024 * 1024 * 100);
        defer allocator.free(file_content);
        var parser = ingestion.systems.gpml.GpmlParser.init(allocator);
        defer parser.deinit();
        const res = try parser.parse(file_content);
        accuracy_pass = res.net.nodes.items.len > 0 or res.path.members.count() > 0;
    } else if (std.mem.eql(u8, format_name, "BIOPAX")) {
        var parser = ingestion.systems.biopax.BiopaxParser.init(allocator);
        const res = try parser.parse(&reader);
        accuracy_pass = res.net.nodes.items.len > 0 or res.path.members.count() > 0;
    } else if (std.mem.eql(u8, format_name, "SBML")) {
        var parser = ingestion.systems.sbml.SbmlParser.init(allocator);
        const res = try parser.parse(&reader);
        accuracy_pass = res.net.nodes.items.len > 0 or res.path.members.count() > 0;
    } else {
        std.debug.print("Unknown format: {s}\n", .{format_name});
        return error.UnknownFormat;
    }

    const stat = try std.Io.File.stat(file, init.io);

    std.debug.print("Format: {s}\n", .{format_name});
    std.debug.print("File Size: {} bytes\n", .{stat.size});
    std.debug.print("Accuracy Check: {s}\n", .{if (accuracy_pass) "PASS" else "FAIL"});
}
