# Molecular Corpus Manifest

## Specification
The Molecular Corpus provides deterministic datasets for sequence and variation parsing and algorithmic validation.

## Generation Rules
* **Seed**: `42` (DefaultPrng)
* **DNA Generation**: Bases are sampled uniformly from `[A, C, G, T]`.
* **RNA Generation**: Bases are sampled uniformly from `[A, C, G, U]`.
* **Protein Generation**: Amino acids are sampled uniformly from the 20 standard amino acids.
* **Variant Generation**: SNPs are placed deterministically at indices `i * 10` with transitions (A <-> G, C <-> T).

## Expected Outputs
* Valid FASTA for DNA, RNA, and Protein.
* Valid FASTQ with phred+33 quality scores ranging between 20-40.
* Valid VCF with 3 samples, featuring deterministic variants.

## Reproducibility
Generated natively via `validation/corpus/molecular.zig`. No external dependencies.
