# Structural Corpus Manifest

## Specification
The Structural Corpus provides deterministic 3D coordinate sets for atomic and molecular structure representation, modeling, and algorithm validation.

## Generation Rules
* **PDB Generation**: Deterministically models an alpha-helical backbone segment. Dihedral angles Phi/Psi are set to -60/-45 respectively. 
* **PQR Generation**: Same backbone segment with predefined partial charges from the AMBER forcefield and standard atomic radii.
* **Residues**: Generates a standard poly-Alanine chain.
* **Malformations**: Generates one file with missing occupancy to test parser resilience.

## Expected Outputs
* Valid PDB file representing a 10-residue poly-alanine alpha helix.
* Valid PQR file for the same helix.

## Reproducibility
Generated natively via `validation/corpus/structural.zig`.
