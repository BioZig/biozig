import os
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
from matplotlib.patches import Polygon
import warnings
warnings.filterwarnings("ignore")

os.makedirs('/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures/', exist_ok=True)

# Try setting Helvetica, fallback to sans-serif if not found
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Helvetica', 'Arial', 'sans-serif']
plt.rcParams['svg.fonttype'] = 'none'

fig, ax = plt.subplots(figsize=(16, 12))
ax.axis('off')

# Data layers setup
layers = ["Fasta", "mmap", "L1 Cache", "Arena", "Vietoris-Rips", "GF(2)"]
# Okabe-Ito colors
colors = ["#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00"]

pos = {}
G = nx.DiGraph()
np.random.seed(42)

nodes_per_layer = 7

# Generate main workflow nodes
for i, layer in enumerate(layers):
    for j in range(nodes_per_layer):
        node_id = f"{layer}_{j}"
        G.add_node(node_id, layer=i)
        
        # Isometric-like positioning
        # Space out layers in x, stagger y
        x_iso = i * 4.5 - j * 0.6
        y_iso = j * 1.2 + i * 1.8
        pos[node_id] = (x_iso, y_iso)

# Draw Z-planes (polygons behind nodes) for Data-Ink max (clean shaded regions)
for i in range(len(layers)):
    x_coords = [pos[f"{layers[i]}_{j}"][0] for j in range(nodes_per_layer)]
    y_coords = [pos[f"{layers[i]}_{j}"][1] for j in range(nodes_per_layer)]
    
    pad_x = 1.2
    pad_y = 1.2
    poly_pts = [
        (x_coords[0] + pad_x, y_coords[0] - pad_y),
        (x_coords[-1] + pad_x, y_coords[-1] - pad_y),
        (x_coords[-1] - pad_x, y_coords[-1] + pad_y),
        (x_coords[0] - pad_x, y_coords[0] + pad_y)
    ]
    # Transparent planes
    poly = Polygon(poly_pts, closed=True, facecolor=colors[i], alpha=0.15, edgecolor=colors[i], lw=2, zorder=0)
    ax.add_patch(poly)
    
    # Layer Label
    ax.text(x_coords[0] + pad_x, y_coords[0] - pad_y - 0.5, layers[i], 
            color=colors[i], fontsize=18, fontweight='bold', ha='center')

# Connect layers with decaying alpha edges
for i in range(len(layers)-1):
    for j in range(nodes_per_layer):
        targets = np.random.choice(range(nodes_per_layer), size=np.random.randint(2, 4), replace=False)
        for k in targets:
            G.add_edge(f"{layers[i]}_{j}", f"{layers[i+1]}_{k}")

for u, v in G.edges():
    layer_u = G.nodes[u]['layer']
    alpha = max(0.15, 1.0 - (layer_u * 0.16))
    nx.draw_networkx_edges(G, pos, edgelist=[(u,v)], ax=ax, alpha=alpha, 
                           edge_color=colors[layer_u], arrows=True, arrowsize=15, 
                           connectionstyle='arc3,rad=0.15')

# Draw nodes
for i in range(len(layers)):
    nodelist = [n for n in G.nodes if G.nodes[n]['layer'] == i]
    nx.draw_networkx_nodes(G, pos, nodelist=nodelist, ax=ax, node_color=colors[i], 
                           node_size=200, edgecolors='white', linewidths=1.5)

# --- Legacy Boundary (Failing) ---
legacy_color = "#CC79A7"  # Okabe-Ito reddish purple
legacy_nodes = []
for j in range(9):
    node_id = f"Legacy_{j}"
    G.add_node(node_id, layer=-1)
    # Positioned underneath as a disjoint/failing base
    x_iso = -1.0 + j * 3.0
    y_iso = -3.5 + np.random.normal(0, 0.4)
    pos[node_id] = (x_iso, y_iso)
    legacy_nodes.append(node_id)

# Draw Legacy nodes
nx.draw_networkx_nodes(G, pos, nodelist=legacy_nodes, ax=ax, node_color="white", 
                       node_size=300, edgecolors=legacy_color, linewidths=2.0, node_shape='s')

# Connect legacy nodes with failing dashed line
for i in range(len(legacy_nodes)-1):
    ax.plot([pos[legacy_nodes[i]][0], pos[legacy_nodes[i+1]][0]], 
            [pos[legacy_nodes[i]][1], pos[legacy_nodes[i+1]][1]], 
            color=legacy_color, linestyle='--', lw=3, alpha=0.6, zorder=2)

# Add "cracks" to symbolize failing boundary
for node in legacy_nodes:
    if np.random.rand() > 0.4:
        px, py = pos[node]
        ax.plot([px-0.4, px+0.4], [py-0.4, py+0.4], color='red', lw=2, zorder=4)
        ax.plot([px+0.4, px-0.4], [py-0.4, py+0.4], color='red', lw=2, zorder=4)

ax.text(pos[legacy_nodes[4]][0], pos[legacy_nodes[4]][1] - 2.0, 
        "Legacy Python/R memory (Failing Boundary)", 
        color=legacy_color, fontsize=18, fontweight='bold', ha='center')

# Final save
out_path = '/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures/figure_1_architecture.svg'
plt.savefig(out_path, format='svg', dpi=600, bbox_inches='tight')
print(f"Successfully generated {out_path}")
