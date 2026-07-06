const std = @import("std");

pub const Chunk = struct {
    beg: u64,
    end: u64,
};

pub const Bin = struct {
    bin: u32,
    chunks: []Chunk,
    loffset: ?u64 = null, // Used in CSI, null in TBI
};

pub const Reference = struct {
    bins: []Bin,
    intervals: []u64, // Used in TBI, empty in CSI
    
    pub fn deinit(self: *Reference, allocator: std.mem.Allocator) void {
        for (self.bins) |bin| {
            allocator.free(bin.chunks);
        }
        allocator.free(self.bins);
        if (self.intervals.len > 0) {
            allocator.free(self.intervals);
        }
    }
};

pub const TabixHeader = struct {
    format: i32,
    col_seq: i32,
    col_beg: i32,
    col_end: i32,
    meta: i32,
    skip: i32,
    names: [][]const u8, // slices into a single allocated buffer
    names_buf: []u8,

    pub fn deinit(self: *TabixHeader, allocator: std.mem.Allocator) void {
        allocator.free(self.names);
        allocator.free(self.names_buf);
    }
};

pub const GenomicIndex = struct {
    allocator: std.mem.Allocator,
    min_shift: i32,
    depth: i32,
    tbi_header: ?TabixHeader = null,
    refs: []Reference,

    pub fn deinit(self: *GenomicIndex) void {
        if (self.tbi_header) |*th| {
            th.deinit(self.allocator);
        }
        for (self.refs) |*r| {
            r.deinit(self.allocator);
        }
        self.allocator.free(self.refs);
    }
    
    pub fn reg2bins(self: *const GenomicIndex, beg: u32, end: u32, allocator: std.mem.Allocator) ![]u32 {
        var bins = std.ArrayList(u32).empty;
        defer bins.deinit(allocator);
        
        var t: u32 = 0;
        var s: u32 = @intCast(self.min_shift + self.depth * 3);
        
        var end_mod = end;
        if (beg >= end_mod) return allocator.alloc(u32, 0);
        
        const max_val = @as(u32, 1) << @intCast(s);
        if (end_mod >= max_val) end_mod = max_val;
        end_mod -= 1;
        
        var i: i32 = 0;
        while (i <= self.depth) : (i += 1) {
            var b = t + (beg >> @intCast(s));
            const e = t + (end_mod >> @intCast(s));
            while (b <= e) : (b += 1) {
                try bins.append(allocator, b);
            }
            if (i < self.depth) {
                s -= 3;
                const shift_amt: u5 = @intCast((self.depth - i) * 3);
                t += @as(u32, 1) << shift_amt;
            }
        }
        return bins.toOwnedSlice(allocator);
    }
};

fn readI32(data: []const u8, offset: *usize) !i32 {
    if (data.len < offset.* + 4) return error.UnexpectedEof;
    const val = std.mem.readInt(i32, data[offset.*..][0..4], .little);
    offset.* += 4;
    return val;
}

fn readU32(data: []const u8, offset: *usize) !u32 {
    if (data.len < offset.* + 4) return error.UnexpectedEof;
    const val = std.mem.readInt(u32, data[offset.*..][0..4], .little);
    offset.* += 4;
    return val;
}

fn readU64(data: []const u8, offset: *usize) !u64 {
    if (data.len < offset.* + 8) return error.UnexpectedEof;
    const val = std.mem.readInt(u64, data[offset.*..][0..8], .little);
    offset.* += 8;
    return val;
}

