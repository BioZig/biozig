# BioZig

**Biological computation built on first-principles representations.**

---

## Mission

**BioZig** is a high-performance, deterministic, and interoperable computational biology framework built in [Zig](https://ziglang.org/). It provides a foundational engine for modern bioinformatics, prioritizing biological-first data structures over generic text-based representations.

By adhering to a "Biology Is Not Text" philosophy, BioZig achieves extreme memory efficiency and computational throughput while maintaining bit-exact reproducibility and cross-language interoperability.

## Core Philosophy: "Biology Is Not Text"

Most bioinformatics software treats biological entities as strings (e.g., "ATCG" for DNA). BioZig rejects this abstraction in favor of compact, domain-specific representations:

*   **Packed Nucleotides:** 2-bit and 4-bit (ambiguity-aware) encodings.
*   **Compact Amino Acids:** Optimized encodings for protein primary and secondary structures.
*   **Biological Graphs:** Domain-specific graph structures for pathways, regulatory networks, and knowledge graphs.
*   **Structural Primitives:** Memory-aligned representations for atomic and residue-level structural data.

## Key Features

*   **Extreme Performance:** Leverages Zig's manual memory management and SIMD optimizations.
*   **Deterministic Execution:** Ensures reproducible results by tracking seeds, compiler versions, and hardware targets.
*   **Interoperability:** A stable C ABI allows seamless integration with Python, R, C++, Swift, Julia, and MATLAB.
*   **Layered Architecture:** Organized by biological abstraction levels (Molecular → Cellular → Organismal).
*   **Publication-Ready:** Built-in support for generating high-quality visualizations and structured reports (PDF, HTML, LaTeX).

---

## Project Structure

BioZig is organized into logical layers reflecting the hierarchy of biological systems:

```text
biozig/
├── core/             # Allocators, SIMD, Threading, Serialization
├── molecular/        # DNA, RNA, Protein, Variants, Transcripts
├── structural/       # Atoms, Residues, Chains, PDB/mmCIF support
├── systems/          # Networks, Pathways, Ontologies, Regulation
├── cellular/         # Single-cell, Spatial, Expression Matrices
├── organismal/       # Anatomy, Development, Phenotypes
├── population/       # GWAS, Haplotypes, Ancestry
├── evolutionary/     # Phylogeny, Comparative Genomics, Selection
├── analytics/        # Statistics, Clustering, Graph Analysis
├── visualization/    # Publication-quality figures (SVG, PDF, PNG)
├── reporting/        # Manuscript and supplementary report generation
├── interoperability/ # Bindings for Python, R, C++, Swift, etc.
└── utility/          # Benchmarking, Logging, Testing, Validation
```

---

## Interoperability Strategy

BioZig is designed to be a "computation engine." While the core is written in Zig, users can interact with it through their preferred high-level languages:

1.  **BioZig Core (Zig)** — High-performance implementation.
2.  **C ABI** — Stable interface layer.
3.  **Language Bindings** — Native-feeling wrappers for:
    *   **Python:** `import biozig`
    *   **R:** `library(biozig)`
    *   **Swift:** `import BioZig`
    *   **Julia, MATLAB, C++**

---

## Non-Goals

*   Creating a new programming language.
*   Replacing general-purpose data science environments (e.g., Pandas/R).
*   Building a generic machine learning framework.

BioZig focuses exclusively on the **computational infrastructure of biology.**

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details (coming soon).

## Author

**MD. Arshad**
*Department of Computer Science, Jamia Millia Islamia*

---
*Governed, Not Generated. Reference-as-Truth.*
