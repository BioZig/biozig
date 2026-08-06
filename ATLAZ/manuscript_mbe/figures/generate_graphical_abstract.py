import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import matplotlib.lines as mlines
from matplotlib.gridspec import GridSpec
import networkx as nx

# --- Elite Journal Aesthetics (Okabe-Ito & Tufte) ---
plt.style.use('default')

# Okabe-Ito Palette
okabe = {
    'black': '#000000',
    'orange': '#E69F00',
    'sky': '#56B4E9',
    'green': '#009E73',
    'yellow': '#F0E442',
    'blue': '#0072B2',
    'vermillion': '#D55E00',
    'purple': '#CC79A7',
    'gray': '#999999'
}

plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Helvetica', 'Arial', 'sans-serif'],
    'font.size': 9,
    'axes.linewidth': 1,
    'axes.edgecolor': okabe['black'],
    'xtick.color': okabe['black'],
    'ytick.color': okabe['black'],
    'text.color': okabe['black'],
    'axes.spines.top': False,
    'axes.spines.right': False
})

out_dir = "/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures"
os.makedirs(out_dir, exist_ok=True)

fig = plt.figure(figsize=(10, 4))
gs = GridSpec(1, 2, width_ratios=[1, 1], wspace=0.1)

# --- Panel A: Traditional Phylogeny ---
ax1 = fig.add_subplot(gs[0])
ax1.axis('off')
ax1.set_title("a  Standard Phylogeny\n(Bifurcation Constraint)", weight='bold', loc='left', fontsize=10, pad=15)

# Plot a simple bifurcating tree
ax1.plot([0.1, 0.3], [0.5, 0.5], color=okabe['black'], lw=2)
ax1.plot([0.3, 0.3], [0.2, 0.8], color=okabe['black'], lw=2)
ax1.plot([0.3, 0.5], [0.8, 0.8], color=okabe['black'], lw=2)
ax1.plot([0.3, 0.5], [0.2, 0.2], color=okabe['black'], lw=2)
ax1.plot([0.5, 0.5], [0.1, 0.3], color=okabe['black'], lw=2)
ax1.plot([0.5, 0.7], [0.3, 0.3], color=okabe['black'], lw=2)
ax1.plot([0.5, 0.7], [0.1, 0.1], color=okabe['black'], lw=2)

# Show the broken horizontal gene transfer
ax1.plot([0.7, 0.7], [0.8, 0.3], color=okabe['vermillion'], lw=2, ls='--')
ax1.scatter([0.7], [0.55], color=okabe['vermillion'], marker='X', s=150, zorder=5)
ax1.text(0.75, 0.55, "Reticulation\nFailed", color=okabe['vermillion'], fontsize=9, va='center')


# --- Panel B: ATLAZ Topology ---
ax2 = fig.add_subplot(gs[1])
ax2.axis('off')
ax2.set_title("b  ATLAZ Geometric Engine\n(Topological Resolution)", weight='bold', loc='left', fontsize=10, pad=15)

# Plot a simplicial complex showing H1 preservation
G = nx.Graph()
ring = [1, 2, 3, 4, 5]
for i in range(len(ring)):
    G.add_edge(ring[i], ring[(i+1)%len(ring)])
G.add_edges_from([(1, 6), (2, 7), (4, 8)])

pos = nx.spring_layout(G, seed=42)
nx.draw_networkx_edges(G, pos, edge_color=okabe['gray'], width=1.5, ax=ax2)
nx.draw_networkx_nodes(G, pos, node_color=okabe['sky'], edgecolors=okabe['black'], node_size=200, ax=ax2)

# Highlight H1 loop
loop_edges = [(ring[i], ring[(i+1)%len(ring)]) for i in range(len(ring))]
nx.draw_networkx_edges(G, pos, edgelist=loop_edges, width=3, edge_color=okabe['green'], ax=ax2)

# Annotate
ax2.text(0, 0, "$H_1$ Loop\n(Recombination\nPreserved)", color=okabe['green'], ha='center', va='center', weight='bold', fontsize=9, bbox=dict(facecolor='white', edgecolor='none', alpha=0.8, pad=0.5))

plt.savefig(os.path.join(out_dir, "graphical_abstract.svg"), format='svg', bbox_inches='tight', dpi=600)
plt.close()

print("Graphical Abstract Generated.")
