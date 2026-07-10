# Cellular Layer

## Purpose
The Cellular layer models physical cells, populations of cells (clusters), their spatial geometries, and the dynamic signaling and communication events that exist between them. It provides domain-specific data structures primarily designed for single-cell, spatial transcriptomics, and developmental lineages.

## Directory Layout
- `expression/`: Dense and Compressed Sparse Row (CSR) biological matrices.
- `singlecell/`: Individual cell representations, metadata tracking, and collections.
- `spatial/`: 2D/3D coordinate systems and fixed-grid neighborhood indices.
- `lineage/`: Directed cell lineage trees supporting ancestry traversal.
- `cellcycle/`: Standard eukaryotic phase tracking (G1, S, G2, M).
- `communication/`: Ligand-receptor interaction structures and communication graphs.

## Public Types
- `expression.DenseMatrix`, `expression.SparseMatrix`
- `singlecell.Cell`, `singlecell.CellCollection`
- `spatial.SpatialCell`, `spatial.SpatialIndex`
- `lineage.LineageNode`, `lineage.LineageTree`
- `cellcycle.State`, `cellcycle.Phase`
- `communication.Interaction`, `communication.InteractionGraph`

## Public APIs
- `expression.DenseMatrix.applyRowNormalization()`
- `singlecell.CellCollection.Neighborhood.addEdge()`
- `spatial.SpatialIndex.findNeighbors()`
- `lineage.LineageTree.getAncestry()`
- `cellcycle.Utils.assignPhase()`
- `communication.InteractionGraph.getInteractions()`

## Serialization Format
All structs implement recursive, deterministic `.serialize()` and `.deserialize()` APIs mapping to binary. 
- Matrices explicitly serialize their dimensions and data layouts (e.g., `indptr` and `indices` for CSR).
- `CellCollection` annotations and `Cell` metadata serialize map capacity followed by key-value string slices.

## Memory Model
Highly efficient Unmanaged memory paradigms are strictly enforced. Large collections (e.g., `CellCollection` and `InteractionGraph`) instantiate with `.empty` and require explicit allocator passing during `.append()` operations.

## Determinism Guarantees
- `SpatialIndex` neighbors are discovered and added in a predictable, stable array-index order based on the initialization slice.
- Lineage tree traversal uses deterministic Breadth-First-Search (BFS).

## Example Usage
```zig
const cell_mod = @import("biozig").cellular.singlecell;

var collection = cell_mod.CellCollection.init(allocator);
defer collection.deinit();

var cell = try cell_mod.Cell.init(allocator, "Cell_A", 2000);
try cell.addMetadata("cell_type", "T-Cell");
try collection.addCell(cell); // Cell ownership transferred
```

## Limitations
- `SparseMatrix` handles standard CSR logic; column-based rapid inserts (CSC) are not natively supported.
- `SpatialIndex` uses a fixed-grid naive boundary iteration rather than an R-Tree or KD-Tree, limiting performance for massive sparse volumes.
