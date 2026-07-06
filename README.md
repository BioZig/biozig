# BioZig

Biological computation framework built in Zig.

## Overview

BioZig provides data structures and algorithms for bioinformatics, prioritizing domain-specific representations over string manipulation. It utilizes explicit memory management to process biological data with exact reproducibility.

## Features

*   **Memory Efficiency:** 2-bit and 4-bit ambiguity-aware nucleotide encodings.
*   **Determinism:** Seed-tracked algorithms and fixed allocator boundaries.
*   **Command-Line Interface:** Native standalone executable `biozig` for direct Unix pipeline integration via standard streams.
*   **Modular Architecture:** Components are separated by biological abstraction level.

## Project Structure

```text
biozig/
├── core/             # Allocators, standard math, generic collections
├── molecular/        # DNA, RNA, Protein data structures
├── structural/       # Atomic and residue-level geometry
├── systems/          # Pathway and network abstractions
├── cellular/         # Single-cell and spatial matrix structures
├── organismal/       # Phenotypic and developmental mapping
├── population/       # Genomic variation and population statistics
├── evolutionary/     # Phylogenetics and substitution models
├── analytics/        # Dimensionality reduction and clustering
├── algorithms/       # Core molecular algorithms (MSA, MCMC, Suffix Trees)
├── ingestion/        # Zero-copy parsers for FASTA, FASTQ, PDB, SAM, VCF
├── visualization/    # SVG generators for structural and omics data
├── reporting/        # Markdown, HTML, and LaTeX export generation
└── cli/              # Command-line interface subcommands
```

## Setup and Usage

BioZig operates as a standalone CLI executable.

1.  **Build the Executable**
    Compile the project using the Zig build system (requires Zig `0.14.0` or later):
    ```bash
    zig build
    ```
    This produces the executable at `zig-out/bin/biozig`.

2.  **Run the CLI**
    The CLI is structured by biological domain:
    ```bash
    ./zig-out/bin/biozig <domain> <subcommand> [options]
    ```

    Example usage:
    ```bash
    ./zig-out/bin/biozig genomics align -i input.fasta
    ```

3.  **Run Tests**
    Execute the exhaustive unit test suite to verify internal integrity:
    ```bash
    zig build test
    ```
    For detailed information on the 440+ exhaustive edge-case test suites, the `tests/` directory structure, and the custom `run_tests.sh` module mapping wrapper, please refer to the [Testing Documentation](docs/TESTING.md).

## License

This project is licensed under the MIT License.

## Author

MD. Arshad
Department of Computer Science, Jamia Millia Islamia
