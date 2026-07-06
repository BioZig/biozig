const std = @import("std");

pub fn generateNewick(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator, "(((A:0.1,B:0.2)C:0.3,D:0.4)E:0.5,F:0.6)Root;\n");
    return out.toOwnedSlice(allocator);
}

pub fn generateNexus(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator,
        \\#NEXUS
        \\BEGIN TAXA;
        \\  DIMENSIONS NTAX=4;
        \\  TAXLABELS A B D F;
        \\END;
        \\BEGIN TREES;
        \\  TREE deterministic = (((A:0.1,B:0.2)C:0.3,D:0.4)E:0.5,F:0.6)Root;
        \\END;
    );
    return out.toOwnedSlice(allocator);
}

pub fn generatePhyloXml(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator,
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<phyloxml xmlns="http://www.phyloxml.org">
        \\  <phylogeny>
        \\    <clade>
        \\      <name>Root</name>
        \\      <clade>
        \\        <name>E</name>
        \\        <branch_length>0.5</branch_length>
        \\        <clade>
        \\          <name>C</name>
        \\          <branch_length>0.3</branch_length>
        \\          <clade><name>A</name><branch_length>0.1</branch_length></clade>
        \\          <clade><name>B</name><branch_length>0.2</branch_length></clade>
        \\        </clade>
        \\        <clade><name>D</name><branch_length>0.4</branch_length></clade>
        \\      </clade>
        \\      <clade><name>F</name><branch_length>0.6</branch_length></clade>
        \\    </clade>
        \\  </phylogeny>
        \\</phyloxml>
    );
    return out.toOwnedSlice(allocator);
}
