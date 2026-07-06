# Organismal and Population Corpus Manifest

## Specification
The Organismal and Population Corpus generates deterministic phylogenetic trees and population genomic structures.

## Generation Rules
* **Newick Generation**: A deterministic bifurcating tree of 5 taxa with fixed branch lengths.
* **NEXUS Generation**: The same tree in NEXUS format with a TAXA block.
* **PhyloXML Generation**: The same tree in PhyloXML format.

## Expected Outputs
* Valid `.newick`, `.nexus`, and `.phyloxml` files representing identical topologies.

## Reproducibility
Generated natively via `validation/corpus/organismal.zig`.
