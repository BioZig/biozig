# Systems Layer

## Purpose
The Systems layer models biological relationships and interactions. It rejects generic graph-theory concepts in favor of strictly semantic, biology-first graph structures designed for specific domains like metabolic pathways, gene regulation, signaling cascades, and standardized ontologies.

## Directory Layout
- `network/`: Core biological network primitives (`Node`, `Edge`, `Network`).
- `pathway/`: Pathway representations and membership tracking.
- `regulation/`: Directed Gene Regulatory Networks (GRNs) with `Activation` and `Repression` edges.
- `signaling/`: Signaling cascades tracking events like `Phosphorylation` and `Binding`.
- `metabolism/`: Bipartite-like graphs mapping `Metabolites` to `Reactions` with stoichiometries.
- `ontology/`: Directed Acyclic Graphs (DAGs) representing standard ontologies (e.g., Gene Ontology).
- `knowledgegraph/`: Heterogeneous, typed biological knowledge graphs (e.g., mapping Genes to Diseases).

## Public Types
- `network.Network`
- `pathway.Pathway`
- `regulation.RegulatoryGraph`, `regulation.RegulationType`
- `signaling.SignalingNetwork`, `signaling.SignalingEvent`
- `metabolism.MetabolicNetwork`, `metabolism.Reaction`
- `ontology.Ontology`
- `knowledgegraph.KnowledgeGraph`, `knowledgegraph.EntityType`, `knowledgegraph.RelationshipType`

## Public APIs
- `network.Network.getInDegree()`
- `pathway.Pathway.hasMember()`
- `regulation.RegulatoryGraph.getTargets()`
- `signaling.SignalingNetwork.getDownstreamEvents()`
- `metabolism.MetabolicNetwork.getReactionsProducing()`
- `ontology.Ontology.isValidDAG()`
- `knowledgegraph.KnowledgeGraph.getRelationships()`

## Serialization Format
All system graphs serialize their node counts and contiguous blocks of structured edges. Dictionaries mapping string IDs to integer indices are rebuilt upon deserialization, ensuring binary payloads only store the essential topology (e.g., adjacency lists are reconstructed).

## Memory Model
Systems layer graphs heavily utilize integer indices (`usize`) for relationships rather than direct pointer links. This `ArenaAllocator`-friendly design eliminates fragmented pointer chasing, keeping the topology tightly packed in `std.ArrayList` instances for high cache hit rates during traversals.

## Determinism Guarantees
- Adjacency entries strictly preserve insertion order. 
- Iterative traversals (e.g., ontology `getAncestors`) yield results based on deterministic HashMaps without pseudo-random hash collisions dictating the path.
- The `isValidDAG` cycle detection operates on a strict BFS iteration order.

## Example Usage
```zig
const std = @import("std");
const sys = @import("biozig").systems.regulation;

var grn = sys.RegulatoryGraph.init(allocator);
defer grn.deinit();

try grn.addInteraction("TP53", "CDKN1A", .Activation, 0.95);
const targets = grn.getTargets("TP53");

std.debug.print("TP53 regulates {d} targets.\n", .{targets.?.len});
```

## Limitations
- Pathway logic handles flat membership only; nested sub-pathways are not recursively expanded.
- Graph analytics (like PageRank or community detection) are explicitly excluded to maintain layer purity; export to an analytics framework is required for those calculations.
