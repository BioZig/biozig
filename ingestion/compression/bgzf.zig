const std = @import("std");

/// A BGZF reader that decompresses blocks from an underlying reader.
pub const BgzfReader = struct {
    input: *std.Io.Reader,
    buffer: []u8,
    eof: bool,

    /// Initialize a new BGZF reader. `buffer` must be at least `std.compress.flate.max_window_len` (64KB).
    pub fn init(input: *std.Io.Reader, buffer: []u8) BgzfReader {
        std.debug.assert(buffer.len >= std.compress.flate.max_window_len);
        return .{
            .input = input,
            .buffer = buffer,
            .eof = false,
        };
    }

    /// Reads exactly one BGZF block, decompresses it into `out_buffer`.
    /// `out_buffer` should be large enough (usually 64KB, BGZF's max block size).
    /// Returns the number of uncompressed bytes, or 0 if EOF.
    pub fn readBlock(self: *BgzfReader, out_buffer: []u8) !usize {
        if (self.eof) return 0;

        const Header = extern struct {
            magic: u16 align(1),
            method: u8,
            flags: packed struct(u8) {
                text: bool,
                hcrc: bool,
                extra: bool,
                name: bool,
                comment: bool,
                reserved: u3,
            },
            mtime: u32 align(1),
            xfl: u8,
            os: u8,
        };
        const header = self.input.takeStruct(Header, .little) catch |err| switch(err) {
            error.EndOfStream => {
                self.eof = true;
                return 0;
            },
            else => return err,
        };

        if (header.magic != 0x8b1f or header.method != 0x08)
            return error.BadGzipHeader;

        var bgzf_block_size: ?u16 = null;
        if (header.flags.extra) {
            const extra_len = try self.input.takeInt(u16, .little);
            var read_extra: usize = 0;
            while (read_extra < extra_len) {
                const si1 = try self.input.takeByte();
                const si2 = try self.input.takeByte();
                const slen = try self.input.takeInt(u16, .little);
                read_extra += 4;
                if (si1 == 'B' and si2 == 'C' and slen == 2) {
                    bgzf_block_size = try self.input.takeInt(u16, .little);
                    read_extra += 2;
                } else {
                    try self.input.discardAll(slen);
                    read_extra += slen;
                }
            }
        }

        if (bgzf_block_size == null) return error.MissingBgzfBlockSize;

        if (header.flags.name) _ = try self.input.discardDelimiterInclusive(0);
        if (header.flags.comment) _ = try self.input.discardDelimiterInclusive(0);
        if (header.flags.hcrc) try self.input.discardAll(2);

        var dec = std.compress.flate.Decompress.init(self.input, .raw, self.buffer);
        var w = std.Io.Writer.fixed(out_buffer);
        _ = dec.reader.stream(&w, .unlimited) catch |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        };

        const decompressed_size = w.end;

        // Skip CRC32 and ISIZE (8 bytes)
        try self.input.discardAll(8);

        return decompressed_size;
    }
};

test "BgzfReader simple test" {
    const empty_buf: []const u8 = &[_]u8{};
    var reader = std.Io.Reader.fixed(empty_buf);
    var window_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var bgzf_reader = BgzfReader.init(&reader, &window_buf);

    var out_buf: [65536]u8 = undefined;
    const n = try bgzf_reader.readBlock(&out_buf);
    try std.testing.expectEqual(@as(usize, 0), n);
}
