const std = @import("std");
const systems = @import("systems");
const network = systems.network;
const pathway = systems.pathway;

pub const BiopaxParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BiopaxParser {
        return .{ .allocator = allocator };
    }

    pub fn parse(self: BiopaxParser, xml_data: []const u8) !struct { net: network.Network, path: pathway.Pathway } {
        var net = network.Network.init(self.allocator);
        errdefer net.deinit();

        var path = try pathway.Pathway.init(self.allocator, "biopax_pathway", "BioPAX Reconstructed Pathway");
        errdefer path.deinit();

        var species_map = std.StringHashMap(usize).init(self.allocator);
        defer {
            var iter = species_map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            species_map.deinit();
        }

        const current_reaction_id: ?[]const u8 = null;
        defer {
            if (current_reaction_id) |id| self.allocator.free(id);
        }

        var left_components = std.ArrayList([]const u8).empty;
        defer {
            for (left_components.items) |l| self.allocator.free(l);
            left_components.deinit(self.allocator);
        }

        var right_components = std.ArrayList([]const u8).empty;
        defer {
            for (right_components.items) |r| self.allocator.free(r);
            right_components.deinit(self.allocator);
        }

        var in_reaction = false;
        var in_pathway = false;
        const current_element_tag: ?[]const u8 = null;
        defer {
            if (current_element_tag) |t| self.allocator.free(t);
        }

        var pos: usize = 0;
        main_loop: while (pos < xml_data.len) {
            const lt_idx = std.mem.indexOfScalarPos(u8, xml_data, pos, '<') orelse break :main_loop;
            const gt_idx = std.mem.indexOfScalarPos(u8, xml_data, lt_idx + 1, '>') orelse break :main_loop;
            const raw_tag = xml_data[lt_idx + 1 .. gt_idx];
            pos = gt_idx + 1;

            if (raw_tag.len == 0) continue;

            if (raw_tag[0] == '/') {
                // Closing tag
                const closing_tag = std.mem.trim(u8, raw_tag[1..], " \t\r\n/");
                if (std.mem.eql(u8, closing_tag, "bp:BiochemicalReaction")) {
                    in_reaction = false;
                    try commitReaction(species_map, &net, left_components.items, right_components.items);
                    for (left_components.items) |l| self.allocator.free(l);
                    left_components.clearRetainingCapacity();
                    for (right_components.items) |r| self.allocator.free(r);
                    right_components.clearRetainingCapacity();
                } else if (std.mem.eql(u8, closing_tag, "bp:Pathway")) {
                    in_pathway = false;
                }
                continue;
            }

            var tokens = std.mem.tokenizeAny(u8, raw_tag, " \t\r\n/");
            const tag_name = tokens.next() orelse continue;

            if (std.mem.eql(u8, tag_name, "bp:Pathway")) {
                in_pathway = true;
                in_reaction = false;
            } else if (std.mem.eql(u8, tag_name, "bp:BiochemicalReaction")) {
                in_reaction = true;
                in_pathway = false;
                left_components.clearRetainingCapacity();
                right_components.clearRetainingCapacity();
            } else if (std.mem.eql(u8, tag_name, "bp:Protein") or
                std.mem.eql(u8, tag_name, "bp:SmallMolecule") or
                std.mem.eql(u8, tag_name, "bp:PhysicalEntity"))
            {
                var rdf_id: ?[]const u8 = null;
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val = std.mem.trim(u8, attr[eq_idx + 1 ..], "\"'#");
                        if (std.mem.eql(u8, key, "rdf:ID") or std.mem.eql(u8, key, "ID") or std.mem.eql(u8, key, "rdf:about")) {
                            rdf_id = val;
                        }
                    }
                }
                if (rdf_id) |s_id| {
                    var node = try network.Node.init(self.allocator, s_id);
                    errdefer node.deinit();
                    try node.addMetadata("biopax_type", tag_name[3..]);
                    const node_idx = try net.addNode(node);
                    try species_map.put(try self.allocator.dupe(u8, s_id), node_idx);
                }
            } else if (std.mem.eql(u8, tag_name, "bp:left") or std.mem.eql(u8, tag_name, "bp:right")) {
                var resource: ?[]const u8 = null;
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val = std.mem.trim(u8, attr[eq_idx + 1 ..], "\"'#");
                        if (std.mem.eql(u8, key, "rdf:resource") or std.mem.eql(u8, key, "resource")) {
                            resource = val;
                        }
                    }
                }
                if (resource) |res| {
                    if (std.mem.eql(u8, tag_name, "bp:left")) {
                        try left_components.append(self.allocator, try self.allocator.dupe(u8, res));
                    } else {
                        try right_components.append(self.allocator, try self.allocator.dupe(u8, res));
                    }
                }
            } else if (std.mem.eql(u8, tag_name, "bp:pathwayComponent")) {
                var resource: ?[]const u8 = null;
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val = std.mem.trim(u8, attr[eq_idx + 1 ..], "\"'#");
                        if (std.mem.eql(u8, key, "rdf:resource") or std.mem.eql(u8, key, "resource")) {
                            resource = val;
                        }
                    }
                }
                if (resource) |res| {
                    try path.addMember(res);
                }
            }
        }

        return .{ .net = net, .path = path };
    }

    fn commitReaction(
        species_map: std.StringHashMap(usize),
        net: *network.Network,
        left: []const []const u8,
        right: []const []const u8,
    ) !void {
        for (left) |l| {
            if (species_map.get(l)) |l_idx| {
                for (right) |r| {
                    if (species_map.get(r)) |r_idx| {
                        try net.addEdge(l_idx, r_idx, 1.0, true);
                    }
                }
            }
        }
    }
};

