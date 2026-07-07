BioZig Context

Vision

BioZig is a high-performance, deterministic, and interoperable computational biology framework built in Zig.

The project is not intended to replace Python, R, Julia, MATLAB, C++, or Swift. Instead, BioZig acts as a biological computation engine with a stable C ABI, allowing scientists and developers to use BioZig from their preferred language.

The primary goals are:

* High performance
* Memory efficiency
* Deterministic execution
* Bit-exact reproducibility where possible
* Biological-first data representations
* Language interoperability
* Publication-ready outputs

⸻

Core Principles

Biology Is Not Text

Most existing bioinformatics software stores biological entities as strings.

Examples:

DNA:
ATCGATCG

Protein:
MKTIIALSYIFCLVFAD

BioZig aims to represent biological entities using compact computational representations whenever appropriate.

Examples:

* DNA (2-bit encoding)
* DNA ambiguity-aware representations
* Protein compact encodings
* Packed k-mer representations

The objective is to reduce memory consumption while improving computational efficiency.

⸻

Reproducibility

BioZig should provide deterministic execution and reproducible analyses.

Tracked metadata should include:

* Input hashes
* Output hashes
* Algorithm version
* Compiler version
* Runtime configuration
* Random seeds

⸻

Interoperability

BioZig is not Zig-exclusive.

Primary access methods:

* Zig
* C ABI
* Python bindings
* R bindings
* C++ bindings
* Swift bindings
* Julia bindings
* MATLAB bindings

Users should not need to learn Zig to use BioZig.

⸻

Architectural Layers

Core

Provides:

* Memory management
* SIMD utilities
* Threading
* Serialization
* Compression
* Hashing
* Deterministic execution support

No biological concepts should exist in this layer.

⸻

Molecular

Provides biological sequence primitives:

* DNA
* RNA
* Protein
* Codon
* Transcript
* Peptide
* Variant

⸻

Structural

Provides:

* Atom
* Residue
* Chain
* Model
* Assembly

Supports:

* PDB
* mmCIF

Future structural analysis modules may be added later.

⸻

Systems

Provides:

* Biological networks
* Pathways
* Regulatory systems
* Signaling systems
* Knowledge graphs

Biological graph types should be represented as domain-specific entities rather than generic graphs.

⸻

Cellular

Provides:

* Expression matrices
* Single-cell representations
* Spatial biology structures

⸻

Organismal

Provides representations linking molecular data to organism-level observations.

⸻

Population

Provides:

* Population genetics primitives
* Haplotype representations
* Population-scale analyses

⸻

Evolutionary

Provides:

* Phylogenetic structures
* Comparative genomics utilities
* Evolutionary analyses

⸻

Domain Modules

Domain modules are user-facing APIs built on top of core biological primitives.

Examples:

* Genomics
* Transcriptomics
* Proteomics
* Epigenomics
* Metagenomics
* Metabolomics
* Synthetic Biology

⸻

Visualization

Visualization is a first-class component.

Goals:

* Publication-ready figures
* Interactive exploration
* Reproducible graphics

Supported output targets may include:

* SVG
* PNG
* PDF
* HTML

⸻

Reporting

BioZig should support structured reporting.

Potential report outputs:

* HTML
* PDF
* Markdown
* LaTeX

Reports should contain:

* Methods
* Parameters
* Statistics
* Figures
* Tables
* Reproducibility metadata

⸻

Non-Goals

Current non-goals:

* Creating a new programming language
* Replacing Python
* Replacing R
* Building a general-purpose machine learning framework
* Building a notebook environment

BioZig focuses on biological computation and analysis infrastructure.
