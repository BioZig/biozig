const std = @import("std");
const ingestion = @import("ingestion");

// Dummy reader that just loops data
pub const MockGBReader = struct {
    chunk: []const u8,
    pos: usize = 0,
    bytes_read: usize = 0,
    target_bytes: usize = 1024 * 1024 * 1024, // 1GB

    pub fn readByte(self: *MockGBReader) !u8 {
        if (self.bytes_read >= self.target_bytes) {
            return error.EndOfStream;
        }
        if (self.pos >= self.chunk.len) {
            self.pos = 0;
        }
        const b = self.chunk[self.pos];
        self.pos += 1;
        self.bytes_read += 1;
        return b;
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe

    const format_name = args.next() orelse return error.MissingFormat;

    std.debug.print("Benchmarking format {s} for 1GB streaming throughput\n", .{format_name});

    if (std.mem.eql(u8, format_name, "VCF")) {
        const vcf_chunk = "chr1\t1000\t.\tA\tT\t100\tPASS\t.\tGT\t0/1\n";
        var reader = MockGBReader{ .chunk = vcf_chunk };
        var parser = ingestion.genomics.vcf.VcfIterator(*MockGBReader).init(allocator, &reader);
        var count: usize = 0;
        while (try parser.next()) |record| {
            count += 1;
            var mut_rec = record;
            mut_rec.deinit();
        }
        std.debug.print("Parsed {d} VCF records\n", .{count});
    } else {
        std.debug.print("Format {s} not fully implemented in mock bench\n", .{format_name});
    }
}
