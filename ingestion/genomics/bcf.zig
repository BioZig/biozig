const std = @import("std");
const molecular = @import("molecular");
const variant = molecular.variant;

pub const BcfParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BcfParser {
        return .{
            .allocator = allocator,
        };
    }

    pub fn parseStream(self: *BcfParser, reader: anytype) !std.ArrayList(variant.Variant) {
        var variants = std.ArrayList(variant.Variant).empty;
        errdefer {
            for (variants.items) |*v| {
                v.deinit();
            }
            variants.deinit(self.allocator);
        }

        var magic: [5]u8 = undefined;
        var magic_n: usize = 0;
        while (magic_n < 5) {
            magic[magic_n] = reader.readByte() catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };
            magic_n += 1;
        }
        const n = magic_n;
        if (n < 5 or !std.mem.eql(u8, magic[0..3], "BCF")) {
            return error.InvalidBcfMagic;
        }

        const l_text = try readIntLocal(reader, u32);
        try skipBytesLocal(reader, l_text);

        while (true) {
            const l_shared = readIntLocal(reader, u32) catch |err| if (err == error.EndOfStream) break else return err;
            const l_indiv = try readIntLocal(reader, u32);
            _ = l_indiv;

            const shared_bytes = try self.allocator.alloc(u8, l_shared);
            defer self.allocator.free(shared_bytes);

            for (0..shared_bytes.len) |i| {
                shared_bytes[i] = try reader.readByte();
            }

            var sr = StringReader.init(shared_bytes);

            const chrom = try readIntLocal(&sr, i32);
            _ = chrom;
            const pos = try readIntLocal(&sr, i32);
            const rlen = try readIntLocal(&sr, i32);
            _ = rlen;
            const qual = try readIntLocal(&sr, u32);
            _ = qual;
            const n_info = try readIntLocal(&sr, u16);
            _ = n_info;
            const n_allele = try readIntLocal(&sr, u16);

            const n_fmt_sample = try readIntLocal(&sr, u32);
            _ = n_fmt_sample;

            // Read ID (usually a string, might be missing "0x07")
            _ = try skipTypedValue(&sr);

            // Read REF
            const ref_str = try readTypedValueString(&sr, self.allocator) orelse return error.MissingRef;
            defer self.allocator.free(ref_str);

            // Read ALT
            var alt_str: []u8 = undefined;
            if (n_allele > 1) {
                alt_str = try readTypedValueString(&sr, self.allocator) orelse return error.MissingAlt;
            } else {
                alt_str = try self.allocator.dupe(u8, "");
            }
            defer self.allocator.free(alt_str);

            if (pos >= 0) {
                const v = try variant.Variant.init(@as(usize, @intCast(pos)), ref_str, alt_str, self.allocator);
                try variants.append(self.allocator, v);
            }
        }

        return variants;
    }

    fn skipTypedValue(reader: anytype) !void {
        const type_byte = try reader.readByte();
        const type_id = type_byte & 0x0F;
        if (type_id == 0) return; // missing value

        var len: usize = @as(usize, type_byte >> 4);
        if (len == 15) {
            const ext_type_byte = try reader.readByte();
            const ext_type_id = ext_type_byte & 0x0F;
            if (ext_type_id == 1) {
                len = @as(usize, try reader.readByte());
            } else if (ext_type_id == 2) {
                len = @as(usize, try readIntLocal(reader, u16));
            } else if (ext_type_id == 3) {
                len = @as(usize, try readIntLocal(reader, u32));
            } else {
                return error.InvalidBcfType;
            }
        }

        var type_size: usize = 0;
        switch (type_id) {
            1 => type_size = 1, // Int8
            2 => type_size = 2, // Int16
            3 => type_size = 4, // Int32
            5 => type_size = 4, // Float32
            7 => type_size = 1, // Character/String
            else => return error.InvalidBcfType,
        }

        try skipBytesLocal(reader, len * type_size);
    }

    fn readTypedValueString(reader: anytype, allocator: std.mem.Allocator) !?[]u8 {
        const type_byte = try reader.readByte();
        const type_id = type_byte & 0x0F;
        if (type_id == 0) return null;
        if (type_id != 7) return error.InvalidBcfType;

        var len: usize = @as(usize, type_byte >> 4);
        if (len == 15) {
            const ext_type_byte = try reader.readByte();
            const ext_type_id = ext_type_byte & 0x0F;
            if (ext_type_id == 1) {
                len = @as(usize, try reader.readByte());
            } else if (ext_type_id == 2) {
                len = @as(usize, try readIntLocal(reader, u16));
            } else if (ext_type_id == 3) {
                len = @as(usize, try readIntLocal(reader, u32));
            } else {
                return error.InvalidBcfType;
            }
        }

        const str = try allocator.alloc(u8, len);
        for (0..str.len) |i| {
            str[i] = try reader.readByte();
        }
        return str;
    }
};

