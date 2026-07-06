const std = @import("std");
const ingestion = @import("ingestion");
const structural = @import("structural");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe

    const format_name = args.next() orelse return error.MissingFormat;
    const filepath = args.next() orelse return error.MissingFilepath;

    const file = try std.Io.Dir.openFileAbsolute(init.io, filepath, .{});
    defer file.close(init.io);

    const file_stat = try file.stat(init.io);
    const buffer = try std.posix.mmap(null, file_stat.size, std.posix.PROT.READ, std.posix.MAP.PRIVATE, file.handle, 0);
    defer std.posix.munmap(buffer);

    var accuracy_pass = false;

    if (std.mem.eql(u8, format_name, "PDB")) {
        const coords = try ingestion.structural.pdb.parsePdbCoords(allocator, buffer);
        accuracy_pass = coords.len > 0;
    } else {
        std.debug.print("Unknown format: {s}\n", .{format_name});
        return error.UnknownFormat;
    }

    std.debug.print("Format: {s}\n", .{format_name});
    std.debug.print("File Size: {d} bytes\n", .{file_stat.size});
    std.debug.print("Accuracy Check: {s}\n", .{if (accuracy_pass) "PASS" else "FAIL"});
    if (!accuracy_pass) return error.AccuracyFailed;
}
