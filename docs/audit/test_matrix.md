# Testing Audit Matrix

| Category | Status |
| :--- | :--- |
| **Missing unit tests** | The `ingestion` parsers have NO unit tests. Various algorithms (Kabsch, Contact Maps, Pocket Statistics, Surface Statistics) lack explicit testing. |
| **Missing edge-case tests** | Null sequences, completely unconnected graphs, highly unstructured topologies, negative coordinates in structure parsing. |
| **Missing malformed-input tests** | No tests exist verifying how parsers gracefully fail when given corrupted or malformed data (FASTA without headers, truncated PDBs, etc.). |
| **Missing serialization tests** | Serialization testing is absent across the parser logic (no roundtrip testing to ensure parsed data serializes back to standard output properly). |
| **Missing memory tests** | No dedicated memory leak bounds checking tests for complex allocations like phylogenetic trees or large sparse matrices. |
| **Missing stress tests** | No stress tests or benchmark validations exist for whole-chromosome FASTA/VCF loading. |
