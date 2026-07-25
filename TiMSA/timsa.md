# TiMSA - Topology-inspired Multiple Sequence Alignment

TiMSA is the first topological multiple sequence alignment (MSA) geometry engine, developed as a core module in BioZig. It fundamentally changes how sequences are aligned by projecting them onto mathematical manifolds to identify true structural and functional conservation, transcending standard affine gap scoring.

## Usage

TiMSA is fully integrated into the BioZig CLI as a standalone domain.

```bash
biozig timsa <mode> -i <input.fasta> [-f fasta|json|clustal|stockholm] > output.file
```

### ATLAZ Integration Pipeline
TiMSA is biologically coupled with **ATLAZ** (Alignment, Topology, and Lineage Analysis in Zig) to compute structural ablation, 1-Wasserstein optimal transport, and $H_1$ recombination loops.
Because ATLAZ utilizes a zero-copy native FASTA memory-mapped parser, TiMSA outputs should be written to disk and instantly fed into the downstream topology engine:
```bash
biozig timsa align -i dataset.fasta > aligned_dataset.fasta
biozig atlaz run --input aligned_dataset.fasta --mode reticulate 
```

### Supported Output Formats (`-f`)
*   **`fasta` (Default):** Standard blocked FASTA format for generic upstream tooling and direct ATLAZ consumption.
*   **`json`:** Highly structured API output containing node consensus and alignments.
*   **`clustal`:** Canonical `CLUSTAL W (1.81)` standard interleaved headers and sequence blocks for phylogenetic solvers (e.g., IQ-TREE).
*   **`stockholm`:** `STOCKHOLM 1.0` unrolled standard, directly compatible with `HMMER` for generating Profile Hidden Markov Models in drug discovery.

### Modes and Biological Interpretations

TiMSA is not a monolithic algorithm; it acts as an alignment state machine supporting multiple modes depending on the biological question at hand:

#### 1. `biozig timsa cluster` (TiMSA-Cluster)
- **Mathematical Lens**: $H_0$ persistence (connected components).
- **Biological Question**: "What natural families exist?"
- **Behavior**: Projects the dataset into topological space and measures the 0-dimensional Wasserstein distance to automatically identify evolutionary cohorts without computing the full MSA, functioning as a high-speed structural clustering filter.

#### 2. `biozig timsa align` (TiMSA-Align)
- **Mathematical Lens**: Global Alignment + Wasserstein refinement.
- **Biological Question**: "How do these sequences align globally?"
- **Behavior**: Extracts a topological manifold from an initial progressive alignment, then iteratively guides profile re-alignment using Wasserstein distance until convergence ($\Delta W_p < 0.05$). The resulting MSA balances standard homology with functional structural constraints.

#### 3. `biozig timsa domain` (TiMSA-Domain)
- **Mathematical Lens**: Local alignment (Smith-Waterman) + topological subgraph isolation.
- **Biological Question**: "Where are the functional domains?"
- **Behavior**: TiMSA-Domain is a planned mode that will use Smith-Waterman local alignment to isolate shared domains. Currently, TiMSA performs global alignment only. 

#### 4. `biozig timsa rigidity` (TiMSA-Rigidity)
- **Mathematical Lens**: Topological Sentinel / Column Ablation + Targeted Refinement.
- **Biological Question**: "Which residues are structurally essential?"
- **Behavior**: Employs an **Ablation Gradient** ($\Delta W_p$). TiMSA systematically isolates active site sentinels by mathematically stripping columns and measuring the structural deformation. The distance matrix is strictly patched using an $O(1)$ incremental update model ($O(L \cdot N^2)$ total complexity), avoiding costly full-space recomputations while generating exact structural sensitivity scores.

#### 5. `biozig timsa recomb` (TiMSA-Recomb)
- **Mathematical Lens**: $H_1$ Sparse Boundary Matrix Reduction over $GF(2)$.
- **Biological Question**: "Where are the recombination events and structural voids?"
- **Behavior**: Harnesses $H_1$ Persistent Homology. It implements a bitwise sparse accumulator to rapidly detect $H_1$ cycles (loops in the distance graph), directly identifying and outputting structural recombination breakpoints without combinatorial explosion.

#### 6. `biozig timsa consensus` (TiMSA-Consensus)
- **Mathematical Lens**: Frequency-based structural summary.
- **Biological Question**: "What is the dominant structural sequence signature?"
- **Behavior**: Ignores topological deviations and strictly calculates the high-confidence canonical sequence across the entire aligned manifold, treating insertions as noise unless statistically significant.

## Configuration & Scoring
TiMSA allows explicit algorithmic tuning via `TiMSAConfig`, which enforces constraints system-wide:
- **`memory_budget_bytes`**: Strict memory ceiling (default 100MB) enforced via block-based processing.
- **`gap_open` / `gap_extend`**: Affine gap penalties (default -10, -2).
- **`match_score` / `mismatch_score`**: Explicit base scoring overrides (default 5, -4).
- **`recurrence_type`**: Toggle between Global, Local, SemiGlobal, and Profile logic.

## Algorithmic Architecture

