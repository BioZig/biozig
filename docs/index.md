# BioZig

Biological computation built on first-principles representations.

BioZig is a deterministic, memory-efficient computational biology framework written in Zig. It provides a foundation for biological data representation and analysis, prioritizing packed, domain-specific memory structures over generic text representations.

## Core Philosophy

- **Biology Is Not Text**: Nucleotides, amino acids, and networks are encoded into compact binary representations, reducing memory footprint and improving cache locality.
- **Determinism**: All algorithms, samplers, and data structures are strictly deterministic.
- **Reproducibility**: Explicit metadata tracking for compilers, targets, hashes, and parameters.
- **Zero-Cost Interoperability**: Built with a stable C ABI to allow high-level languages (Python, R, Julia) to interface with zero-copy memory semantics.

## Documentation Index

### Overviews
- [Getting Started](getting-started.md)
- [Architecture](architecture.md)
- [Reproducibility](reproducibility.md)

### Layer Reference
- [Core](core.md) - Memory, SIMD, and determinism primitives.
- [Analytics](analytics.md) - Statistical engines and mathematics.
- [Molecular](molecular.md) - DNA, RNA, proteins, and variants.
- [Structural](structural.md) - Atomic and 3D residue representations.
- [Cellular](cellular.md) - Single-cell matrices, spatial coordinates, and lineages.
- [Systems](systems.md) - Biological networks, ontologies, and metabolic graphs.
- [Organismal](organismal.md) - Phenotypes and anatomies.
- [Population](population.md) - GWAS, haplotypes, and LD matrices.
- [Visualization](visualization.md) - Publication-ready asset generation.
- [Reporting](reporting.md) - Reproducible manuscript compilation.
- [ATLAZ](../ATLAZ/ATLAZ_ARCHITECTURE.md) - Topological lineage and recombination.
- [TiMSA](../TiMSA/timsa.md) - Topological alignment and epistasis.
