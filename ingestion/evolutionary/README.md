# Evolutionary Parsers

Implemented robust parsers for evolutionary and phylogenetic trees.

- **Newick**: Parses standard newick strings.
- **NEXUS**: Parses NEXUS block files, extracting trees from the TREES block.
- **PhyloXML**: Parses PhyloXML sequences.

Note: Parsers avoid deprecated `std.io` components and correctly utilize Zig `0.14-dev`'s unmanaged `ArrayList`.
