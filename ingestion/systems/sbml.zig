const std = @import("std");
const systems = @import("systems");
const network = systems.network;
const pathway = systems.pathway;

pub const SbmlParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SbmlParser {
        return .{ .allocator = allocator };
    }

    pub fn parse(self: SbmlParser, xml_data: []const u8) !struct { net: network.Network, path: pathway.Pathway } {
        var net = network.Network.init(self.allocator);
        errdefer net.deinit();

        var path = try pathway.Pathway.init(self.allocator, "sbml_pathway", "SBML Reconstructed Pathway");
        errdefer path.deinit();

        var species_map = std.StringHashMap(usize).init(self.allocator);
        defer {
            var iter = species_map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            species_map.deinit();
        }

        var current_reaction_id: ?[]const u8 = null;
        defer {
            if (current_reaction_id) |id| self.allocator.free(id);
        }

        var reactants = std.ArrayList([]const u8).empty;
        defer {
            for (reactants.items) |r| self.allocator.free(r);
            reactants.deinit(self.allocator);
        }

        var products = std.ArrayList([]const u8).empty;
        defer {
            for (products.items) |p| self.allocator.free(p);
            products.deinit(self.allocator);
        }

        var in_reactants = false;
        var in_products = false;

        var pos: usize = 0;

        // Parse XML tags streamingly
        while (pos < xml_data.len) {
            const lt_idx = std.mem.indexOfScalarPos(u8, xml_data, pos, '<') orelse break;
            const gt_idx = std.mem.indexOfScalarPos(u8, xml_data, lt_idx + 1, '>') orelse break;
            const raw_tag = xml_data[lt_idx + 1 .. gt_idx];
            pos = gt_idx + 1;

            if (raw_tag.len == 0) continue;

            if (raw_tag[0] == '/') continue; // closing tag

            var tokens = std.mem.tokenizeAny(u8, raw_tag, " \t\r\n/");
            const tag_name = tokens.next() orelse continue;

            if (std.mem.eql(u8, tag_name, "species")) {
                var id: ?[]const u8 = null;
                var name: ?[]const u8 = null;

                // Parse attributes
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val_raw = attr[eq_idx + 1 ..];
                        const val = std.mem.trim(u8, val_raw, "\"'");

                        if (std.mem.eql(u8, key, "id")) id = val;
                        if (std.mem.eql(u8, key, "name")) name = val;
                    }
                }

                if (id) |s_id| {
                    const node_name = name orelse s_id;
                    var node = try network.Node.init(self.allocator, node_name);
                    errdefer node.deinit();
                    try node.addMetadata("sbml_id", s_id);

                    const node_idx = try net.addNode(node);
                    try species_map.put(try self.allocator.dupe(u8, s_id), node_idx);
                    try path.addMember(node_name);
                }
            } else if (std.mem.eql(u8, tag_name, "reaction")) {
                var id: ?[]const u8 = null;
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val_raw = attr[eq_idx + 1 ..];
                        const val = std.mem.trim(u8, val_raw, "\"'");
                        if (std.mem.eql(u8, key, "id")) id = val;
                    }
                }
                if (current_reaction_id) |c_id| self.allocator.free(c_id);
                current_reaction_id = if (id) |r_id| try self.allocator.dupe(u8, r_id) else null;
                reactants.clearRetainingCapacity();
                products.clearRetainingCapacity();
            } else if (std.mem.eql(u8, tag_name, "listOfReactants")) {
                in_reactants = true;
                in_products = false;
            } else if (std.mem.eql(u8, tag_name, "listOfProducts")) {
                in_reactants = false;
                in_products = true;
            } else if (std.mem.eql(u8, tag_name, "speciesReference")) {
                var species_ref: ?[]const u8 = null;
                while (tokens.next()) |attr| {
                    if (std.mem.indexOfScalar(u8, attr, '=')) |eq_idx| {
                        const key = attr[0..eq_idx];
                        const val_raw = attr[eq_idx + 1 ..];
                        const val = std.mem.trim(u8, val_raw, "\"'");
                        if (std.mem.eql(u8, key, "species")) species_ref = val;
                    }
                }
                if (species_ref) |s_ref| {
                    if (in_reactants) {
                        try reactants.append(self.allocator, try self.allocator.dupe(u8, s_ref));
                    } else if (in_products) {
                        try products.append(self.allocator, try self.allocator.dupe(u8, s_ref));
                    }
                }
            }

            // If we hit end of reaction definition or next tag that closes reaction lists
            if (raw_tag[raw_tag.len - 1] == '/' and (std.mem.eql(u8, tag_name, "reaction") or std.mem.eql(u8, tag_name, "speciesReference"))) {
                // Check if we need to commit edges for the current reaction
                if (std.mem.eql(u8, tag_name, "reaction") or (std.mem.eql(u8, tag_name, "speciesReference") and !in_reactants and !in_products)) {
                    // Reaction finished
                    try commitReaction(species_map, &net, reactants.items, products.items);
                    for (reactants.items) |r| self.allocator.free(r);
                    reactants.clearRetainingCapacity();
                    for (products.items) |p| self.allocator.free(p);
                    products.clearRetainingCapacity();
                }
            }
        }

        // Final commit if any remains
        try commitReaction(species_map, &net, reactants.items, products.items);

        return .{ .net = net, .path = path };
    }

    fn commitReaction(
        species_map: std.StringHashMap(usize),
        net: *network.Network,
        reactants: []const []const u8,
        products: []const []const u8,
    ) !void {
        for (reactants) |r| {
            if (species_map.get(r)) |r_idx| {
                for (products) |p| {
                    if (species_map.get(p)) |p_idx| {
                        try net.addEdge(r_idx, p_idx, 1.0, true);
                    }
                }
            }
        }
    }
};

