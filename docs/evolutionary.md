# Evolutionary

The `evolutionary` module provides data structures and algorithms for phylogenetics and comparative genomics.

## Phylogenetics

### Tree Construction
- **Neighbor-Joining (NJ):** Agglomerative clustering method for phylogenetic tree creation based on distance matrices.
- **UPGMA:** Unweighted Pair Group Method with Arithmetic Mean.

### Tree Optimization
- **Nearest Neighbor Interchange (NNI):** Tree rearrangement topology search.
- **Subtree Pruning and Regrafting (SPR):** Advanced topological rearrangement.

### Tree Statistics
- **Robinson-Foulds Distance:** Computes the symmetric difference between two unrooted trees.

### Formats
Supports parsing and serialization for common evolutionary tree formats:
- Newick
- Nexus
- PhyloXML
