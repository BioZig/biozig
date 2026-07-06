const std = @import("std");
const c_api = @import("c_api.zig");
const core = @import("core");
const genomics = @import("ingestion").genomics;

pub const CBiozigParseResult = extern struct {
    num_records: c_int,
    error_code: c_int,
};

fn getAllocator() std.mem.Allocator {
    if (c_api.c_arena) |arena| {
        return arena.allocator();
    }
    return std.heap.page_allocator;
}

const BufferReader = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn readByte(self: *BufferReader) !u8 {
        if (self.pos >= self.buffer.len) return error.EndOfStream;
        const b = self.buffer[self.pos];
        self.pos += 1;
        return b;
    }

    pub fn readAll(self: *BufferReader, dest: []u8) !usize {
        const remaining = self.buffer.len - self.pos;
        const to_read = @min(dest.len, remaining);
        @memcpy(dest[0..to_read], self.buffer[self.pos .. self.pos + to_read]);
        self.pos += to_read;
        return to_read;
    }

    pub fn readNoEof(self: *BufferReader, dest: []u8) !void {
        const amt = try self.readAll(dest);
        if (amt < dest.len) return error.EndOfStream;
    }
};

// FASTA
export fn biozig_parse_fasta(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var iter = genomics.fasta.fastaIterator(mmap.data);
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt == null) break;
        res.num_records += 1;
    }
    return res;
}

// FASTQ
export fn biozig_parse_fastq(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var iter = genomics.fastq.fastqIterator(mmap.data);
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt == null) break;
        res.num_records += 1;
    }
    return res;
}

// SAM
export fn biozig_parse_sam(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var reader = BufferReader{ .buffer = mmap.data };
    var iter = genomics.sam.samIterator(alloc, &reader);
    defer iter.deinit();
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt) |rec| {
            res.num_records += 1;
            rec.deinit();
        } else {
            break;
        }
    }
    return res;
}

// BAM
export fn biozig_parse_bam(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var reader = BufferReader{ .buffer = mmap.data };
    var iter = genomics.bam.bamIterator(alloc, &reader);
    defer iter.deinit();
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt) |rec| {
            res.num_records += 1;
            rec.deinit();
        } else {
            break;
        }
    }
    return res;
}

// CRAM
export fn biozig_parse_cram(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var reader = BufferReader{ .buffer = mmap.data };
    var parser = genomics.cram.CramParser.init(alloc);
    var records = parser.parseStream(&reader) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    res.num_records = @intCast(records.items.len);
    records.deinit(alloc);
    return res;
}

// VCF
export fn biozig_parse_vcf(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var iter = genomics.vcf.vcfIterator(mmap.data);
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt == null) break;
        res.num_records += 1;
    }
    return res;
}

// BCF
export fn biozig_parse_bcf(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var reader = BufferReader{ .buffer = mmap.data };
    var parser = genomics.bcf.BcfParser.init(alloc);
    var records = parser.parseStream(&reader) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    res.num_records = @intCast(records.items.len);
    records.deinit(alloc);
    return res;
}

// BED
export fn biozig_parse_bed(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var iter = genomics.bed.bedIterator(mmap.data);
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt == null) break;
        res.num_records += 1;
    }
    return res;
}

// GFF3
export fn biozig_parse_gff3(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var reader = BufferReader{ .buffer = mmap.data };
    var iter = genomics.gff3.gff3Iterator(alloc, &reader);
    defer iter.deinit();
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt) |rec| {
            res.num_records += 1;
            rec.deinit();
        } else {
            break;
        }
    }
    return res;
}

// GTF
export fn biozig_parse_gtf(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var reader = BufferReader{ .buffer = mmap.data };
    var iter = genomics.gtf.gtfIterator(alloc, &reader);
    defer iter.deinit();
    while (true) {
        const record_opt = iter.next() catch |err| {
            res.error_code = @intFromError(err);
            return res;
        };
        if (record_opt) |rec| {
            res.num_records += 1;
            rec.deinit();
        } else {
            break;
        }
    }
    return res;
}

// 2BIT
export fn biozig_parse_twobit(file_path: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_records = 0, .error_code = 0 };
    const alloc = getAllocator();
    const path = std.mem.span(file_path);
    
    var mmap = core.io.mmap.MMapReader.init(alloc, path) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer mmap.deinit();
    
    var parser = genomics.twobit.TwoBitFile.init(alloc, mmap.data) catch |err| {
        res.error_code = @intFromError(err);
        return res;
    };
    defer parser.deinit();
    
    res.num_records = @intCast(parser.sequence_count);
    return res;
}
