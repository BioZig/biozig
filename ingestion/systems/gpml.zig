const std = @import("std");
const systems = @import("systems");
const network = systems.network;
const pathway = systems.pathway;

pub const GpmlParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GpmlParser {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *GpmlParser) void {
        _ = self;
    }

    pub fn parse(self: *GpmlParser, xml_data: []const u8) !struct { net: network.Network, path: pathway.Pathway } {

        var net = network.Network.init(self.allocator);
        errdefer net.deinit();

        var path = try pathway.Pathway.init(self.allocator, "GPML", "GPML Pathway");
        errdefer path.deinit();


        // graph_id -> node index
        var node_map = std.StringHashMap(usize).init(self.allocator);
        defer {
            var iter = node_map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            node_map.deinit();
        }

        var in_pathway = false;
        var in_interaction = false;
        
        var current_source_ref: ?[]const u8 = null;
        var current_target_ref: ?[]const u8 = null;
        
        defer {
            if (current_source_ref) |ref| self.allocator.free(ref);
            if (current_target_ref) |ref| self.allocator.free(ref);
        }

        var pos: usize = 0;
        while (pos < xml_data.len) {
            const lt_idx = std.mem.indexOfScalarPos(u8, xml_data, pos, '<') orelse break;
            const gt_idx = std.mem.indexOfScalarPos(u8, xml_data, lt_idx + 1, '>') orelse break;
            const raw_tag = xml_data[lt_idx + 1 .. gt_idx];
            pos = gt_idx + 1;

            if (raw_tag.len == 0) continue;

            if (raw_tag[0] == '/') {
                const close_tag = std.mem.trim(u8, raw_tag[1..], " \r\t\n/");
                if (std.mem.startsWith(u8, close_tag, "Interaction")) {
                    in_interaction = false;
                    // commit edge
                    if (current_source_ref != null and current_target_ref != null) {
                        const s_ref = current_source_ref.?;
                        const t_ref = current_target_ref.?;
                        if (node_map.get(s_ref)) |s_idx| {
                            if (node_map.get(t_ref)) |t_idx| {
                                try net.addEdge(s_idx, t_idx, 1.0, true);
                            }
                        }
                    }
                    if (current_source_ref) |ref| self.allocator.free(ref);
                    if (current_target_ref) |ref| self.allocator.free(ref);
                    current_source_ref = null;
                    current_target_ref = null;
                }
                continue;
            }

            var tokens = std.mem.tokenizeAny(u8, raw_tag, " \t\r\n/");
            const tag_name = tokens.next() orelse continue;

            if (std.mem.eql(u8, tag_name, "Pathway")) {
                in_pathway = true;
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val = std.mem.trim(u8, attr[eq_idx + 1 ..], "\"'");
                        if (std.mem.eql(u8, key, "Name")) {
                            self.allocator.free(path.name);
                            path.name = try self.allocator.dupe(u8, val);
                        }
                    }
                }
            } else if (std.mem.eql(u8, tag_name, "DataNode")) {
                var text_label: ?[]const u8 = null;
                var graph_id: ?[]const u8 = null;
                
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val = std.mem.trim(u8, attr[eq_idx + 1 ..], "\"'");
                        if (std.mem.eql(u8, key, "TextLabel")) text_label = val;
                        if (std.mem.eql(u8, key, "GraphId")) graph_id = val;
                    }
                }

                if (graph_id) |g_id| {
                    const node_name = text_label orelse g_id;
                    var node = try network.Node.init(self.allocator, node_name);
                    errdefer node.deinit();
                    try node.addMetadata("gpml_id", g_id);

                    const node_idx = try net.addNode(node);
                    try node_map.put(try self.allocator.dupe(u8, g_id), node_idx);
                    try path.addMember(node_name);
                }
            } else if (std.mem.eql(u8, tag_name, "Interaction")) {
                in_interaction = true;
            } else if (std.mem.eql(u8, tag_name, "Point")) {
                if (in_interaction) {
                    var graph_ref: ?[]const u8 = null;
                    while (tokens.next()) |attr| {
                        if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                            const key = attr[0..eq_idx];
                            const val = std.mem.trim(u8, attr[eq_idx + 1 ..], "\"'");
                            if (std.mem.eql(u8, key, "GraphRef")) graph_ref = val;
                        }
                    }
                    if (graph_ref) |g_ref| {
                        if (current_source_ref == null) {
                            current_source_ref = try self.allocator.dupe(u8, g_ref);
                        } else if (current_target_ref == null) {
                            current_target_ref = try self.allocator.dupe(u8, g_ref);
                        } else {
                            // GPML interactions typically have multiple points. We assume the first is source, the last is target.
                            self.allocator.free(current_target_ref.?);
                            current_target_ref = try self.allocator.dupe(u8, g_ref);
                        }
                    }
                }
            }

            if (raw_tag[raw_tag.len - 1] == '/' and std.mem.eql(u8, tag_name, "Interaction")) {
                in_interaction = false;
                if (current_source_ref != null and current_target_ref != null) {
                    const s_ref = current_source_ref.?;
                    const t_ref = current_target_ref.?;
                    if (node_map.get(s_ref)) |s_idx| {
                        if (node_map.get(t_ref)) |t_idx| {
                            try net.addEdge(s_idx, t_idx, 1.0, true);
                        }
                    }
                }
                if (current_source_ref) |ref| self.allocator.free(ref);
                if (current_target_ref) |ref| self.allocator.free(ref);
                current_source_ref = null;
                current_target_ref = null;
            }
        }
        
        // Final commit if any remains
        if (current_source_ref != null and current_target_ref != null) {
            const s_ref = current_source_ref.?;
            const t_ref = current_target_ref.?;
            if (node_map.get(s_ref)) |s_idx| {
                if (node_map.get(t_ref)) |t_idx| {
                    try net.addEdge(s_idx, t_idx, 1.0, true);
                }
            }
        }

        if (!in_pathway) {
            return error.InvalidFormat;
        }

        return .{ .net = net, .path = path };
    }
};

