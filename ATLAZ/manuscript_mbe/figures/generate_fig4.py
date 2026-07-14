import matplotlib
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import matplotlib.path as mpath
import numpy as np
import networkx as nx
import os

# Set font to Helvetica
matplotlib.rcParams['font.sans-serif'] = "Helvetica"
matplotlib.rcParams['font.family'] = "sans-serif"

# Okabe-Ito colors
okabe_ito = ["#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7"]

# Generate data for a manifold with a hole (H1 hole)
np.random.seed(42)
n_points = 300
theta = np.random.uniform(0, 2*np.pi, n_points)
r = np.random.normal(5, 1, n_points)

x = r * np.cos(theta) + np.random.normal(0, 0.5, n_points)
y = r * np.sin(theta) + np.random.normal(0, 0.5, n_points)

# Create a graph
G = nx.Graph()
for i in range(n_points):
    G.add_node(i, pos=(x[i], y[i]))

# Add edges based on proximity (k-nearest neighbors-ish)
from scipy.spatial import distance_matrix
dist = distance_matrix(np.column_stack((x, y)), np.column_stack((x, y)))
for i in range(n_points):
    # Connect to closest 4 points
    closest = np.argsort(dist[i])[1:5]
    for j in closest:
        if not G.has_edge(i, j):
            G.add_edge(i, j)

# Additional random edges to create "reticulation" effect across the hole, but keep them sparse
for _ in range(30):
    i = np.random.randint(0, n_points)
    j = np.random.randint(0, n_points)
    if dist[i, j] > 5 and not G.has_edge(i, j):
        G.add_edge(i, j)

# Color points by angle (UMAP-style gradient)
colors = [okabe_ito[int((t / (2*np.pi)) * 6) % 6 + 1] for t in theta]
sizes = np.random.uniform(10, 50, n_points)

fig, ax = plt.subplots(figsize=(10, 8))

# Draw Bezier curves for edges
for u, v in G.edges():
    x1, y1 = G.nodes[u]['pos']
    x2, y2 = G.nodes[v]['pos']
    
    if dist[u, v] > 5:
        # Cross-hole reticulation: curvy
        # control point
        cx, cy = (0, 0) # Pull towards center
        color = okabe_ito[7] # #CC79A7
        alpha = 0.15
        lw = 1.0
    else:
        # Local edges: slightly curved
        cx, cy = (x1+x2)/2 + np.random.normal(0, 0.5), (y1+y2)/2 + np.random.normal(0, 0.5)
        color = "#888888"
        alpha = 0.2
        lw = 0.5
        
    Path = mpath.Path
    pp1 = patches.PathPatch(
        Path([(x1, y1), (cx, cy), (x2, y2)], [Path.MOVETO, Path.CURVE3, Path.CURVE3]),
        fc="none", transform=ax.transData, edgecolor=color, alpha=alpha, linewidth=lw
    )
    ax.add_patch(pp1)

# Plot nodes
ax.scatter(x, y, c=colors, s=sizes, alpha=0.8, edgecolors='white', linewidths=0.5, zorder=5)

ax.set_aspect('equal')
ax.axis('off')

plt.tight_layout()

out_path = "/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures/figure_4_3d_reticulation.svg"
plt.savefig(out_path, format="svg", dpi=600, bbox_inches="tight")
print(f"Saved to {out_path}")
