# Ingestion

The `ingestion` module provides parsers for standard biological file formats. All parsers are designed to operate using bounded memory or memory-mapped files (mmap) to avoid heap allocation overhead.

## Genomic Parsers
- **FASTA:** Reference sequence parsing.
- **FASTQ:** Sequencing read parsing with quality score extraction.
- **SAM / BAM / CRAM:** Alignment formats.
- **VCF:** Variant Calling Format.

## Structural Parsers
- **PDB:** Protein Data Bank atom records.
- **mmCIF:** Macromolecular Crystallographic Information File.

## Memory Management
The `MMapReader` struct maps large files directly into memory. Parsers operate on these zero-copy memory slices, returning views into the original mapped file rather than allocating new strings.
