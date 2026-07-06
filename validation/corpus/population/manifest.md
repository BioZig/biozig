# Population Corpus Manifest

## Specification
The Population Corpus generates deterministic datasets for population genomics, including variants, genotypes, haplotypes, and linkage disequilibrium (LD) matrices.

## Generation Rules
* **VCF/BCF**: Re-uses the molecular deterministic VCF generation.

## Expected Outputs
* Valid `.vcf` and `.bcf` representations.

## Reproducibility
Generated natively via `validation/corpus/population.zig`.
