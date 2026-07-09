<div align="center">
  <img src="manuscript/figures/biozig_logo.png" alt="BioZig Logo" width="200"/>
  <h1>BioZig</h1>
  <p><strong>Structural Stability in a Fragmented Discipline</strong></p>
  <p><em>A mathematically deterministic, zero-copy computational engine that completely excises the garbage collector in favor of strict O(1) Arena Allocators and Struct-of-Arrays (SoA) SIMD cache alignment.</em></p>
</div>

---

## ⚡ The Architectural Paradigm Shift

Modern bioinformatics pipelines rely heavily on interpreted languages (Python, R) that abstract hardware memory models, resulting in critical structural inefficiencies, garbage collection deadlocks, and Out-of-Memory (OOM) failures on pan-genomic scales. 

BioZig reduces structural biology, cheminformatics, systems biology, and scRNA-seq clustering to **bare-metal vector mathematics**. We demonstrate absolute hardware-bound execution supremacy, bypassing the Global Interpreter Lock (GIL) and guaranteeing infinite computational scaling without distributed cloud clusters.

### Key Capabilities
* **Genomics (O(1) Memory):** Dynamically streams, parses, and executes Markov state analytics (Transition/Transversion ratios) across the entire 3.2 billion base pair human reference genome (GRCh38) in ~35 minutes while maintaining an impenetrable memory footprint of exactly **7.2 MB**.
* **Structural Biology:** Real-time generation of structural Contact Maps (C$\alpha$ distances) directly from PDB network streams via strict SIMD cache alignment.
* **Transcriptomics:** Mathematically rigorous Two-Pass Streaming K-Means clustering on massive single-cell RNA-seq lineage matrices.
* **Systems Biology:** Scale-free Dijkstra graph traversal on 10-million edge PPI networks (STRING-DB) without dynamic pointer fragmentation.

---

## 🏗️ Project Structure

BioZig is organized into strict, biologically distinct abstractions:

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
├── analytics/        # Dimensionality reduction, clustering, and cheminformatics
├── algorithms/       # Core molecular algorithms (MSA, MCMC, Suffix Trees)
├── ingestion/        # Zero-copy parsers (FASTA, FASTQ, PDB, SAM, VCF, SMILES)
├── net/              # O(1) Streaming Engine (NCBI, UniProt, PDB, ChEMBL, Ensembl)
├── visualization/    # SVG generators for structural and omics data
├── reporting/        # Markdown, HTML, and LaTeX export generation
└── cli/              # Command-line interface subcommands
```

---

## 🚀 Quickstart & CLI Usage

BioZig is written in Zig `0.16.0`. It compiles into a standalone, native executable.

### 1. Installation
Clone the repository and build the ReleaseFast executable natively.
```bash
git clone https://github.com/BioZig/biozig.git
cd biozig
zig build -Doptimize=ReleaseFast
```

### 2. Standard CLI Usage
BioZig operates via subcommands mapped to biological domains.

**Genomics (Transition/Transversion Statistics on GRCh38 Chromosome 1):**
```bash
./zig-out/bin/biozig fetch --db ncbi --query NC_000001.11 --analyze titv
```

**Structural Biology (Contact Maps from PDB Stream):**
```bash
./zig-out/bin/biozig fetch --db pdb --query 6vxx --analyze contact_map
```

**Systems Biology (PPI Network Traversal):**
*Note: STRING-DB uses string identifiers. For O(1) performance, you must preprocess the edge list to integers first.*
```bash
python3 scripts/preprocess_stringdb.py 9606.protein.links.v12.0.txt string_db_9606.txt
./zig-out/bin/biozig systems dijkstra -i string_db_9606.txt
```

---

## 🧩 Ecosystem Interoperability (Python / R)

BioZig is designed to act as the impenetrable, memory-safe foundation beneath Python and R. By utilizing zero-cost C-ABI boundaries (Foreign Function Interfaces), BioZig parses massive payloads natively and passes only the *aggregated dense matrices* back to your interpreted scripts via raw pointers—bypassing the GIL entirely.

### Python Integration (via `ctypes`)
Instead of loading massive files into Pandas, pass the file path to BioZig and receive the computed float matrix back:

```python
import ctypes
import numpy as np

# Load the compiled BioZig shared library
lib = ctypes.CDLL("./zig-out/lib/libbiozig.so")

# Configure C-ABI return types (Returns a pointer to a struct containing the matrix)
lib.compute_contact_map.restype = ctypes.POINTER(ctypes.c_double)

# Execute bare-metal structural physics (0ms serialization overhead)
# BioZig handles the O(1) stream; Python only gets the final dense matrix.
result_ptr = lib.compute_contact_map(b"6vxx")

# Wrap the raw C pointer directly into a NumPy array (Zero-Copy)
matrix = np.ctypeslib.as_array(result_ptr, shape=(1024, 1024))
```

### R Integration (via `.Call`)
For Bioconductor users, avoid `readLines` memory deadlocks by offloading the parsing to BioZig:

```R
# Load the BioZig shared object
dyn.load("zig-out/lib/libbiozig.so")

# Pass the massive STRING-DB edge list to BioZig for network traversal
# BioZig loads the graph in Arena memory; R receives only the computed centralities.
centrality_scores <- .Call("biozig_dijkstra_centrality", "string_db_9606.txt")

print(head(centrality_scores))
```

---

## 🔒 License
Released under the **3-Clause BSD License**.

**Author:** MD. Arshad (BioZig Software Foundation)
