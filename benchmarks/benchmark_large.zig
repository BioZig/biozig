const std = @import("std");
const ingestion = @import("ingestion");
const structural = @import("structural");

pub const FileReader = struct {
    file: std.Io.File,
    io: std.Io,
    buffer: [65536]u8 = undefined,
    pos: usize = 0,
    len: usize = 0,

    pub fn readByte(self: *FileReader) !u8 {
        if (self.pos >= self.len) {
            const buffers = &[_][]u8{ &self.buffer };
            self.len = try self.file.readStreaming(self.io, buffers);
            if (self.len == 0) return error.EndOfStream;
            self.pos = 0;
        }
        const b = self.buffer[self.pos];
        self.pos += 1;
        return b;
    }

    pub fn readAll(self: *FileReader, dest: []u8) !usize {
        var bytes_read: usize = 0;
        while (bytes_read < dest.len) {
            const b = self.readByte() catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };
            dest[bytes_read] = b;
            bytes_read += 1;
        }
        return bytes_read;
    }

    pub fn readNoEof(self: *FileReader, dest: []u8) !void {
        const amt = try self.readAll(dest);
        if (amt < dest.len) return error.EndOfStream;
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

    var count: usize = 0;

    if (std.mem.eql(u8, format_name, "VCF")) {
        var parser = ingestion.genomics.vcf.VcfIterator(*FileReader).init(allocator, &reader);
        while (try parser.next()) |record| {
            count += 1;
            var mut_record = record;
            mut_record.deinit();
        }
    } else if (std.mem.eql(u8, format_name, "MMCIF")) {
        const models = try ingestion.structural.mmcif.parseMmcif(allocator, &reader);
        count = models.len;
    } else if (std.mem.eql(u8, format_name, "BAM")) {
        var parser = ingestion.genomics.bam.BamIterator(*FileReader).init(allocator, &reader);
        while (try parser.next()) |record| {
            count += 1;
            _ = record;
        }
    } else if (std.mem.eql(u8, format_name, "CRAM")) {
        var parser = ingestion.genomics.cram.CramParser.init(allocator);
        var sequences = try parser.parseStream(&reader);
        count = sequences.items.len;
        for (sequences.items) |*seq| seq.deinit();
        sequences.deinit(allocator);
    } else {
        std.debug.print("Unknown format: {s}\n", .{format_name});
        return error.UnknownFormat;
    }

    std.debug.print("Parsed {d} records/models for {s}\n", .{count, format_name});
}