pub fn serialize(writer: anytype, net: network.Network, path: pathway.Pathway) !void {
    try writer.writeAll(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<Pathway xmlns="http://pathvisio.org/GPML/2013a" Name="
    );
    try writer.writeAll(path.name);
    try writer.writeAll(
        \\">
        \\
    );

    for (net.nodes.items) |node| {
        const gpml_id = node.metadata.get("gpml_id") orelse node.id;
        try writer.print("  <DataNode TextLabel=\"{s}\" GraphId=\"{s}\"/>\n", .{ node.id, gpml_id });
    }

    for (net.edges.items, 0..) |edge, idx| {
        const r_node = net.nodes.items[edge.source_idx];
        const p_node = net.nodes.items[edge.target_idx];
        const r_id = r_node.metadata.get("gpml_id") orelse r_node.id;
        const p_id = p_node.metadata.get("gpml_id") orelse p_node.id;

        try writer.print(
            \\  <Interaction GraphId="id_{}">
            \\    <Graphics>
            \\      <Point GraphRef="{s}"/>
            \\      <Point GraphRef="{s}"/>
            \\    </Graphics>
            \\  </Interaction>
            \\
        , .{ idx, r_id, p_id });
    }

    try writer.writeAll("</Pathway>\n");
}

const gpml_valid = 
    \\<?xml version="1.0" encoding="UTF-8"?>
    \\<Pathway Name="Glycolysis">
    \\  <DataNode TextLabel="Glucose" GraphId="n1" Type="Metabolite"/>
    \\  <DataNode TextLabel="Glucose 6-phosphate" GraphId="n2" Type="Metabolite"/>
    \\  <DataNode TextLabel="Fructose 6-phosphate" GraphId="n3" Type="Metabolite"/>
    \\  <Interaction>
    \\    <Graphics>
    \\      <Point GraphRef="n1"/>
    \\      <Point GraphRef="n2"/>
    \\    </Graphics>
    \\  </Interaction>
    \\  <Interaction>
    \\    <Graphics>
    \\      <Point GraphRef="n2"/>
    \\      <Point GraphRef="n3"/>
    \\    </Graphics>
    \\  </Interaction>
    \\</Pathway>
;

const gpml_malformed = 
    \\<?xml version="1.0" encoding="UTF-8"?>
    \\<NotAPathway Name="Bad">
    \\  <DataNode TextLabel="Glucose" GraphId="n1"/>
    \\</NotAPathway>
;

test "GPML parser valid data" {
    const alloc = std.testing.allocator;
    var parser = GpmlParser.init(alloc);
    defer parser.deinit();

    var result = try parser.parse(gpml_valid);
    defer result.net.deinit();
    defer result.path.deinit();

    try std.testing.expectEqualStrings("Glycolysis", result.path.name);
    try std.testing.expectEqual(@as(usize, 3), result.net.nodes.items.len);
    try std.testing.expectEqual(@as(usize, 2), result.net.edges.items.len);

    try std.testing.expectEqualStrings("Glucose", result.net.nodes.items[0].id);
    try std.testing.expectEqualStrings("n1", result.net.nodes.items[0].metadata.get("gpml_id").?);

    // Edges
    try std.testing.expectEqual(@as(usize, 0), result.net.edges.items[0].source_idx);
    try std.testing.expectEqual(@as(usize, 1), result.net.edges.items[0].target_idx);
    try std.testing.expectEqual(@as(usize, 1), result.net.edges.items[1].source_idx);
    try std.testing.expectEqual(@as(usize, 2), result.net.edges.items[1].target_idx);
}

test "GPML parser malformed data" {
    const alloc = std.testing.allocator;
    var parser = GpmlParser.init(alloc);
    defer parser.deinit();

    try std.testing.expectError(error.InvalidFormat, parser.parse(gpml_malformed));
}

test "GPML serialization roundtrip" {
    const alloc = std.testing.allocator;
    var parser = GpmlParser.init(alloc);
    defer parser.deinit();

    var result = try parser.parse(gpml_valid);
    defer result.net.deinit();
    defer result.path.deinit();

    var buf: [2048]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    
    try serialize(&writer, result.net, result.path);
    const serialized_data = writer.buffered();

    var parser2 = GpmlParser.init(alloc);
    defer parser2.deinit();

    var result2 = try parser2.parse(serialized_data);
    defer result2.net.deinit();
    defer result2.path.deinit();

    try std.testing.expectEqualStrings("Glycolysis", result2.path.name);
    try std.testing.expectEqual(@as(usize, 3), result2.net.nodes.items.len);
    try std.testing.expectEqual(@as(usize, 2), result2.net.edges.items.len);
}


