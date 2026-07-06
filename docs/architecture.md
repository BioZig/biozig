# Architecture

BioZig is structured hierarchically. Higher-level biological abstractions depend on lower-level primitives. 

## Dependency Graph

```text
Core
 ↓
Analytics
 ↓
Molecular
 ↓
Cellular
 ↓
Structural
 ↓
Systems
 ↓
Organismal
 ↓
Population
 ↓
Visualization
 ↓
Reporting
```

### 1. Core Layer
Handles all system interactions. Provides allocators, bitpacking, SIMD utilities, deterministic serialization, and thread pools. No biological logic exists here.

### 2. Analytics Layer
Provides numerical methods and statistical routines (e.g., Kahan summation, linear regression, multiple testing corrections) used by higher layers.

### 3. Molecular Layer
Defines base sequences. Implements 2-bit and 4-bit packed nucleotide representations, compact amino acids, and basic transcript mapping.

### 4. Cellular Layer
Defines cells as vectors of molecular features. Implements expression matrices (Dense, Compressed Sparse Row), spatial coordinates, and cell cycle states.

### 5. Structural Layer
Defines 3D spatial properties of molecules. Implements atomic coordinates, protein chains, and contact maps.

### 6. Systems Layer
Defines interactions between biological entities. Implements gene regulatory networks, metabolic reactions, signaling cascades, and biological ontologies (DAGs).

### 7. Organismal Layer
Defines macroscopic biological properties. Implements phenotype associations and anatomical ontologies.

### 8. Population Layer
Defines cohorts and evolutionary metrics. Implements GWAS association collections, Haplotype blocks, Linkage Disequilibrium matrices, and epidemiological study designs.

### 9. Visualization Layer
Translates data structures into graphical representations. Generates primitive geometric instructions (e.g., SVG elements) for statistical and network plots.

### 10. Reporting Layer
Consolidates visual outputs, text, and reproducibility records into standard output formats (Markdown, PDF, LaTeX, HTML).