pub fn parseTbi(allocator: std.mem.Allocator, data: []const u8) !GenomicIndex {
    var offset: usize = 0;
    if (data.len < 4) return error.UnexpectedEof;
    if (!std.mem.eql(u8, data[0..4], "TBI\x01")) return error.InvalidMagic;
    offset += 4;
    
    const n_ref = try readI32(data, &offset);
    const format = try readI32(data, &offset);
    const col_seq = try readI32(data, &offset);
    const col_beg = try readI32(data, &offset);
    const col_end = try readI32(data, &offset);
    const meta = try readI32(data, &offset);
    const skip = try readI32(data, &offset);
    const l_nm = try readI32(data, &offset);
    
    if (data.len < offset + @as(usize, @intCast(l_nm))) return error.UnexpectedEof;
    const names_buf = try allocator.alloc(u8, @intCast(l_nm));
    errdefer allocator.free(names_buf);
    @memcpy(names_buf, data[offset .. offset + @as(usize, @intCast(l_nm))]);
    offset += @intCast(l_nm);
    
    var name_list = std.ArrayList([]const u8).empty;
    errdefer name_list.deinit(allocator);
    
    var start: usize = 0;
    for (names_buf, 0..) |c, i| {
        if (c == 0) {
            if (i > start) {
                try name_list.append(allocator, names_buf[start..i]);
            }
            start = i + 1;
        }
    }
    
    const th = TabixHeader{
        .format = format,
        .col_seq = col_seq,
        .col_beg = col_beg,
        .col_end = col_end,
        .meta = meta,
        .skip = skip,
        .names = try name_list.toOwnedSlice(allocator),
        .names_buf = names_buf,
    };
    
    var refs = try allocator.alloc(Reference, @intCast(n_ref));
    errdefer {
        for (refs) |*r| r.deinit(allocator);
        allocator.free(refs);
        var mut_th = th;
        mut_th.deinit(allocator);
    }
    @memset(refs, Reference{ .bins = &[_]Bin{}, .intervals = &[_]u64{} });
    
    for (0..@intCast(n_ref)) |r_idx| {
        const n_bin = try readI32(data, &offset);
        var bins = try allocator.alloc(Bin, @intCast(n_bin));
        @memset(bins, Bin{ .bin = 0, .chunks = &[_]Chunk{}, .loffset = null });
        
        for (0..@intCast(n_bin)) |b_idx| {
            const bin_id = try readU32(data, &offset);
            const n_chunk = try readI32(data, &offset);
            
            var chunks = try allocator.alloc(Chunk, @intCast(n_chunk));
            for (0..@intCast(n_chunk)) |c_idx| {
                const cnk_beg = try readU64(data, &offset);
                const cnk_end = try readU64(data, &offset);
                chunks[c_idx] = Chunk{ .beg = cnk_beg, .end = cnk_end };
            }
            bins[b_idx] = Bin{ .bin = bin_id, .chunks = chunks, .loffset = null };
        }
        
        const n_intv = try readI32(data, &offset);
        var intervals = try allocator.alloc(u64, @intCast(n_intv));
        for (0..@intCast(n_intv)) |i_idx| {
            intervals[i_idx] = try readU64(data, &offset);
        }
        
        refs[r_idx] = Reference{ .bins = bins, .intervals = intervals };
    }
    
    return GenomicIndex{
        .allocator = allocator,
        .min_shift = 14,
        .depth = 5,
        .tbi_header = th,
        .refs = refs,
    };
}

pub fn parseCsi(allocator: std.mem.Allocator, data: []const u8) !GenomicIndex {
    var offset: usize = 0;
    if (data.len < 4) return error.UnexpectedEof;
    if (!std.mem.eql(u8, data[0..4], "CSI\x01")) return error.InvalidMagic;
    offset += 4;
    
    const min_shift = try readI32(data, &offset);
    const depth = try readI32(data, &offset);
    const l_aux = try readI32(data, &offset);
    
    var tbi_header: ?TabixHeader = null;
    if (l_aux > 0) {
        if (l_aux >= 28) {
            const aux_start = offset;
            const format = try readI32(data, &offset);
            const col_seq = try readI32(data, &offset);
            const col_beg = try readI32(data, &offset);
            const col_end = try readI32(data, &offset);
            const meta = try readI32(data, &offset);
            const skip = try readI32(data, &offset);
            const l_nm = try readI32(data, &offset);
            
            const remaining = l_aux - 28;
            if (l_nm != remaining) {
                // Not a tabix header
                offset = aux_start + @as(usize, @intCast(l_aux));
            } else {
                if (data.len < offset + @as(usize, @intCast(l_nm))) return error.UnexpectedEof;
                const names_buf = try allocator.alloc(u8, @intCast(l_nm));
                @memcpy(names_buf, data[offset .. offset + @as(usize, @intCast(l_nm))]);
                offset += @intCast(l_nm);
                
                var name_list = std.ArrayList([]const u8).empty;
                var start: usize = 0;
                for (names_buf, 0..) |c, i| {
                    if (c == 0) {
                        if (i > start) {
                            try name_list.append(allocator, names_buf[start..i]);
                        }
                        start = i + 1;
                    }
                }
                tbi_header = TabixHeader{
                    .format = format,
                    .col_seq = col_seq,
                    .col_beg = col_beg,
                    .col_end = col_end,
                    .meta = meta,
                    .skip = skip,
                    .names = try name_list.toOwnedSlice(allocator),
                    .names_buf = names_buf,
                };
            }
        } else {
            offset += @intCast(l_aux);
        }
    }
    
    const n_ref = try readI32(data, &offset);
    var refs = try allocator.alloc(Reference, @intCast(n_ref));
    @memset(refs, Reference{ .bins = &[_]Bin{}, .intervals = &[_]u64{} });
    
    for (0..@intCast(n_ref)) |r_idx| {
        const n_bin = try readI32(data, &offset);
        var bins = try allocator.alloc(Bin, @intCast(n_bin));
        @memset(bins, Bin{ .bin = 0, .chunks = &[_]Chunk{}, .loffset = null });
        
        for (0..@intCast(n_bin)) |b_idx| {
            const bin_id = try readU32(data, &offset);
            const loffset = try readU64(data, &offset);
            const n_chunk = try readI32(data, &offset);
            
            var chunks = try allocator.alloc(Chunk, @intCast(n_chunk));
            for (0..@intCast(n_chunk)) |c_idx| {
                const cnk_beg = try readU64(data, &offset);
                const cnk_end = try readU64(data, &offset);
                chunks[c_idx] = Chunk{ .beg = cnk_beg, .end = cnk_end };
            }
            bins[b_idx] = Bin{ .bin = bin_id, .chunks = chunks, .loffset = loffset };
        }
        
        refs[r_idx] = Reference{ .bins = bins, .intervals = &[_]u64{} };
    }
    
    return GenomicIndex{
        .allocator = allocator,
        .min_shift = min_shift,
        .depth = depth,
        .tbi_header = tbi_header,
        .refs = refs,
    };
}

