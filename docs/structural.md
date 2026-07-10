# Structural Layer

## Purpose
The Structural layer models the 3D geometry of biological macromolecules. It focuses on representing Cartesian coordinates, connectivity, and spatial properties required for structural bioinformatics without embedding dynamic physics simulations.

## Directory Layout
- `atom/`: 3D Cartesian coordinates and elemental properties.
- `residue/`: Collections of atoms forming specific amino acids or nucleotides.
- `chain/`: Continuous linear sequences of residues (e.g., protein subunits).
- `model/`: Complete 3D structures composed of multiple chains.
- `assembly/`: Quaternary biological assemblies.
- `geometry/`: Distance, angle, and dihedral calculations.
- `contacts/`: Spatial contact maps and interaction networks.
- `surfaces/`: Accessible surface area (SASA) representations.
- `pockets/`: Structural cleft and binding site coordinate maps.
- `docking/`: Receptor-ligand pose representations.

## Public Types
- `atom.Atom`
- `residue.Residue`
- `chain.Chain`
- `model.StructureModel`
- `geometry.Vec3`
- `contacts.ContactMap`

## Public APIs
- `geometry.Vec3.distance()`
- `geometry.calculateDihedral()`
- `contacts.ContactMap.build()`
- `chain.Chain.getResidue()`

## Serialization Format
Atoms serialize their Cartesian `x`, `y`, `z` coordinates as IEEE-754 `f64` floats along with elemental identifier strings. Contact maps serialize their sparse topologies to minimize storage size.

## Memory Model
Structures represent data hierarchically. A `StructureModel` owns `Chain` instances, which own `Residue` instances, which own `Atom` instances. They rely on contiguous unmanaged arrays (`std.ArrayListUnmanaged`) for high locality during geometric coordinate scans.

## Determinism Guarantees
- Distance matrices and dihedral angle calculations use deterministic, platform-agnostic float mathematics.
- Bounding box calculations are sorted deterministically before returning spatial limits.

## Example Usage
```zig
const std = @import("std");
const struct_mod = @import("biozig").structural;

const a1 = struct_mod.atom.Atom{ .x = 0.0, .y = 0.0, .z = 0.0, .element = "C" };
const a2 = struct_mod.atom.Atom{ .x = 1.0, .y = 0.0, .z = 0.0, .element = "O" };

const dist = struct_mod.geometry.distance(a1, a2);
std.debug.print("Bond length: {d} Angstroms\n", .{dist});
```

## Limitations
- Does not implement real-time molecular dynamics (MD) integrators or force fields.
- PDB/mmCIF string parsing is explicitly isolated from the structural primitives.
