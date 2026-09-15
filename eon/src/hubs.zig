const std = @import("std");

pub const NodeCentrality = struct {
    id: usize,
    degree: f64,
};

fn descendingCentrality(context: void, a: NodeCentrality, b: NodeCentrality) bool {
    _ = context;
    return a.degree > b.degree;
}

pub fn calculateHubs(allocator: std.mem.Allocator, csv_file: []const u8, out_file: []const u8) !void {
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();

    const fd_in = try std.Io.Dir.openFile(cwd, io, csv_file, .{ .mode = .read_only });
    defer std.Io.File.close(fd_in, io);
    
    const file_stat = try std.Io.File.stat(fd_in, io);
    const file_size = file_stat.size;
    
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

    var node_weights = std.AutoHashMap(usize, f64).init(allocator);
    defer node_weights.deinit();

    var lines = std.mem.splitScalar(u8, file_data.items, '\n');
    var is_first = true;
    while (lines.next()) |raw_line| {
        if (raw_line.len == 0) continue;
        var line = raw_line;
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        if (line.len == 0) continue;
        
        if (is_first) {
            is_first = false;
            continue;
        }

        var tokens = std.mem.splitScalar(u8, line, ',');
        const src_str = tokens.next() orelse continue;
        const tgt_str = tokens.next() orelse continue;
        const wt_str = tokens.next() orelse continue;

        if (!std.mem.startsWith(u8, src_str, "Col_")) continue;
        if (!std.mem.startsWith(u8, tgt_str, "Col_")) continue;

        const src_id = try std.fmt.parseInt(usize, src_str[4..], 10);
        const tgt_id = try std.fmt.parseInt(usize, tgt_str[4..], 10);
        const weight = try std.fmt.parseFloat(f64, wt_str);

        const src_entry = try node_weights.getOrPutValue(src_id, 0.0);
        src_entry.value_ptr.* += weight;

        const tgt_entry = try node_weights.getOrPutValue(tgt_id, 0.0);
        tgt_entry.value_ptr.* += weight;
    }

    var centralities = std.ArrayListUnmanaged(NodeCentrality).empty;
    defer centralities.deinit(allocator);

    var it = node_weights.iterator();
    while (it.next()) |kv| {
        try centralities.append(allocator, .{
            .id = kv.key_ptr.*,
            .degree = kv.value_ptr.*,
        });
    }

    std.mem.sort(NodeCentrality, centralities.items, {}, descendingCentrality);

    const fd_out = try std.Io.Dir.createFile(cwd, io, out_file, .{});
    defer std.Io.File.close(fd_out, io);

    var out_builder = std.ArrayListUnmanaged(u8).empty;
    defer out_builder.deinit(allocator);

    try out_builder.appendSlice(allocator, "Node,Degree,IsHub\n");
    
    // Top 10% are hubs (example threshold)
    const hub_threshold = centralities.items.len / 10;
    
    var out_offset: usize = 0;
    for (centralities.items, 0..) |node, i| {
        const is_hub = i < hub_threshold;
        var line_buf: [128]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&line_buf, "Col_{d},{d:.6},{s}\n", .{ node.id, node.degree, if (is_hub) "true" else "false" });
        try out_builder.appendSlice(allocator, formatted);
        
        if (out_builder.items.len > 1024 * 1024) {
            try std.Io.File.writePositionalAll(fd_out, io, out_builder.items, out_offset);
            out_offset += out_builder.items.len;
            out_builder.clearRetainingCapacity();
        }
    }
    
    if (out_builder.items.len > 0) {
        try std.Io.File.writePositionalAll(fd_out, io, out_builder.items, out_offset);
    }
    
    std.debug.print("Hub calculation complete. Ranked nodes written to {s}\n", .{out_file});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const arg1 = "output.csv"; // input from fuse.zig
    const arg2 = "hubs.csv"; // output

    try calculateHubs(allocator, arg1, arg2);
}
