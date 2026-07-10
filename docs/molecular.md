# Molecular Layer

## Purpose
The Molecular layer provides the foundational sequence representations for biology. It implements the "Biology Is Not Text" philosophy by encoding nucleotides and amino acids into highly compact binary formats rather than ASCII strings, maximizing memory density for genomic-scale datasets.

## Directory Layout
- `sequence/`: Generic biological sequence wrappers and alignments.
- `dna/`: 2-bit packed DNA arrays and reverse-complement operations.
- `rna/`: Transcript sequence representations.
- `codon/`: Triplet-to-amino-acid translation tables.
- `protein/`: Amino acid encodings.
- `peptide/`: Short peptide sequence fragments.
- `transcript/`: Gene-to-transcript mapping structures.
- `variant/`: SNPs and Indels representation structures.

## Public Types
- `dna.DnaSequence`, `dna.PackedDna`
- `rna.RnaSequence`
- `protein.ProteinSequence`
- `codon.TranslationTable`
- `variant.Variant`

## Public APIs
- `dna.DnaSequence.reverseComplement()`
- `codon.TranslationTable.translate()`
- `protein.ProteinSequence.getMolecularWeight()`

## Serialization Format
Sequence blocks are binary serialized using their underlying 2-bit or 4-bit packed byte arrays, accompanied by a 64-bit integer representing the true sequence length to account for bit-padding at the end of the byte array.

## Memory Model
Sequences manage their internal byte arrays using the explicit `Allocator` passed during initialization. Packed representations reduce standard DNA memory requirements by exactly 75% compared to ASCII equivalents, allowing entire human chromosomes to fit easily in CPU L3 cache.

## Determinism Guarantees
- Translation maps handle ambiguous codons deterministically (e.g., assigning 'X' consistently).
- Reverse-complementation operates in-place deterministically using static lookup tables.

## Example Usage
```zig
const std = @import("std");
const mol = @import("biozig").molecular;

var dna_seq = try mol.dna.DnaSequence.init(allocator, "ATCGATCG");
defer dna_seq.deinit();

try dna_seq.reverseComplement();
// dna_seq now conceptually represents "CGATCGAT"
```

## Limitations
- Highly degenerated DNA sequences with large numbers of `N`s may lose their performance advantages if forced into strict 2-bit encodings; ambiguity-aware 4-bit fallbacks are required.
