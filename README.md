# BioZig

Biology computed exactly.

![BioZig](docs/biozig_logo.png)

## Architecture

BioZig enforces strict zero-copy data ingestion and static memory boundaries. It operates without a garbage collector, relying exclusively on `O(1)` Arena Allocators and Struct-of-Arrays (SoA) memory layouts to guarantee SIMD vectorization across CPU registers.

### Core Specifications
* **Memory Model:** Zero-copy ingestion via memory-mapped files. All allocations are arena-bound. Memory limits are deterministically enforced via the Structural Recomputation Framework (SRFScheduler).
* **Execution:** Unrestricted multi-threading (`std.Thread.Pool`). Bypasses interpreted environment limitations (e.g., Python GIL).
* **Dependency Chain:** Zero external dependencies. Pure Zig compilation.

### Implemented Subsystems
* **Genomics:** Constant-time `O(1)` streaming parsers for FASTA/FASTQ. Validated on GRCh38 (3.2Gb) with a stable 7.2 MB allocation footprint.
* **Structural Biology:** Vectorized Kabsch algorithm for RMSD and pairwise Euclidean contact map generation from PDB coordinate streams.
* **Systems Biology:** Graph traversal (Dijkstra/A*) on large-scale PPI networks (e.g., STRING-DB) using contiguous memory arrays.
* **Transcriptomics:** Out-of-core sparse matrix factorization and Two-Pass Streaming K-Means for scRNA-seq clustering.

## Documentation & Architecture

Comprehensive technical specifications and implementation details are maintained in the [`docs/`](docs/index.md) directory to prevent redundancy.

### Domain Modules
* [`core`](docs/core.md) — Custom allocators and linear algebra primitives
* [`molecular`](docs/molecular.md) — DNA/RNA/Protein data structures
* [`structural`](docs/structural.md) — 3D coordinate geometry
* [`systems`](docs/systems.md) — Graph network structures
* [`cellular`](docs/cellular.md) — Sparse count matrices
* [`organismal`](docs/organismal.md) — Phenotypic mapping
* [`population`](docs/population.md) — VCF parsing and population genetics
* [`evolutionary`](docs/evolutionary.md) — Phylogenetics (Newick parsing)
* [`analytics`](docs/analytics.md) — Dimensionality reduction (SVD/K-Means)
* [`algorithms`](docs/algorithms.md) — Sequence alignment, suffix trees
* [`ingestion`](docs/ingestion.md) — Zero-copy parsers
* [`net`](docs/net.md) — Socket-based data fetching
* [`visualization`](docs/visualization.md) — Data export routines
* [`reporting`](docs/reporting.md) — Markdown/LaTeX serializers
* [`cli`](docs/CLI.md) — Command-line interface
* [`atlaz`](ATLAZ/ATLAZ_ARCHITECTURE.md) — Topological lineage and recombination analysis
* [`timsa`](TiMSA/timsa.md) — Topology-inspired multiple sequence alignment and epistasis

## Quickstart

Requires Zig `0.16.0`. See [`docs/getting-started.md`](docs/getting-started.md) for full compilation and FFI bridging (Python/R) instructions.

```bash
git clone https://github.com/BioZig/biozig.git
cd biozig
zig build -Doptimize=ReleaseFast

# Genomic Transition/Transversion Ratio
./zig-out/bin/biozig fetch --db ncbi --query NC_000001.11 --analyze titv
```

For advanced usage, refer to the [Command Line Reference](docs/CLI.md) and [C-ABI Interoperability](docs/architecture.md).

## License
3-Clause BSD License.

**Creator and Curator:** MD. Arshad (BioZig Software Foundation)

**Website:** [https://biozig.org/](https://biozig.org/)