/// Serializes Network and Pathway to BioPAX OWL format
pub fn serialize(writer: anytype, net: network.Network, path: pathway.Pathway) !void {
    try writer.writeAll(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<rdf:RDF
        \\  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
        \\  xmlns:bp="http://www.biopax.org/release/biopax-level3.owl#"
        \\  xmlns:owl="http://www.w3.org/2002/07/owl#"
        \\  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
        \\  xmlns:xsd="http://www.w3.org/2001/XMLSchema#">
        \\  <owl:Ontology rdf:about=""/>
        \\
        \\  <bp:Pathway rdf:ID="BiopaxPathway">
        \\    <bp:displayName>BioPAX Pathway Export</bp:displayName>
        \\
    );

    // List all pathway components
    var iter = path.members.keyIterator();
    while (iter.next()) |k| {
        try writer.print("    <bp:pathwayComponent rdf:resource=\"#{s}\"/>\n", .{k.*});
    }

    try writer.writeAll(
        \\  </bp:Pathway>
        \\
    );

    // List physical entities
    for (net.nodes.items) |node| {
        const bp_type = node.metadata.get("biopax_type") orelse "PhysicalEntity";
        try writer.print(
            \\  <bp:{s} rdf:ID="{s}">
            \\    <bp:displayName>{s}</bp:displayName>
            \\  </bp:{s}>
            \\
        , .{ bp_type, node.id, node.id, bp_type });
    }

    // List biochemical reactions
    for (net.edges.items, 0..) |edge, idx| {
        const l_node = net.nodes.items[edge.source_idx];
        const r_node = net.nodes.items[edge.target_idx];

        try writer.print(
            \\  <bp:BiochemicalReaction rdf:ID="Reaction_{}">
            \\    <bp:left rdf:resource="#{s}"/>
            \\    <bp:right rdf:resource="#{s}"/>
            \\  </bp:BiochemicalReaction>
            \\
        , .{ idx, l_node.id, r_node.id });
    }

    try writer.writeAll("</rdf:RDF>\n");
}
