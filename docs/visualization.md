# Visualization Layer

## Purpose
The Visualization layer provides deterministic generation of scientific assets. It does not interface directly with monitors or GPUs; instead, it outputs exact vector strings (like SVG geometries) that are mathematically verifiable.

## Directory Layout
- `sequence/`: Sequence alignment and motif graphics.
- `structure/`: 2D representations of 3D topologies.
- `network/`: Node-edge graph layouts.
- `omics/`: Volcano plots, heatmaps, and Manhattan plots.
- `phylogeny/`: Phylogenetic tree graphics.
- `dashboards/`: Composed multi-panel layout structures.
- `publication/`: Core publication primitives (`Figure`, `Table`, `Reference`, `Panel`).

## Public Types
- `publication.Figure`
- `publication.Table`
- `publication.Reference`
- `publication.Panel`
- `publication.Caption`

## Public APIs
- `publication.Figure.init()`
- `publication.Table.init()`
- `omics.buildVolcanoPlot()`
- `network.buildForceDirectedLayout()`

## Serialization Format
The Visualization layer natively produces text-based vector markup (e.g., SVG). Serialization of the abstract components themselves writes down coordinate bounds, styling parameters, and associated captions.

## Memory Model
Visual elements are primarily string slices (`[]const u8`). The components hold references to these slices to avoid duplicating massive HTML/SVG geometry strings.

## Determinism Guarantees
- Layout algorithms (e.g., force-directed graph spacing) must be seeded deterministically to ensure the resulting coordinates are bit-exact on every run.
- Colors and strokes are bound to fixed hexadecimal codes.

## Example Usage
```zig
const pub_mod = @import("biozig").visualization.publication;

const p1 = pub_mod.Panel.init("A", "<circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"blue\"/>");
const panels = [_]pub_mod.Panel{ p1 };

const fig = pub_mod.Figure.init(
    1,
    "Figure 1",
    pub_mod.Caption.init("My visual geometry."),
    &panels,
    &[_]pub_mod.Reference{},
);
```

## Limitations
- No native GPU rasterization or OpenGL rendering is supported.
- Animations and interactive javascript events are excluded to preserve static reproducibility.