fn appendI32(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), val: i32) !void {
    var num: [4]u8 = undefined;
    std.mem.writeInt(i32, &num, val, .little);
    try buf.appendSlice(allocator, &num);
}

fn appendU32(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), val: u32) !void {
    var num: [4]u8 = undefined;
    std.mem.writeInt(u32, &num, val, .little);
    try buf.appendSlice(allocator, &num);
}

fn appendU64(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), val: u64) !void {
    var num: [8]u8 = undefined;
    std.mem.writeInt(u64, &num, val, .little);
    try buf.appendSlice(allocator, &num);
}

test "tbi parsing with mock data" {
    const allocator = std.testing.allocator;
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    
    try buf.appendSlice(allocator, "TBI\x01");
    try appendI32(allocator, &buf, 1); // n_ref
    try appendI32(allocator, &buf, 2); // format VCF
    try appendI32(allocator, &buf, 1); // col_seq
    try appendI32(allocator, &buf, 2); // col_beg
    try appendI32(allocator, &buf, 0); // col_end
    try appendI32(allocator, &buf, '#'); // meta
    try appendI32(allocator, &buf, 0); // skip
    try appendI32(allocator, &buf, 5); // l_nm
    try buf.appendSlice(allocator, "chr1\x00"); // names
    
    // 1 ref
    try appendI32(allocator, &buf, 1); // n_bin
    // 1 bin
    try appendU32(allocator, &buf, 4681); // bin id
    try appendI32(allocator, &buf, 1); // n_chunk
    // 1 chunk
    try appendU64(allocator, &buf, 100); // cnk_beg
    try appendU64(allocator, &buf, 200); // cnk_end
    
    try appendI32(allocator, &buf, 2); // n_intv
    try appendU64(allocator, &buf, 50); // ioffset 1
    try appendU64(allocator, &buf, 100); // ioffset 2
    
    var idx = try parseTbi(allocator, buf.items);
    defer idx.deinit();
    
    try std.testing.expectEqual(idx.min_shift, 14);
    try std.testing.expectEqual(idx.depth, 5);
    try std.testing.expectEqual(idx.refs.len, 1);
    try std.testing.expectEqual(idx.refs[0].bins.len, 1);
    try std.testing.expectEqual(idx.refs[0].bins[0].chunks.len, 1);
    try std.testing.expectEqual(idx.refs[0].intervals.len, 2);
    try std.testing.expect(idx.tbi_header != null);
    if (idx.tbi_header) |th| {
        try std.testing.expectEqualStrings(th.names[0], "chr1");
    }
}

test "csi parsing with mock data" {
    const allocator = std.testing.allocator;
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    
    try buf.appendSlice(allocator, "CSI\x01"); // magic
    try appendI32(allocator, &buf, 14); // min_shift
    try appendI32(allocator, &buf, 5); // depth
    try appendI32(allocator, &buf, 0); // l_aux
    
    // 1 ref
    try appendI32(allocator, &buf, 1); // n_ref
    try appendI32(allocator, &buf, 1); // n_bin
    // 1 bin
    try appendU32(allocator, &buf, 4681); // bin id
    try appendU64(allocator, &buf, 1234); // loffset
    try appendI32(allocator, &buf, 1); // n_chunk
    // 1 chunk
    try appendU64(allocator, &buf, 100); // cnk_beg
    try appendU64(allocator, &buf, 200); // cnk_end
    
    var idx = try parseCsi(allocator, buf.items);
    defer idx.deinit();
    
    try std.testing.expectEqual(idx.min_shift, 14);
    try std.testing.expectEqual(idx.depth, 5);
    try std.testing.expectEqual(idx.refs.len, 1);
    try std.testing.expectEqual(idx.refs[0].bins.len, 1);
    try std.testing.expectEqual(idx.refs[0].bins[0].loffset.?, 1234);
    try std.testing.expectEqual(idx.refs[0].bins[0].chunks.len, 1);
}

test "GenomicIndex.reg2bins" {
    const allocator = std.testing.allocator;
    var idx = GenomicIndex{
        .allocator = allocator,
        .min_shift = 14,
        .depth = 5,
        .refs = &[_]Reference{},
    };
    
    const bins = try idx.reg2bins(10, 20, allocator);
    defer allocator.free(bins);
    
    try std.testing.expect(bins.len > 0);
}
