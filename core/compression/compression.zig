const std = @import("std");

pub const Format = enum {
    raw,
    zlib,
    gzip,

    pub fn toContainer(self: Format) std.compress.flate.Container {
        return switch (self) {
            .raw => .raw,
            .zlib => .zlib,
            .gzip => .gzip,
        };
    }
};

pub fn compress(dest: []u8, src: []const u8, format: Format) ![]const u8 {
    var writer = std.Io.Writer.fixed(dest);
    var history: [std.compress.flate.max_window_len]u8 = undefined;
    var compressor = try std.compress.flate.Compress.init(
        &writer,
        &history,
        format.toContainer(),
        std.compress.flate.Compress.Options.level_6,
    );
    try compressor.writer.writeAll(src);
    try compressor.finish();
    return writer.buffered();
}

pub fn decompress(dest: []u8, src: []const u8, format: Format) ![]const u8 {
    var reader = std.Io.Reader.fixed(src);
    var history: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(
        &reader,
        format.toContainer(),
        &history,
    );
    const n = try decompressor.reader.readSliceShort(dest);
    return dest[0..n];
}

test "raw, zlib, gzip compression roundtrip" {
    const original = "BioZig compression subsystem verification. Highly efficient and stack-allocated!";
    var compressed_buf: [1024]u8 = undefined;
    var decompressed_buf: [1024]u8 = undefined;

    inline for (std.meta.fields(Format)) |f| {
        const format = @as(Format, @enumFromInt(f.value));

        const comp = try compress(&compressed_buf, original, format);
        try std.testing.expect(comp.len > 0);

        const decomp = try decompress(&decompressed_buf, comp, format);
        try std.testing.expectEqualStrings(original, decomp);
    }
}