/// Serializes Network and Pathway back into standard SBML XML format
pub fn serialize(writer: anytype, net: network.Network, path: pathway.Pathway) !void {
    try writer.writeAll(
        \\<?xml version="1.0" encoding="UTF-8" standalone="no"?>
        \\<sbml xmlns="http://www.sbml.org/sbml/level3/version2/core" level="3" version="2">
        \\  <model id="BioZigModel" name="BioZig SBML Export">
        \\    <listOfSpecies>
        \\
    );

    for (net.nodes.items) |node| {
        const sbml_id = node.metadata.get("sbml_id") orelse node.id;
        try writer.print("      <species id=\"{s}\" name=\"{s}\" compartment=\"default\" hasOnlySubstanceUnits=\"false\" boundaryCondition=\"false\" constant=\"false\"/>\n", .{ sbml_id, node.id });
    }

    try writer.writeAll(
        \\    </listOfSpecies>
        \\    <listOfReactions>
        \\
    );

    // Reconstruct reactions from edges
    for (net.edges.items, 0..) |edge, idx| {
        const r_node = net.nodes.items[edge.source_idx];
        const p_node = net.nodes.items[edge.target_idx];
        const r_id = r_node.metadata.get("sbml_id") orelse r_node.id;
        const p_id = p_node.metadata.get("sbml_id") orelse p_node.id;

        try writer.print(
            \\      <reaction id="R_{}" reversible="false" fast="false">
            \\        <listOfReactants>
            \\          <speciesReference species="{s}" stoichiometry="1" constant="true"/>
            \\        </listOfReactants>
            \\        <listOfProducts>
            \\          <speciesReference species="{s}" stoichiometry="1" constant="true"/>
            \\        </listOfProducts>
            \\      </reaction>
            \\
        , .{ idx, r_id, p_id });
    }

    try writer.print(
        \\    </listOfReactions>
        \\  </model>
        \\</sbml>
        \\<!-- Pathway Member Count: {} -->
        \\
    , .{path.memberCount()});
}
