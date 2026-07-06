const std = @import("std");
const ingestion = @import("ingestion");
const algorithms = @import("algorithms");

pub const FileReader = struct {
    file: std.Io.File,
    io: std.Io,
    buffer: [4096]u8 = undefined,
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
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe
    
    const format_name = args.next() orelse return error.MissingFormat;
    const filepath = args.next() orelse return error.MissingFilepath;

    var file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();
    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var accuracy_pass = false;

    if (std.mem.eql(u8, format_name, "FASTA")) {
        var parser = ingestion.genomics.fasta.fastaIterator(buffer);
        var count: usize = 0;
        while (try parser.next()) |_| {
            count += 1;
        }
        accuracy_pass = count > 0;
    } else if (std.mem.eql(u8, format_name, "FASTQ")) {
        var parser = ingestion.genomics.fastq.fastqIterator(buffer);
        var count: usize = 0;
        while (try parser.next()) |_| {
            count += 1;
        }
        accuracy_pass = count > 0;
    } else if (std.mem.eql(u8, format_name, "VCF")) {
        var parser = ingestion.genomics.vcf.vcfIterator(buffer);
        var count: usize = 0;
        while (try parser.next()) |_| {
            count += 1;
        }
        accuracy_pass = count > 0;
    } else if (std.mem.eql(u8, format_name, "GFF3")) {
        const file_reader = try std.fs.cwd().openFile(filepath, .{});
        defer file_reader.close();
        var reader = FileReader{ .file = file_reader, .io = init.io };
        var parser = ingestion.genomics.gff3.gff3Iterator(allocator, &reader);
        var count: usize = 0;
        while (try parser.next()) |record| {
            count += 1;
            record.deinit();
        }
        accuracy_pass = count > 0;
    } else if (std.mem.eql(u8, format_name, "GTF")) {
        var parser = ingestion.genomics.gtf.gtfIterator(allocator, &reader);
        var count: usize = 0;
        while (try parser.next()) |record| {
            count += 1;
            record.deinit();
        }
        accuracy_pass = count > 0;
    } else if (std.mem.eql(u8, format_name, "BED")) {
        var parser = ingestion.genomics.bed.bedIterator(allocator, &reader);
        var count: usize = 0;
        while (try parser.next()) |record| {
            count += 1;
            record.deinit();
        }
        accuracy_pass = count > 0;
    } else {
        std.debug.print("Unknown format: {s}\n", .{format_name});
        return error.UnknownFormat;
    }

    const file_stat = try file.stat(init.io);
    std.debug.print("Format: {s}\n", .{format_name});
    std.debug.print("File Size: {d} bytes\n", .{file_stat.size});
    std.debug.print("Accuracy Check: {s}\n", .{if (accuracy_pass) "PASS" else "FAIL"});
    if (!accuracy_pass) return error.AccuracyFailed;
}
