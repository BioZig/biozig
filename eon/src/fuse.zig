const std = @import("std");

pub fn runFuse(allocator: std.mem.Allocator, in_file: []const u8, out_file: []const u8) !void {
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();

    const fd_in = try std.Io.Dir.openFile(cwd, io, in_file, .{ .mode = .read_only });
    defer std.Io.File.close(fd_in, io);
    
    const file_stat = try std.Io.File.stat(fd_in, io);
    const file_size = file_stat.size;
    
    // Quick buffered read using a large array list
    var file_data = std.ArrayListUnmanaged(u8).empty;
    defer file_data.deinit(allocator);
    
    var offset: usize = 0;
    while (offset < file_size) {
        var buf: [65536]u8 = undefined;
        const to_read = @min(buf.len, file_size - offset);
        _ = try std.Io.File.readPositionalAll(fd_in, io, buf[0..to_read], offset);
        try file_data.appendSlice(allocator, buf[0..to_read]);
        offset += to_read;
    }

    const fd_out = try std.Io.Dir.createFile(cwd, io, out_file, .{});
    defer std.Io.File.close(fd_out, io);

    var msa = std.ArrayListUnmanaged([]const u8).empty;
    defer {
        for (msa.items) |seq| allocator.free(seq);
        msa.deinit(allocator);
    }

    var rigidities = std.ArrayListUnmanaged(f64).empty;
    defer rigidities.deinit(allocator);

    var current_seq = std.ArrayListUnmanaged(u8).empty;
    defer current_seq.deinit(allocator);
    var is_consensus = false;

    var lines = std.mem.splitScalar(u8, file_data.items, '\n');
    while (lines.next()) |raw_line| {
        if (raw_line.len == 0) continue;
        var line = raw_line;
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "Loaded")) continue;

        if (std.mem.startsWith(u8, line, ">TiMSA_Consensus")) {
            if (current_seq.items.len > 0) {
                try msa.append(allocator, try current_seq.toOwnedSlice(allocator));
            }
            is_consensus = true;
            continue;
        }

        if (line[0] == '>') {
            if (current_seq.items.len > 0) {
                try msa.append(allocator, try current_seq.toOwnedSlice(allocator));
            }
            is_consensus = false;
            continue;
        }

        if (std.mem.startsWith(u8, line, "Col ")) {
            if (current_seq.items.len > 0) {
                try msa.append(allocator, try current_seq.toOwnedSlice(allocator));
            }
            if (std.mem.indexOfScalar(u8, line, ':')) |colon| {
                const val_str = std.mem.trim(u8, line[colon + 1 ..], " \t");
                const val = try std.fmt.parseFloat(f64, val_str);
                try rigidities.append(allocator, val);
            }
        } else {
            if (!is_consensus and !std.mem.startsWith(u8, line, "===")) {
                const trimmed = std.mem.trimEnd(u8, line, " \t");
                try current_seq.appendSlice(allocator, trimmed);
            }
        }
    }
    if (current_seq.items.len > 0) {
        try msa.append(allocator, try current_seq.toOwnedSlice(allocator));
    }

    std.debug.print("Read {d} sequences and {d} rigidity floats.\n", .{ msa.items.len, rigidities.items.len });
    if (msa.items.len == 0 or rigidities.items.len == 0) return;

    var out_builder = std.ArrayListUnmanaged(u8).empty;
    defer out_builder.deinit(allocator);
    try out_builder.appendSlice(allocator, "Source,Target,Weight\n");

    var min_cols: usize = rigidities.items.len;
    for (msa.items) |seq| {
        if (seq.len < min_cols) min_cols = seq.len;
    }
    const cols_to_process = min_cols;
    const n_f: f64 = @floatFromInt(msa.items.len);
    
    var out_offset: usize = 0;

    var i: usize = 0;
    while (i < cols_to_process) : (i += 1) {
        var counts_i = std.AutoHashMap(u8, f64).init(allocator);
        defer counts_i.deinit();

        for (msa.items) |seq| {
            const entry = try counts_i.getOrPutValue(seq[i], 0.0);
            entry.value_ptr.* += 1.0;
        }

        var h_i: f64 = 0.0;
        var it_i = counts_i.iterator();
        while (it_i.next()) |kv| {
            const p = kv.value_ptr.* / n_f;
            h_i -= p * @log2(p);
        }
        if (h_i == 0.0) continue;

        var j: usize = i + 1;
        while (j < cols_to_process) : (j += 1) {
            var counts_j = std.AutoHashMap(u8, f64).init(allocator);
            defer counts_j.deinit();

            for (msa.items) |seq| {
                const entry = try counts_j.getOrPutValue(seq[j], 0.0);
                entry.value_ptr.* += 1.0;
            }

            var h_j: f64 = 0.0;
            var it_j = counts_j.iterator();
            while (it_j.next()) |kv| {
                const p = kv.value_ptr.* / n_f;
                h_j -= p * @log2(p);
            }
            if (h_j == 0.0) continue;

            var joint = std.AutoHashMap(u16, f64).init(allocator);
            defer joint.deinit();

            for (msa.items) |seq| {
                const pair: u16 = (@as(u16, seq[i]) << 8) | @as(u16, seq[j]);
                const entry = try joint.getOrPutValue(pair, 0.0);
                entry.value_ptr.* += 1.0;
            }

            var h_ij: f64 = 0.0;
            var it_ij = joint.iterator();
            while (it_ij.next()) |kv| {
                const p = kv.value_ptr.* / n_f;
                h_ij -= p * @log2(p);
            }

            const mi = h_i + h_j - h_ij;
            if (mi > 0.00001) {
                const weight = mi * (@abs(rigidities.items[i]) + @abs(rigidities.items[j]));
                if (weight > 0.0) {
                    var line_buf: [128]u8 = undefined;
                    const formatted = try std.fmt.bufPrint(&line_buf, "Col_{d},Col_{d},{d:.6}\n", .{ i, j, weight });
                    try out_builder.appendSlice(allocator, formatted);
                    
                    if (out_builder.items.len > 1024 * 1024) {
                        try std.Io.File.writePositionalAll(fd_out, io, out_builder.items, out_offset);
                        out_offset += out_builder.items.len;
                        out_builder.clearRetainingCapacity();
                    }
                }
            }
        }
    }
    
    if (out_builder.items.len > 0) {
        try std.Io.File.writePositionalAll(fd_out, io, out_builder.items, out_offset);
    }
    
    std.debug.print("Fusion complete. Output written to {s}\n", .{out_file});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const arg1 = "rigidity_out.txt";
    const arg2 = "output.csv";

    try runFuse(allocator, arg1, arg2);
}
