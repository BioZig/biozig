# BioZig CLI Reference Manual

BioZig is a high-performance, out-of-core, zero-copy bioinformatics engine. The CLI is designed around a strictly domain-driven architecture, enabling massive parallel data analysis right from your terminal without requiring Python or R scripts.

## Core Architecture
BioZig runs natively using `mmap` zero-copy memory boundaries. This means whether you pipe data to BioZig using standard Unix tools or pass large files directly, the CLI will map the files without touching the heap, completely eliminating Out-Of-Memory (OOM) crashes.

---

## Global Options

The BioZig CLI enforces strict, standard POSIX-style flags across all commands:

*   `-i`, `--input <path>`: The absolute or relative path to the input file. You can also specify `-` to pipe data into BioZig from `stdin`.
*   `-o`, `--output <path>`: The file destination for the analysis results. If omitted, BioZig outputs directly to `stdout`.
*   `-f`, `--format <type>`: The output format for standard streams. Available formats are `text` (default, standard TSV output) or `json` (for programmatic pipelines or APIs).
*   `-t`, `--threads <num>`: Set the number of CPU threads used for multi-threading heavily parallelizable computations (default: 1).
*   `-r`, `--report <path>`: Generates a human-readable compiled report (e.g. `summary.md`) combining graphs, statistics, and runtimes.
*   `-p`, `--plot`: Generates an inline ANSI/ASCII visualization plot directly in your terminal output.
*   `-h`, `--help`: Show the detailed help message for any domain or subcommand.

---

## Domain: Genomics
Handles genomic sequence alignment, mapping, and analysis.

### Commands
*   `align`: Align sequencing reads to a reference genome.
*   `index`: Generate CSI/Tabix indices for variants.
*   `parse`: Stream and validate uncompressed or BGZF files.
*   `kmer`: Count K-mers and build spectra.
*   `hmm`: Hidden Markov Model motif searching.
*   `gibbs`: Gibbs sampling for motif discovery.
*   `suffix-tree`: Suffix tree construction and exact matching.
*   `assembly`: De Bruijn graph sequence assembly.
*   `msa`: Multiple Sequence Alignment.

---

## Domain: Analytics
Statistical models, matrix decompositions, and clustering.

### Commands
*   `pca`: Principal Component Analysis.
*   `nmf`: Non-negative Matrix Factorization.
*   `mds`: Multidimensional Scaling.
*   `descriptive`: Compute descriptive statistics (mean, variance, skewness).
*   `correlation`: Compute correlation matrices (Pearson, Spearman).
*   `hypothesis`: Statistical hypothesis testing (t-test, ANOVA).
*   `distributions`: Fit biological probability distributions.
*   `multiple_testing`: False Discovery Rate (FDR) / Bonferroni correction.
*   `regression`: Linear, Logistic, and generalized regression.
*   `survival`: Kaplan-Meier and Cox Proportional Hazards.
*   `dispersion`: Negative Binomial GLM bulk differential expression.
*   `biology`: Domain-specific statistical biology tests.
*   `enrichment`: Gene Set Enrichment Analysis (GSEA) and Over-Representation.
*   `metrics`: Sliding window GC content, transition/transversion ratio.
*   `umap`: Uniform Manifold Approximation and Projection.
*   `tsne`: t-Distributed Stochastic Neighbor Embedding.
*   `kmeans`: K-Means Clustering.
*   `dbscan`: Density-Based Spatial Clustering of Applications with Noise.
*   `hierarchical`: Hierarchical Clustering.
*   `node2vec`: Graph node embeddings (Node2Vec).
*   `spectral`: Spectral clustering/embedding.
*   `sparse`: Sparse matrix operations.
*   `svd`: Singular Value Decomposition.
*   `spia`: Signaling Pathway Impact Analysis.
*   `markov`: Markov sequence models.
*   `kmer_stats`: K-mer statistics and spectra.

---

## Domain: Structural
3D protein structures and interactions.

### Commands
*   `atom`: Atom-level operations.
*   `residue`: Residue-level operations.
*   `chain`: Chain-level operations.
*   `model`: Model-level operations.
*   `assembly`: Biological assembly operations.
*   `geometry`: Structural geometry and RMSD analysis.
*   `contacts`: Contact maps and hydrogen bonds.
*   `surfaces`: Surface area metrics.
*   `pockets`: Pocket statistics and identification.
*   `dock`: Molecular docking simulation.
*   `dynamics`: Molecular dynamics (Verlet, Simulated Annealing).
*   `anm`: Elastic Network Models (ANM Hessian).
*   `threading`: Fold recognition / Threading DP.
*   `rotamers`: Sidechain packing / Rotamers.
*   `ingestion`: Structure parsing (PDB, mmCIF, mol2, sdf, pqr).