test "BcfParser: valid BCF" {
    const allocator = std.testing.allocator;

    // Construct a valid basic BCF in memory
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    var writer = StringWriter{ .list = &buf, .allocator = allocator };
    // Magic
    try writer.writeAll("BCF\x02\x02");

    // Header
    const header_text = "##fileformat=VCFv4.2\n";
    try writeIntTest(&writer, u32, @as(u32, @intCast(header_text.len)), .little);
    try writer.writeAll(header_text);

    // Record 1
    var shared_buf = std.ArrayList(u8).empty;
    defer shared_buf.deinit(allocator);
    var sw = StringWriter{ .list = &shared_buf, .allocator = allocator };

    try writeIntTest(&sw, i32, 0, .little); // chrom
    try writeIntTest(&sw, i32, 100, .little); // pos
    try writeIntTest(&sw, i32, 1, .little); // rlen
    try writeIntTest(&sw, u32, 0x7F800001, .little); // qual (missing f32)
    try writeIntTest(&sw, u16, 0, .little); // n_info
    try writeIntTest(&sw, u16, 2, .little); // n_allele
    try writeIntTest(&sw, u32, 0, .little); // n_fmt_sample

    // ID (missing)
    try sw.writeByte(0x07); // length 0, type string

    // REF "A"
    try sw.writeByte(0x17); // len=1, type=String
    try sw.writeAll("A");

    // ALT "G"
    try sw.writeByte(0x17); // len=1, type=String
    try sw.writeAll("G");

    // Write shared len
    try writeIntTest(&writer, u32, @as(u32, @intCast(shared_buf.items.len)), .little);
    try writeIntTest(&writer, u32, 0, .little); // l_indiv
    try writer.writeAll(shared_buf.items);

    var parser = BcfParser.init(allocator);
    var sr = StringReader.init(buf.items);

    var variants = try parser.parseStream(&sr);
    defer {
        for (variants.items) |*v| v.deinit();
        variants.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), variants.items.len);
    try std.testing.expectEqual(@as(usize, 100), variants.items[0].position);
    try std.testing.expectEqualStrings("A", variants.items[0].reference);
    try std.testing.expectEqualStrings("G", variants.items[0].alternate);
}

test "BcfParser: malformed BCF" {
    const allocator = std.testing.allocator;
    var parser = BcfParser.init(allocator);

    var sr = StringReader.init("NOTBCF");
    const res = parser.parseStream(&sr);
    try std.testing.expectError(error.InvalidBcfMagic, res);
}

test "BcfParser: invalid BCF" {
    const allocator = std.testing.allocator;
    var parser = BcfParser.init(allocator);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    var writer = StringWriter{ .list = &buf, .allocator = allocator };
    try writer.writeAll("BCF\x02\x02");
    try writeIntTest(&writer, u32, 0, .little); // empty header
    try writeIntTest(&writer, u32, 100, .little); // shared length = 100
    try writeIntTest(&writer, u32, 0, .little); // indiv length = 0
    // But then EOF right after!

    var sr = StringReader.init(buf.items);
    const res = parser.parseStream(&sr);
    try std.testing.expectError(error.EndOfStream, res);
}

test "BcfParser: roundtrip / serialization mock" {
    // Basic verification of architecture integration
    // BCF serialization normally maps to VCF or BGZF. Here we test memory stability
    const allocator = std.testing.allocator;
    var parser = BcfParser.init(allocator);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    var writer = StringWriter{ .list = &buf, .allocator = allocator };
    try writer.writeAll("BCF\x02\x02");
    try writeIntTest(&writer, u32, 0, .little); // empty header

    var sr = StringReader.init(buf.items);
    var variants = try parser.parseStream(&sr);
    defer variants.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), variants.items.len);
}

const StringReader = struct {
    buffer: []const u8,
    pos: usize = 0,
    pub fn init(b: []const u8) StringReader {
        return .{ .buffer = b };
    }
    pub fn readByte(self: *@This()) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const c = self.buffer[self.pos];
        self.pos += 1;
        return c;
    }
};

const StringWriter = struct {
    list: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pub fn writeByte(self: *@This(), b: u8) !void {
        try self.list.append(self.allocator, b);
    }
    pub fn writeAll(self: *@This(), s: []const u8) !void {
        try self.list.appendSlice(self.allocator, s);
    }
};

fn readIntLocal(reader: anytype, comptime T: type) !T {
    var bytes: [@sizeOf(T)]u8 = undefined;
    for (0..@sizeOf(T)) |i| {
        bytes[i] = try reader.readByte();
    }
    return std.mem.readInt(T, &bytes, .little);
}

fn skipBytesLocal(reader: anytype, count: usize) !void {
    for (0..count) |_| {
        _ = reader.readByte() catch |err| {
            if (err == error.EndOfStream) return;
            return err;
        };
    }
}

fn writeIntTest(writer: anytype, comptime T: type, val: T, endian: std.builtin.Endian) !void {
    _ = endian;
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, val, .little);
    try writer.writeAll(&bytes);
}
