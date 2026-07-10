# Population Layer

## Purpose
The Population layer provides robust, memory-efficient data structures for population genetics, epidemiology, and evolutionary biology. It establishes standard representations for cohorts, genetic variants (GWAS, LD), selection signals, and demographic histories without conflating them with inference algorithms.

## Directory Layout
- `gwas/`: Genome-Wide Association Study records mapping variants to traits.
- `haplotype/`: Phased haplotype sequences and `HaplotypeBlock` coordination.
- `ld/`: Linkage Disequilibrium matrices and pairwise interaction records ($r^2$, $D'$).
- `ancestry/`: Directed graphs tracking population splits, admixture, and parent/derived relationships.
- `selection/`: Representations of positive/balancing selection signals (e.g., iHS, Tajima's D).
- `epidemiology/`: Case-Control study designs, cohorts, exposures, and outcomes.

## Public Types
- `gwas.AssociationCollection`, `gwas.AssociationRecord`
- `haplotype.HaplotypeBlock`, `haplotype.Haplotype`
- `ld.LDMatrix`, `ld.LinkageDisequilibriumRecord`
- `ancestry.AncestryGraph`, `ancestry.Population`
- `selection.SelectionCollection`, `selection.SelectionSignal`
- `epidemiology.CaseControlStudy`, `epidemiology.Cohort`

## Public APIs
- `gwas.AssociationCollection.getByVariant()`
- `haplotype.HaplotypeBlock.getHaplotype()`
- `ld.LDMatrix.get()`
- `ancestry.AncestryGraph.getDescendants()`
- `selection.SelectionCollection.getByLocus()`
- `epidemiology.CaseControlStudy.addAssociation()`

## Serialization Format
Binary serializations strictly validate expected ranges (e.g., $r^2 \in [0, 1]$). Cohorts serialize their baseline metadata and counts. High-density structures like `LDMatrix` serialize the flat 1D array representing the $N \times N$ matrix.

## Memory Model
Collections like `AssociationCollection` and `SelectionCollection` utilize Unmanaged `.empty` initializers. Hash maps (`std.StringHashMap(std.ArrayList(usize))`) serve as rapid indices, mapping biological string identifiers (like "rs1042522") to array offsets, preventing string duplication.

## Determinism Guarantees
- Ancestry relationships and study associations are appended sequentially, preserving explicit temporal order during serialization/deserialization.
- Confidence intervals and p-values are stored as `f64` using IEEE-754 standards, ensuring no implicit truncation alters statistical significance across platforms.

## Example Usage
```zig
const std = @import("std");
const gwas = @import("biozig").population.gwas;

var collection = gwas.AssociationCollection.init(allocator);
defer collection.deinit();

const record = try gwas.AssociationRecord.init(
    allocator, "rs1042522", "Height", 5e-8, 1.2, 1.0, 1.4
);
try collection.addRecord(record);

const hits = collection.getByTrait("Height");
std.debug.print("Found {d} significant associations.\n", .{hits.?.len});
```

## Limitations
- Phasing, admixture estimation, and simulation are out-of-scope; this layer only models the resulting representations.
- `LDMatrix` is represented as a dense structure; highly sparse or chromosome-scale block-diagonal matrices may require significant contiguous memory allocation.
