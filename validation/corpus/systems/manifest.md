# Systems Corpus Manifest

## Specification
The Systems Corpus generates deterministic graph-based models for biological pathways and metabolic systems.

## Generation Rules
* **SBML Generation**: A basic deterministic model of Glycolysis, covering the Hexokinase reaction (Glucose + ATP -> G6P + ADP).
* **GPML Generation**: A visual/pathway representation of the same Hexokinase reaction.
* **Nodes and Edges**: Deterministic weights and stoichiometry.

## Expected Outputs
* Valid SBML level 3 version 1 file.
* Valid GPML file containing nodes (DataNodes) and edges (Interactions).

## Reproducibility
Generated natively via `validation/corpus/systems.zig`.
