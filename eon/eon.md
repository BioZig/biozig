**EON (Evolutionary Overwatch Network).** 
EON is faster, deterministic, and requires no training data or known resistance signatures. It *scans everything*.

## Updated Methodology 

1. **Sequence Input**: Multiple Sequence Alignment (MSA) or raw sequences (TiMSA aligns them)
2. **Rigidity Calculation (TiMSA)**: Compute ΔW per residue. This is the topological "stiffness" score.
3. **Node Classification (fuse_network)**: Translate ΔW into formal taxonomy:
   - **DEAD**: Rigid anchors (ΔW high). Mutating them collapses the manifold → lethal.
   - **BAIL**: Flexible nodes (ΔW low). Mutating them is structurally permissive → viable.
4. **Communication Network (fuse_network)**: Extract allosteric communication edges between BAIL nodes (mutual information + geometric coupling).
5. **Hub Identification**: Identify BAIL nodes with high connectivity (hubs). These are allosteric control centers — mutating them has global effects.
6. **Resistance Risk Scoring**:
   - **CRITICAL**: BAIL hub with high connectivity + matches known resistance DB
   - **HIGH**: BAIL hub (connectivity > threshold)
   - **MEDIUM**: BAIL node (connectivity < threshold)
   - **ZERO**: DEAD node (ideal drug target; cannot mutate)
7. **Clinical Cross-Reference (Optional)**: Validate flagged BAIL hubs against CARD, MEGARes, or NCBI AMRFinder.
8. **Report**: Output JSON + human-readable AMR risk profile.


## Structural Hierarchy : 

```
BioZig/
├── TiMSA/                          # Core alignment + rigidity
│   ├── rigidity.zig               # ΔW computation
│   └── (existing modules)
│
├── fuse_network.cpp                # Taxonomy translation + communication network
│
├── EON/                            # NEW: AMR Risk Prediction
│   ├── src/
│   │   ├── risk.zig               # BAIL/DEAD + network → risk scoring
│   │   ├── hubs.zig               # Hub identification (connectivity ranking)
│   │   ├── crossref.zig           # Cross-reference against CARD/MEGARes
│   │   ├── report.zig             # Output formatter (JSON + human-readable)
│   │   └── main.zig               # CLI entry point (`biozig eon`)
│   ├── tests/
│   │   ├── test_risk.zig
│   │   ├── test_hubs.zig
│   │   └── test_crossref.zig
│   └── benchmarks/
│       └── benchmark_amr.zig
│
└── core/                           # Shared infrastructure
    ├── srf.zig                    # SRF memory scheduler
    ├── sasa.zig                   # (Optional: structure-based pocket detection)
    └── (existing modules)
```



## CLI Interface

```bash
# Basic run
biozig eon -i sequences.fasta -o eon_report.json

# With cross-reference to known resistance DBs
biozig eon -i sequences.fasta --crossref card,megares -o eon_report.json

# Verbose output with network visualization
biozig eon -i sequences.fasta --verbose --visualize -o eon_report.json
```


## EON Risk Categories (clinically fatal for humans to clinicaly fatal to the microbes)

| Category | Icon | Interpretation |
| :--- | :--- | :--- |
| **CRITICAL** | 🔴 | BAIL hub + matches known resistance | High confidence resistance risk |
| **HIGH** | 🟠 | BAIL hub | Likely resistance risk |
| **MEDIUM** | 🟡 | BAIL node | Possible resistance risk |
| **ZERO** | 🟢 | DEAD node | Ideal drug target (cannot mutate) |



## Key Metrics (Retrospective Validation)

| Metric | Expected | Why |
| :--- | :--- | :--- |
| **Recall** | >80% of known resistance mutations flagged | EON captures known resistance |
| **Precision** | >70% of flagged nodes are actual resistance | EON doesn't overpredict |
| **Novel predictions** | >50 novel resistance candidates | EON predicts unknown resistance |


## The Bottom Line

| Aspect | Status |
| :--- | :--- |
| **Name** | EON (Evolutionary Overwatch Network) |
| **Input** | MSA only (structure-free) |
| **Output** | AMR risk profile (JSON + human-readable) |
| **Key novelty** | BAIL hubs as allosteric control centers |
| **Validation** | Retrospective against CARD/MEGARes |
| **Competition** | NCBI AMRFinder (heuristic, DB-dependent) vs EON (topological, deterministic) |
