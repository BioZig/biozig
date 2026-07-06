#!/bin/bash
set -e

mkdir -p benchmarks/data

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

echo -e "\n## Evolutionary Layer Benchmarks\n" >> benchmarks/benchmark_results.md

echo "Generating dummy Newick..."
echo "((A:0.1,B:0.2):0.3,C:0.4);" > benchmarks/data/test.nwk

echo "Running NEWICK Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_evolutionary NEWICK $(pwd)/benchmarks/data/test.nwk >> benchmarks/benchmark_results.md 2>&1
rm benchmarks/data/test.nwk

echo "Generating dummy NEXUS..."
echo "#NEXUS" > benchmarks/data/test.nex
echo "BEGIN TAXA;" >> benchmarks/data/test.nex
echo "  DIMENSIONS NTAX=3;" >> benchmarks/data/test.nex
echo "  TAXLABELS A B C;" >> benchmarks/data/test.nex
echo "END;" >> benchmarks/data/test.nex
echo "BEGIN TREES;" >> benchmarks/data/test.nex
echo "  TREE tree1 = ((A:0.1,B:0.2):0.3,C:0.4);" >> benchmarks/data/test.nex
echo "END;" >> benchmarks/data/test.nex

echo "Running NEXUS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_evolutionary NEXUS $(pwd)/benchmarks/data/test.nex >> benchmarks/benchmark_results.md 2>&1
rm benchmarks/data/test.nex

echo "Generating dummy PhyloXML..."
echo '<?xml version="1.0" encoding="UTF-8"?>' > benchmarks/data/test.xml
echo '<phyloxml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.phyloxml.org http://www.phyloxml.org/1.10/phyloxml.xsd" xmlns="http://www.phyloxml.org">' >> benchmarks/data/test.xml
echo '  <phylogeny rooted="true">' >> benchmarks/data/test.xml
echo '    <clade>' >> benchmarks/data/test.xml
echo '      <clade>' >> benchmarks/data/test.xml
echo '        <branch_length>0.3</branch_length>' >> benchmarks/data/test.xml
echo '        <clade>' >> benchmarks/data/test.xml
echo '          <name>A</name>' >> benchmarks/data/test.xml
echo '          <branch_length>0.1</branch_length>' >> benchmarks/data/test.xml
echo '        </clade>' >> benchmarks/data/test.xml
echo '        <clade>' >> benchmarks/data/test.xml
echo '          <name>B</name>' >> benchmarks/data/test.xml
echo '          <branch_length>0.2</branch_length>' >> benchmarks/data/test.xml
echo '        </clade>' >> benchmarks/data/test.xml
echo '      </clade>' >> benchmarks/data/test.xml
echo '      <clade>' >> benchmarks/data/test.xml
echo '        <name>C</name>' >> benchmarks/data/test.xml
echo '        <branch_length>0.4</branch_length>' >> benchmarks/data/test.xml
echo '      </clade>' >> benchmarks/data/test.xml
echo '    </clade>' >> benchmarks/data/test.xml
echo '  </phylogeny>' >> benchmarks/data/test.xml
echo '</phyloxml>' >> benchmarks/data/test.xml

echo "Running PHYLOXML Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_evolutionary PHYLOXML $(pwd)/benchmarks/data/test.xml >> benchmarks/benchmark_results.md 2>&1
rm benchmarks/data/test.xml

echo "Evolutionary Layer Benchmark Complete."
