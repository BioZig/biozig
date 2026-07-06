const std = @import("std");

pub fn generateSbml(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator,
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<sbml xmlns="http://www.sbml.org/sbml/level3/version1/core" level="3" version="1">
        \\  <model id="glycolysis" name="Glycolysis">
        \\    <listOfCompartments>
        \\      <compartment id="cytosol" size="1" constant="true"/>
        \\    </listOfCompartments>
        \\    <listOfSpecies>
        \\      <species id="glucose" compartment="cytosol" initialConcentration="10" hasOnlySubstanceUnits="false" boundaryCondition="false" constant="false"/>
        \\      <species id="g6p" compartment="cytosol" initialConcentration="0" hasOnlySubstanceUnits="false" boundaryCondition="false" constant="false"/>
        \\    </listOfSpecies>
        \\    <listOfReactions>
        \\      <reaction id="hexokinase" reversible="false" fast="false">
        \\        <listOfReactants>
        \\          <speciesReference species="glucose" stoichiometry="1" constant="true"/>
        \\        </listOfReactants>
        \\        <listOfProducts>
        \\          <speciesReference species="g6p" stoichiometry="1" constant="true"/>
        \\        </listOfProducts>
        \\      </reaction>
        \\    </listOfReactions>
        \\  </model>
        \\</sbml>
    );
    return out.toOwnedSlice(allocator);
}

pub fn generateGpml(allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(allocator,
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<Pathway xmlns="http://pathvisio.org/GPML/2013a" Name="Glycolysis">
        \\  <DataNode TextLabel="Glucose" GraphId="n1" Type="Metabolite" />
        \\  <DataNode TextLabel="G6P" GraphId="n2" Type="Metabolite" />
        \\  <Interaction GraphId="i1">
        \\    <Graphics>
        \\      <Point GraphRef="n1" />
        \\      <Point GraphRef="n2" />
        \\    </Graphics>
        \\  </Interaction>
        \\</Pathway>
    );
    return out.toOwnedSlice(allocator);
}
