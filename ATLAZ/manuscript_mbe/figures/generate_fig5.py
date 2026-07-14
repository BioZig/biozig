import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
import matplotlib as mpl

# Set font
mpl.rcParams['font.family'] = 'sans-serif'
mpl.rcParams['font.sans-serif'] = ['Helvetica', 'Arial', 'DejaVu Sans']

# Okabe-Ito colors
okabe_ito = [
    "#E69F00", "#56B4E9", "#009E73", "#F0E442",
    "#0072B2", "#D55E00", "#CC79A7", "#000000"
]

def main():
    # Setup directory
    out_dir = "/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures/"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "figure_5_tss_math.svg")
    
    # Generate mock incidence matrix (nodes x hyperedges)
    np.random.seed(42)
    n_nodes = 15
    n_edges = 20
    
    # Original Matrix
    H_orig = np.random.choice([0, 1], size=(n_nodes, n_edges), p=[0.7, 0.3])
    
    # Make sure no empty rows or cols
    for i in range(n_nodes):
        if H_orig[i].sum() == 0:
            H_orig[i, np.random.randint(0, n_edges)] = 1
    for j in range(n_edges):
        if H_orig[:, j].sum() == 0:
            H_orig[np.random.randint(0, n_nodes), j] = 1
            
    # TSS Math via column ablation (ablate 4 columns)
    cols_to_ablate = [3, 7, 12, 18]
    H_ablated = H_orig.copy()
    H_ablated[:, cols_to_ablate] = 0
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 7))
    
    # Colormap for heatmaps
    cmap = ListedColormap(['#f0f0f0', okabe_ito[4]]) # Blue for present
    norm = BoundaryNorm([-.5, .5, 1.5], cmap.N)
    
    cmap2 = ListedColormap(['#f0f0f0', okabe_ito[5]]) # Vermilion for present
    
    # Plot Original Matrix
    ax = axes[0]
    im1 = ax.imshow(H_orig, cmap=cmap, norm=norm, aspect='auto')
    ax.set_title("Original Incidence Matrix $H$", fontsize=18, fontweight='bold', pad=15)
    ax.set_xlabel("Hyperedges (Simplices)", fontsize=16)
    ax.set_ylabel("Nodes (Vertices)", fontsize=16)
    ax.set_xticks(np.arange(n_edges))
    ax.set_yticks(np.arange(n_nodes))
    ax.set_xticklabels([f"e{i}" for i in range(n_edges)], rotation=90, fontsize=12)
    ax.set_yticklabels([f"v{i}" for i in range(n_nodes)], fontsize=12)
    
    # Highlight columns to ablate in original
    for col in cols_to_ablate:
        ax.axvspan(col - 0.5, col + 0.5, color=okabe_ito[1], alpha=0.3)
    
    # Plot Ablated Matrix
    ax2 = axes[1]
    
    im2 = ax2.imshow(H_ablated, cmap=cmap2, norm=norm, aspect='auto')
    ax2.set_title("TSS Math: Column Ablation $H'$", fontsize=18, fontweight='bold', pad=15)
    ax2.set_xlabel("Hyperedges (Simplices)", fontsize=16)
    ax2.set_ylabel("Nodes (Vertices)", fontsize=16)
    ax2.set_xticks(np.arange(n_edges))
    ax2.set_yticks(np.arange(n_nodes))
    ax2.set_xticklabels([f"e{i}" for i in range(n_edges)], rotation=90, fontsize=12)
    ax2.set_yticklabels([f"v{i}" for i in range(n_nodes)], fontsize=12)
    
    # Add cross marks for ablated columns
    for col in cols_to_ablate:
        ax2.axvspan(col - 0.5, col + 0.5, color='#dddddd', alpha=0.8)
        ax2.text(col, n_nodes/2, "X", color=okabe_ito[7], fontsize=24, 
                 ha='center', va='center', fontweight='bold')
    
    # Add major grid lines
    for ax in axes:
        ax.set_xticks(np.arange(-0.5, n_edges, 1), minor=True)
        ax.set_yticks(np.arange(-0.5, n_nodes, 1), minor=True)
        ax.grid(which='minor', color='w', linestyle='-', linewidth=2)
        ax.tick_params(which='minor', bottom=False, left=False)
        for spine in ax.spines.values():
            spine.set_visible(False)
    
    plt.tight_layout()
    plt.savefig(out_path, format="svg", dpi=600, bbox_inches="tight")
    print(f"Saved figure to {out_path}")

if __name__ == '__main__':
    main()
