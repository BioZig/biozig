#!/bin/bash
set -e

mkdir -p benchmarks/data

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

echo -e "\n## Systems Layer Benchmarks\n" >> benchmark_results.md

echo "Generating dummy GPML..."
echo '<?xml version="1.0" encoding="UTF-8"?>' > benchmarks/data/test.gpml
echo '<Pathway xmlns="http://pathvisio.org/GPML/2013a" Name="Test Pathway" Data-Source="WikiPathways" Version="1.0">' >> benchmarks/data/test.gpml
echo '  <DataNode TextLabel="Node A" GraphId="n1" Type="GeneProduct">' >> benchmarks/data/test.gpml
echo '    <Graphics CenterX="100.0" CenterY="100.0" Width="80.0" Height="20.0" ZOrder="32768" FontSize="10" Valign="Middle"/>' >> benchmarks/data/test.gpml
echo '    <Xref Database="" ID=""/>' >> benchmarks/data/test.gpml
echo '  </DataNode>' >> benchmarks/data/test.gpml
echo '  <DataNode TextLabel="Node B" GraphId="n2" Type="GeneProduct">' >> benchmarks/data/test.gpml
echo '    <Graphics CenterX="200.0" CenterY="100.0" Width="80.0" Height="20.0" ZOrder="32768" FontSize="10" Valign="Middle"/>' >> benchmarks/data/test.gpml
echo '    <Xref Database="" ID=""/>' >> benchmarks/data/test.gpml
echo '  </DataNode>' >> benchmarks/data/test.gpml
echo '  <Interaction GraphId="id_abc123">' >> benchmarks/data/test.gpml
echo '    <Graphics ZOrder="12288" LineThickness="1.0">' >> benchmarks/data/test.gpml
echo '      <Point X="140.0" Y="100.0" GraphRef="n1" RelX="1.0" RelY="0.0"/>' >> benchmarks/data/test.gpml
echo '      <Point X="160.0" Y="100.0" GraphRef="n2" RelX="-1.0" RelY="0.0" ArrowHead="Arrow"/>' >> benchmarks/data/test.gpml
echo '    </Graphics>' >> benchmarks/data/test.gpml
echo '    <Xref Database="" ID=""/>' >> benchmarks/data/test.gpml
echo '  </Interaction>' >> benchmarks/data/test.gpml
echo '</Pathway>' >> benchmarks/data/test.gpml

echo "Running GPML Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems GPML $(pwd)/benchmarks/data/test.gpml >> benchmark_results.md 2>&1
rm benchmarks/data/test.gpml

echo "Generating dummy BioPAX..."
echo '<?xml version="1.0" encoding="utf-8"?>' > benchmarks/data/test.owl
echo '<rdf:RDF xmlns:bp="http://www.biopax.org/release/biopax-level3.owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xsd="http://www.w3.org/2001/XMLSchema#">' >> benchmarks/data/test.owl
echo '  <bp:Pathway rdf:ID="pathway_1">' >> benchmarks/data/test.owl
echo '    <bp:displayName rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Dummy Pathway</bp:displayName>' >> benchmarks/data/test.owl
echo '    <bp:pathwayComponent rdf:resource="#reaction_1" />' >> benchmarks/data/test.owl
echo '  </bp:Pathway>' >> benchmarks/data/test.owl
echo '  <bp:BiochemicalReaction rdf:ID="reaction_1">' >> benchmarks/data/test.owl
echo '    <bp:left rdf:resource="#protein_A" />' >> benchmarks/data/test.owl
echo '    <bp:right rdf:resource="#protein_B" />' >> benchmarks/data/test.owl
echo '  </bp:BiochemicalReaction>' >> benchmarks/data/test.owl
echo '  <bp:Protein rdf:ID="protein_A">' >> benchmarks/data/test.owl
echo '    <bp:displayName rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Protein A</bp:displayName>' >> benchmarks/data/test.owl
echo '  </bp:Protein>' >> benchmarks/data/test.owl
echo '  <bp:Protein rdf:ID="protein_B">' >> benchmarks/data/test.owl
echo '    <bp:displayName rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Protein B</bp:displayName>' >> benchmarks/data/test.owl
echo '  </bp:Protein>' >> benchmarks/data/test.owl
echo '</rdf:RDF>' >> benchmarks/data/test.owl

echo "Running BioPAX Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems BIOPAX $(pwd)/benchmarks/data/test.owl >> benchmark_results.md 2>&1
rm benchmarks/data/test.owl

echo "Generating dummy SBML..."
echo '<?xml version="1.0" encoding="UTF-8"?>' > benchmarks/data/test.sbml
echo '<sbml xmlns="http://www.sbml.org/sbml/level3/version2/core" level="3" version="2">' >> benchmarks/data/test.sbml
echo '  <model id="dummy_model" name="Dummy Model">' >> benchmarks/data/test.sbml
echo '    <listOfSpecies>' >> benchmarks/data/test.sbml
echo '      <species id="spec_A" name="Species A" compartment="default" hasOnlySubstanceUnits="false" boundaryCondition="false" constant="false"/>' >> benchmarks/data/test.sbml
echo '      <species id="spec_B" name="Species B" compartment="default" hasOnlySubstanceUnits="false" boundaryCondition="false" constant="false"/>' >> benchmarks/data/test.sbml
echo '    </listOfSpecies>' >> benchmarks/data/test.sbml
echo '    <listOfReactions>' >> benchmarks/data/test.sbml
echo '      <reaction id="rxn_1" reversible="false" fast="false">' >> benchmarks/data/test.sbml
echo '        <listOfReactants>' >> benchmarks/data/test.sbml
echo '          <speciesReference species="spec_A" stoichiometry="1" constant="true"/>' >> benchmarks/data/test.sbml
echo '        </listOfReactants>' >> benchmarks/data/test.sbml
echo '        <listOfProducts>' >> benchmarks/data/test.sbml
echo '          <speciesReference species="spec_B" stoichiometry="1" constant="true"/>' >> benchmarks/data/test.sbml
echo '        </listOfProducts>' >> benchmarks/data/test.sbml
echo '      </reaction>' >> benchmarks/data/test.sbml
echo '    </listOfReactions>' >> benchmarks/data/test.sbml
echo '  </model>' >> benchmarks/data/test.sbml
echo '</sbml>' >> benchmarks/data/test.sbml

echo "Running SBML Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems SBML $(pwd)/benchmarks/data/test.sbml >> benchmark_results.md 2>&1
rm benchmarks/data/test.sbml

echo "Systems Layer Benchmark Complete."
