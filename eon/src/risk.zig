const std = @import("std");

pub const RiskCategory = enum {
    ZERO,
    MEDIUM,
    HIGH,
    CRITICAL,
    
    pub fn toString(self: RiskCategory) []const u8 {
        return switch (self) {
            .ZERO => "ZERO",
            .MEDIUM => "MEDIUM",
            .HIGH => "HIGH",
            .CRITICAL => "CRITICAL",
        };
    }
};

pub const NodeRisk = struct {
    id: usize,
    rigidity: f64,
    degree: f64,
    is_hub: bool,
    category: RiskCategory,
    ref_pos: ?usize,
    ref_aa: u8,
};

pub fn generateRiskReport(allocator: std.mem.Allocator, rigidity_file: []const u8, hubs_file: []const u8, out_file: []const u8) !void {
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();

    // 1. Read rigidity file
    const fd_rig = try std.Io.Dir.openFile(cwd, io, rigidity_file, .{ .mode = .read_only });
    defer std.Io.File.close(fd_rig, io);
    const size_rig = (try std.Io.File.stat(fd_rig, io)).size;
    var data_rig = std.ArrayListUnmanaged(u8).empty;
    defer data_rig.deinit(allocator);
    var offset_rig: usize = 0;
    while (offset_rig < size_rig) {
        var buf: [65536]u8 = undefined;
        const to_read = @min(buf.len, size_rig - offset_rig);
        _ = try std.Io.File.readPositionalAll(fd_rig, io, buf[0..to_read], offset_rig);
        try data_rig.appendSlice(allocator, buf[0..to_read]);
        offset_rig += to_read;
    }

    var rigidities = std.AutoHashMap(usize, f64).init(allocator);
    defer rigidities.deinit();

    var ref_seq = std.ArrayListUnmanaged(u8).empty;
    defer ref_seq.deinit(allocator);

    var lines_rig = std.mem.splitScalar(u8, data_rig.items, '\n');
    var in_ref_seq = false;
    var found_ref = false;

    while (lines_rig.next()) |raw_line| {
        if (raw_line.len == 0) continue;
        var line = raw_line;
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        
        if (std.mem.startsWith(u8, line, ">")) {
            if (!found_ref) {
                in_ref_seq = true;
                found_ref = true;
            } else {
                in_ref_seq = false;
            }
            continue;
        }

        if (in_ref_seq and !std.mem.startsWith(u8, line, "Col ")) {
            const trimmed = std.mem.trimEnd(u8, line, " \t");
            try ref_seq.appendSlice(allocator, trimmed);
            continue;
        }

        if (std.mem.startsWith(u8, line, "Col ")) {
            in_ref_seq = false; // Stop capturing if we hit Col lines
            if (std.mem.indexOfScalar(u8, line, ':')) |colon| {
                const id_str = std.mem.trim(u8, line[4..colon], " \t");
                const id = try std.fmt.parseInt(usize, id_str, 10);
                const val_str = std.mem.trim(u8, line[colon + 1 ..], " \t");
                const val = try std.fmt.parseFloat(f64, val_str);
                try rigidities.put(id, val);
            }
        }
    }

    // Build mapping: col_index -> { ref_pos, aa }
    // Note: ref_pos is 1-indexed for biologists
    var col_to_ref_pos = std.AutoHashMap(usize, usize).init(allocator);
    defer col_to_ref_pos.deinit();
    var col_to_ref_aa = std.AutoHashMap(usize, u8).init(allocator);
    defer col_to_ref_aa.deinit();

    var current_ref_pos: usize = 1;
    for (ref_seq.items, 0..) |aa, col_idx| {
        try col_to_ref_aa.put(col_idx, aa);
        if (aa != '-') {
            try col_to_ref_pos.put(col_idx, current_ref_pos);
            current_ref_pos += 1;
        }
    }

    // Deterministic Topological Thresholding:
    // We determine the maximum absolute Delta W_p (rigidity) in the network.
    // A node is classified as ZERO (topologically unviable) if its distortion exceeds 
    // a strict geometric ratio (e.g., 50%) of the maximum possible distortion in the system.
    var max_dWp: f64 = 0.0;
    var it_rig = rigidities.iterator();
    while (it_rig.next()) |kv| {
        const val = @abs(kv.value_ptr.*);
        if (val > max_dWp) {
            max_dWp = val;
        }
    }
    
    // Strict deterministic ratio: 50% of the maximum topological distortion
    const unviable_threshold = max_dWp * 0.50;


    // 2. Read hubs file
    const fd_hubs = try std.Io.Dir.openFile(cwd, io, hubs_file, .{ .mode = .read_only });
    defer std.Io.File.close(fd_hubs, io);
    const size_hubs = (try std.Io.File.stat(fd_hubs, io)).size;
    var data_hubs = std.ArrayListUnmanaged(u8).empty;
    defer data_hubs.deinit(allocator);
    var offset_hubs: usize = 0;
    while (offset_hubs < size_hubs) {
        var buf: [65536]u8 = undefined;
        const to_read = @min(buf.len, size_hubs - offset_hubs);
        _ = try std.Io.File.readPositionalAll(fd_hubs, io, buf[0..to_read], offset_hubs);
        try data_hubs.appendSlice(allocator, buf[0..to_read]);
        offset_hubs += to_read;
    }

    var nodes = std.ArrayListUnmanaged(NodeRisk).empty;
    defer nodes.deinit(allocator);

    var lines_hubs = std.mem.splitScalar(u8, data_hubs.items, '\n');
    var is_first = true;
    while (lines_hubs.next()) |raw_line| {
        if (raw_line.len == 0) continue;
        var line = raw_line;
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        if (is_first) {
            is_first = false;
            continue;
        }

        var tokens = std.mem.splitScalar(u8, line, ',');
        const node_str = tokens.next() orelse continue;
        const deg_str = tokens.next() orelse continue;
        const hub_str = tokens.next() orelse continue;

        if (!std.mem.startsWith(u8, node_str, "Col_")) continue;
        const id = try std.fmt.parseInt(usize, node_str[4..], 10);
        const degree = try std.fmt.parseFloat(f64, deg_str);
        const is_hub = std.mem.eql(u8, hub_str, "true");

        const rigidity = rigidities.get(id) orelse 0.0;
        
        // EON logic: 
        // ZERO = Topologically unviable anchor (abs(rigidity) > unviable_threshold)
        // HIGH/MEDIUM = Flexible node capable of surviving mutation
        const is_unviable = @abs(rigidity) > unviable_threshold; 
        
        var category: RiskCategory = .ZERO;
        if (is_unviable) {
            category = .ZERO;
        } else if (is_hub) {
            category = .HIGH;
        } else {
            category = .MEDIUM;
        }

        const ref_pos = col_to_ref_pos.get(id);
        const ref_aa = col_to_ref_aa.get(id) orelse '-';

        try nodes.append(allocator, .{
            .id = id,
            .rigidity = rigidity,
            .degree = degree,
            .is_hub = is_hub,
            .category = category,
            .ref_pos = ref_pos,
            .ref_aa = ref_aa,
        });
    }

    // 3. Output JSON format
    const fd_out = try std.Io.Dir.createFile(cwd, io, out_file, .{});
    defer std.Io.File.close(fd_out, io);
    var out_builder = std.ArrayListUnmanaged(u8).empty;
    defer out_builder.deinit(allocator);

    try out_builder.appendSlice(allocator, "{\n  \"eon_report\": [\n");
    
    var out_offset: usize = 0;
    for (nodes.items, 0..) |node, i| {
        var buf: [256]u8 = undefined;
        var pos_str_buf: [32]u8 = undefined;
        const pos_str = if (node.ref_pos) |p| try std.fmt.bufPrint(&pos_str_buf, "{d}", .{p}) else "null";
        
        const formatted = try std.fmt.bufPrint(&buf, "    {{\n      \"node\": {d},\n      \"reference_pos\": {s},\n      \"reference_aa\": \"{c}\",\n      \"category\": \"{s}\",\n      \"rigidity\": {d:.4},\n      \"degree\": {d:.4}\n    }}{s}\n", 
            .{ node.id, pos_str, node.ref_aa, node.category.toString(), node.rigidity, node.degree, if (i < nodes.items.len - 1) "," else "" });
        
        try out_builder.appendSlice(allocator, formatted);
        
        if (out_builder.items.len > 1024 * 1024) {
            try std.Io.File.writePositionalAll(fd_out, io, out_builder.items, out_offset);
            out_offset += out_builder.items.len;
            out_builder.clearRetainingCapacity();
        }
    }
    
    try out_builder.appendSlice(allocator, "  ]\n}\n");
    
    if (out_builder.items.len > 0) {
        try std.Io.File.writePositionalAll(fd_out, io, out_builder.items, out_offset);
    }
    
    std.debug.print("Risk scoring complete. Report written to {s}\n", .{out_file});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const arg1 = "rigidity_out.txt";
    const arg2 = "hubs.csv";
    const arg3 = "eon_report.json";

    try generateRiskReport(allocator, arg1, arg2, arg3);
}
