# Organismal Layer

## Purpose
The Organismal layer models high-level biological phenotypes, diseases, developmental stages, and anatomy. It connects the underlying molecular and cellular data to macroscopic, clinical, or observable traits.

## Directory Layout
- `phenotype/`: Observable traits and characteristics.
- `disease/`: Standardized disease representations.
- `development/`: Developmental stages and life-cycle events.
- `physiology/`: Physiological functions and systems.
- `anatomy/`: Anatomical structures and organ maps.

## Public Types
- `phenotype.Phenotype`
- `disease.Disease`
- `organismal.PhenotypeDiseaseLink`
- `development.Stage`
- `anatomy.Structure`

## Public APIs
- `phenotype.Phenotype.addTrait()`
- `disease.Disease.setSeverity()`
- `development.Stage.next()`

## Serialization Format
Organismal structures primarily serialize strict string identifiers (e.g., DOID, HPO terms) to maintain compatibility with external clinical databases. Structural links (like `PhenotypeDiseaseLink`) serialize their relationship weights and IDs.

## Memory Model
Relies on highly optimized `StringHashMap` instances to map clinical terms to their hierarchical relationships.

## Determinism Guarantees
- Identifiers are parsed and stored exactly as provided, preserving external database fidelity.
- Traversals of anatomical models guarantee fixed topological ordering.

## Example Usage
```zig
const std = @import("std");
const org = @import("biozig").organismal;

const link = org.PhenotypeDiseaseLink{
    .phenotype_id = "HP:0001250", // Seizures
    .disease_id = "DOID:1936",    // Epilepsy
    .weight = 1.0
};
```

## Limitations
- Does not implement phenotype prediction algorithms from genotype data (GWAS tools operate in the Population layer).
- Acts strictly as a semantic relationship model.