TiMSA operates through a deterministic 5-Phase pipeline, heavily optimized for specific topological manifolds:
1. **Graph Reconstruction**: Sequences are hashed into a k-mer space to construct $k$-NN structural neighborhoods.
2. **Topological Clustering ($H_0$ & $H_1$)**: Vietoris-Rips complexes compute raw Persistent Homology. For $H_0$ (connected components), TiMSA bypasses dense boundary matrices entirely by deploying an $O(E \cdot \alpha(V))$ Kruskal's Union-Find fast-path algorithm. For $H_1$, the distance matrix is reduced over $Z_2$ using sparse bitwise accumulators.
3. **Guide Tree Construction (`upgma_tree.zig`)**: Distances are clustered into an Unweighted Pair Group Method with Arithmetic Mean (UPGMA) tree to dictate merge order without sequence alignment overhead.
4. **Progressive Unification (`upgma_align.zig`)**: The $O(N^3)$ guide tree generation is explicitly decoupled from the dynamic programming profile generation. Phase 4 computes the topological node dependencies (DAG) instantly, then dispatches a horizontal lock-free thread pool. All CPU cores traverse the dependency DAG concurrently, merging nodes instantaneously once dependencies are satisfied, guaranteeing maximum hardware utilization.
5. **Topological Refinement & Exact Matching**: The resulting MSA topology is compared against the *Raw Persistence* using Wasserstein distance. To enforce pure biological exactness over heuristics, TiMSA utilizes the Hungarian Algorithm for Bipartite Matching to compute the Wasserstein optimal transport plan. A hierarchical progressive profile alignment mode is under development. In the current release, the engine handles up to 10,000 sequences via capped refinement (entropy gating + landmark mapping). For datasets exceeding 10,000 sequences, chunking is recommended.

## Engineering Strictness
As part of the BioZig philosophy, TiMSA is:
- **Fully Deterministic**: Zero stochastic elements (no RNGs or HMMs).
- **Bounded**: Execution scales strictly within the defined `memory_budget_bytes`, utilizing chunked dynamic programming (`SRFScheduler`). If a clinical monolithic dataset natively exceeds the threshold (e.g., a $10,000 \times 10,000$ dense scaling), the engine invokes a `DETERMINISTIC PANIC`. However, such constraints are structurally bypassed via Hierarchical Profiling, allowing unhindered progress for massive data.
- **Mathematical**: Implements explicit algebraic topology (Vietoris-Rips, Sparse Matrix Accumulator, Wasserstein distances) directly in Zig.

### Theoretical Complexity
| Algorithm | Time Complexity | Space Complexity | Deterministic? |
| :--- | :--- | :--- | :--- |
| **TiMSA (full)** | $O(N^3) + O(NL^2)$ | $O(N^2)$ | ✅ Yes |
| **TiMSA (scalable)** | $O(N \log N) + O(L^3)$ | $O(NL + L^2)$ | ✅ Yes |

## Multi-Core Scaling Architecture (Phase 5)

To achieve bounded execution on commodity hardware for massive datasets (e.g., $10,000$ sequences), TiMSA deploys a strict topological subsampling pipeline specifically in the Rigidity/Ablation mode:

1. **Phase 1: Deterministic Max-Min Landmarks**
   Instead of calculating persistent homology on all $N$ sequences, the pipeline selects a mathematically bounded subset of $L$ structural landmarks using a Max-Min distance heuristic. The topological footprint (`raw_pd`) is strictly derived from this bounded subgraph, avoiding an $O(N^3)$ lockup.

2. **Phase 2: Bounded Chunking**
   Sequences are assigned to clusters via topological nearest-neighbor projection. To prevent `SRFScheduler` arenas from colliding or exhausting memory, subclusters are chunked into strict sub-matrices. To prevent $O(N^3)$ explosion during UPGMA topological correction, the refinement engine caps intermediate evaluations at 200 sequences. This cap applies only to intermediate merges—the final alignment includes all sequences.

3. **Phase 3: Thread-Local Isolation**
   Chunk alignments are distributed across independent threads using Zig's `std.Thread.spawn` and lock-free atomic indices (`std.atomic.Value(usize)`). Each thread allocates its own `SRFScheduler` memory arena, absolutely guaranteeing zero allocator collisions and deterministic hardware isolation.

4. **Phase 4: Lock-Free Horizontal DAG UPGMA Merging**
   The merged subclusters are unified via a parallelized UPGMA guide tree. The topological tree is calculated in advance as a rigid Directed Acyclic Graph (DAG). A thread pool utilizes lock-free atomics (`std.atomic.Value(u8)` states) to aggressively hunt and claim sub-tree merges in parallel across all cores. When profile distances diverge significantly, the RefinementEngine isolates that specific tree branch and applies Wasserstein corrections to stabilize the global topology.

5. **Phase 5: Parallel Wasserstein Rigidity Ablation**
   For deep structural analytics, we measure the topological sensitivity of each column by removing it and computing the Wasserstein gradient ($\Delta W_p$).
   * **Optimization A:** Entropy Gating: We calculate Shannon entropy and ONLY ablate columns with strictly conserved structural identity ($H < 1.0$).
   * **Optimization B:** Landmark Injection: The ablation gradient is calculated strictly on the mapped indices of the Phase 1 landmarks, bounding the topology evaluation cost at $O(L^3)$ where $L$ is fixed (e.g., $L=500$). This prevents the $O(N^3)$ explosion for large $N$.
   * **Optimization C:** Embarrassingly Parallel: The column ablation loop is completely parallelized across all CPU cores.