---

## Domain: Reporting
Automated reporting and publication exports.

### Commands
*   `html`: Export interactive HTML reports.
*   `latex`: Export LaTeX documents.
*   `manuscript`: Generate structured manuscripts.
*   `markdown`: Export Markdown reports.
*   `pdf`: Export PDF reports.
*   `supplement`: Generate supplementary materials.

---

## Domain: Visualize
Render beautiful biological data and plots.

### Commands
*   `dashboards`: Render composite interactive dashboards.
*   `network`: Render biological networks and interactions.
*   `omics`: Render omics data (heatmaps, volcano plots, PCA).
*   `phylogeny`: Render phylogenetic trees.
*   `publication`: Render publication-ready composite figures.
*   `sequence`: Render sequence statistics (GC content, coverage).
*   `structure`: Render molecular structures and contact maps.

---

## Domain: Cellular
Single-cell tools for dimensionality reduction and clustering.

### Commands
*   `umap`: Uniform Manifold Approximation and Projection.
*   `tsne`: t-Distributed Stochastic Neighbor Embedding.
*   `kmeans`: K-Means Clustering.
*   `zinb`: Zero-Inflated Negative Binomial modeling.
*   `pseudotime`: Trajectory Inference.

---

## Domain: Systems
Systems biology and network analysis.

### Commands
*   `maxflow`: Edmonds-Karp / Push-Relabel for flux networks.
*   `motif`: Graphlet / Network Motif Counting.
*   `layout`: Force-Directed Layout (Fruchterman-Reingold).
*   `centrality`: Network Centrality (Betweenness, Closeness, PageRank).
*   `community`: Community Detection (Louvain).
*   `network`: General network properties (components, degree, paths).
*   `metabolism`: Metabolic flux and stoichiometry.
*   `signaling`: Signaling network analysis.
*   `pathway`: Pathway enrichment and traversal.
*   `regulation`: Gene regulatory network inference.
*   `ontology`: Biomedical ontology integration.
*   `knowledgegraph`: Knowledge graph queries and embedding.
*   `sbml`: Parse Systems Biology Markup Language.
*   `biopax`: Parse BioPAX format.
*   `gpml`: Parse GenMAPP Pathway Markup Language.

---

## Domain: Population
Population genetics analysis.

### Commands
*   `gwas`: Genome-Wide Association Studies (Linear Mixed Models).
*   `admixture`: Expectation-Maximization for ancestral proportions.
*   `ibd`: Identity by Descent / State detection.
*   `hwe`: Hardy-Weinberg Equilibrium Exact Test.
*   `ld`: Linkage Disequilibrium statistics.
*   `selection`: Selection signal (Tajima's D proxy).
*   `epi`: Epidemiological summary statistics.
*   `impute`: Li-Stephens Model imputation.
*   `fstats`: Wright's F-statistics (Fis, Fst, Fit).
*   `vstats`: Variant statistics (Transitions, Transversions).
*   `vmatch`: Variant matching and overlap detection.
*   `vfilter`: Variant filtering and sorting.

---

## Domain: Evolutionary
Phylogenetics and evolutionary models.

### Commands
*   `nj`: Neighbor-Joining Tree Construction.
*   `upgma`: UPGMA Tree Construction.
*   `mle`: Maximum Likelihood Estimation (Felsenstein's pruning).
*   `parsimony`: Maximum Parsimony (Fitch's algorithm).
*   `mcmc`: Bayesian Inference of Phylogeny (MCMC).
*   `bootstrap`: Felsenstein Bootstrapping.
*   `nni`: Nearest Neighbor Interchange (NNI).
*   `spr`: Subtree Pruning and Regrafting (SPR).
*   `stats`: Compute Tree Statistics.
*   `rf-distance`: Robinson-Foulds Distance.
*   `parse-newick`: Parse and Serialize Newick Trees.
*   `parse-nexus`: Parse and Serialize Nexus Trees.
*   `parse-phyloxml`: Parse and Serialize PhyloXML Trees.

---

## Unix Pipeline Integration Examples

Because BioZig outputs clean standard text by default (and can ingest from `-`), you can chain it natively into advanced pipelines:

**Example 1: Streaming JSON to JQ**
```bash
biozig analytics pca -i 1M_cells.mtx -f json | jq '.eigenvalues[] | select(.variance > 0.05)'
```

**Example 2: Compressing Aligned Output on the Fly**
```bash
biozig genomics align -i reads.fastq --ref genome.fa | gzip > output.bam
```

**Example 3: Visualizing Terminal Outputs Instantly**
```bash
biozig structural contacts -i viral_envelope.mmcif -p
```
*(Prints an ASCII topological map of the viral envelope contacts before exiting)*
