const std = @import("std");
const core = @import("core");

test "io buffered reader/writer edge cases" {
    // 0 byte write
    var dest_buffer: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&dest_buffer);
    var buf_writer = core.io.BufferedWriter(*std.Io.Writer, 8).init(&writer);

    const written = try buf_writer.write("");
    try std.testing.expectEqual(written, 0);

    // Test the 0 byte read
    var reader = std.Io.Reader.fixed("");
    var buf_reader = core.io.BufferedReader(*std.Io.Reader, 8).init(&reader);
    var dest: [1]u8 = undefined;
    const read = try buf_reader.read(&dest);
    try std.testing.expectEqual(read, 0);
}
