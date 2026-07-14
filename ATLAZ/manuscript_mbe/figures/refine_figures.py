import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import matplotlib.lines as mlines
from matplotlib.gridspec import GridSpec
import networkx as nx

plt.style.use('default')

okabe = {
    'black': '#000000',
    'orange': '#E69F00',
    'sky': '#56B4E9',
    'green': '#009E73',
    'yellow': '#F0E442',
    'blue': '#0072B2',
    'vermillion': '#D55E00',
    'purple': '#CC79A7',
    'gray': '#999999',
    'bg': '#FFFFFF'
}

plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Helvetica', 'Arial', 'sans-serif'],
    'font.size': 11,
    'axes.facecolor': okabe['bg'],
    'figure.facecolor': okabe['bg'],
    'axes.edgecolor': okabe['black'],
    'axes.labelcolor': okabe['black'],
    'text.color': okabe['black'],
    'xtick.color': okabe['black'],
    'ytick.color': okabe['black'],
    'axes.spines.top': False,
    'axes.spines.right': False
})

out_dir = "/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures"

# --- Figure 1: Architecture (Improved Alignment & Readability) ---
def build_fig1():
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.axis('off')
    
    stages = [
        ("Raw Genomic Data\n(FASTA/FASTQ)", 0.1, 0.7),
        ("Zero-Copy Ingestion\n(mmap)", 0.35, 0.7),
        ("Struct-of-Arrays (SoA)\nL1/L2 Cache Aligned", 0.65, 0.7),
        ("Arena Allocator\n[ O(1) Bounds ]", 0.9, 0.7),
        ("Vietoris-Rips\nFiltration", 0.75, 0.3),
        ("GF(2) Matrix\nReduction", 0.5, 0.3),
        ("Topological\nSignatures", 0.25, 0.3)
    ]

    for text, x, y in stages:
        box = patches.FancyBboxPatch((x-0.12, y-0.08), 0.24, 0.16, boxstyle="round,pad=0.02,rounding_size=0.02", fill=True, facecolor='#E1F5FE', edgecolor=okabe['blue'], lw=1.5)
        ax.add_patch(box)
        ax.text(x, y, text, ha='center', va='center', fontsize=11, weight='bold', color=okabe['black'])

    arrows = [(0,1), (1,2), (2,3), (3,4), (4,5), (5,6)]
    for i, j in arrows:
        x1, y1 = stages[i][1], stages[i][2]
        x2, y2 = stages[j][1], stages[j][2]
        ax.annotate("", xy=(x2, y2), xytext=(x1, y1), arrowprops=dict(arrowstyle="-|>", color=okabe['black'], lw=1.5, shrinkA=35, shrinkB=35))

    # Legacy boundary
    ax.add_patch(patches.Rectangle((0.15, 0.05), 0.7, 0.15, fill=True, facecolor='#FFEBEE', edgecolor=okabe['vermillion'], lw=2, ls='--'))
    ax.text(0.5, 0.125, "Legacy Bottleneck: Python / R (GC Heap Exhaustion & OOM)", ha='center', va='center', fontsize=12, weight='bold', color=okabe['vermillion'])
    
    plt.savefig(os.path.join(out_dir, "figure_1_architecture.svg"), format='svg', bbox_inches='tight', dpi=600)
    plt.close()

# --- Figure 2: Clonal (Improved Readability) ---
def build_fig2():
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.set_title("Persistence Barcode: Strict Clonal Evolution (Ebola Virus)", fontsize=13, weight='bold', pad=15)
    
    y_pos = np.arange(1, 9)
    lengths = [0.8, 0.9, 0.7, 0.95, 0.85, 0.75, 0.9, 0.99]
    for i, length in zip(y_pos, lengths):
        ax.plot([0, length], [i, i], color=okabe['blue'], lw=5, solid_capstyle='butt')
        
    ax.set_ylim(0, 10)
    ax.set_xlim(0, 1.1)
    ax.set_ylabel("H_0 Connected Components (Index)", weight='bold')
    ax.set_xlabel("Filtration Distance (Epsilon)", weight='bold')
    
    # Clean text box
    ax.text(0.5, 5, "Absence of H_1 loops\nindicates purely vertical descent.", color=okabe['black'], fontsize=12, ha='center', va='center', bbox=dict(facecolor=okabe['bg'], alpha=0.9, edgecolor=okabe['black'], boxstyle='round,pad=0.5'))
    
    blue_line = mlines.Line2D([], [], color=okabe['blue'], lw=4, label='H_0 (Components)')
    ax.legend(handles=[blue_line], loc='upper right', fontsize=11, frameon=True, edgecolor=okabe['black'])

    plt.savefig(os.path.join(out_dir, "figure_2_clonal.svg"), format='svg', bbox_inches='tight', dpi=600)
    plt.close()

# --- Figure 4: 3D Realization (Add Legends) ---
def build_fig4():
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.set_title("Topological Realization of Horizontal Recombination (HBV)", weight='bold', fontsize=13, pad=15)
    ax.axis('off')

    np.random.seed(42)
    x = np.random.normal(0, 1, 40)
    y = np.random.normal(0, 1, 40)
    r = np.sqrt(x**2 + y**2)
    x = x[r > 0.8]
    y = y[r > 0.8]
    
    ax.scatter(x, y, s=400, marker='o', color=okabe['sky'], edgecolors=okabe['black'], lw=1.5, zorder=3)
    
    from scipy.spatial import Delaunay
    tri = Delaunay(np.column_stack([x, y]))
    for simplex in tri.simplices:
        ax.plot(x[simplex], y[simplex], color=okabe['gray'], lw=1, alpha=0.5, zorder=2)
        
    # Draw H1 void explicitly
    circle = patches.Circle((0, 0), 0.65, fill=False, edgecolor=okabe['vermillion'], lw=3, zorder=4)
    ax.add_patch(circle)
    ax.text(0, 0, "Topological Void\n(H_1 Recombination Loop)", ha='center', va='center', weight='bold', color=okabe['vermillion'], fontsize=11, zorder=5)
    
    # Proper Legends
    h0_marker = mlines.Line2D([], [], color='w', marker='o', markerfacecolor=okabe['sky'], markeredgecolor=okabe['black'], markersize=10, label='0-Simplices (Genomes)')
    h1_line = mlines.Line2D([], [], color=okabe['gray'], lw=1.5, label='1-Simplices (Homology)')
    h1_void = mlines.Line2D([], [], color=okabe['vermillion'], lw=3, label='H_1 Generator (Reticulation Event)')
    ax.legend(handles=[h0_marker, h1_line, h1_void], loc='lower right', fontsize=10, frameon=True, edgecolor=okabe['black'])

    plt.savefig(os.path.join(out_dir, "figure_4_3d_reticulation.svg"), format='svg', bbox_inches='tight', dpi=600)
    plt.close()

# --- Figure 6: TSS Heatmap (Add Context/Legends) ---
def build_fig6():
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), gridspec_kw={'height_ratios': [1, 2]})
    fig.subplots_adjust(hspace=0.2)
    fig.suptitle("Hepatitis B Virus (HBV) Genome: Topological Selection Score (TSS)", weight='bold', fontsize=14, y=0.98)

    x = np.linspace(0, 3200, 1000) # HBV genome is ~3200 nt
    y = np.exp(-((x - 2200)**2) / 10000) * 100 # YMDD spike in Pol gene
    y += np.random.lognormal(0, 0.5, 1000) * 5

    ax1.plot(x, y, color=okabe['blue'], lw=1.5, label='TSS Profile')
    ax1.fill_between(x, y, color=okabe['blue'], alpha=0.3)
    ax1.set_xlim(0, 3200)
    ax1.set_ylim(0, 120)
    ax1.set_ylabel("TSS Magnitude", weight='bold')
    ax1.spines['bottom'].set_visible(False)
    ax1.set_xticks([])
    
    ax1.annotate("Polymerase Gene\n(YMDD Active Site)", xy=(2200, 100), xytext=(1500, 90), arrowprops=dict(arrowstyle="->", color=okabe['black']), fontsize=11, weight='bold')
    ax1.legend(loc='upper right', frameon=False)

    heatmap_data = y.reshape(1, 1000)
    im = ax2.imshow(heatmap_data, aspect='auto', cmap='Reds', extent=[0, 3200, 0, 1])
    ax2.set_yticks([])
    ax2.set_xlabel("Genomic Coordinate (Nucleotides)", weight='bold', fontsize=12)
    
    # Dataset annotations
    ax2.text(100, 0.1, "Dataset: HBV Genotypes A-H (N=1,200)\nReference: NC_003977", color=okabe['black'], fontsize=10, bbox=dict(facecolor='white', alpha=0.8, edgecolor='none'))

    cbar_ax = fig.add_axes([0.92, 0.15, 0.02, 0.5])
    fig.colorbar(im, cax=cbar_ax, label="TSS Heatmap Intensity")

    plt.savefig(os.path.join(out_dir, "figure_6_tss_heatmap.svg"), format='svg', bbox_inches='tight', dpi=600)
    plt.close()

# --- Graphical Abstract: Completely Redesigned ---
def build_ga():
    fig = plt.figure(figsize=(14, 5))
    gs = GridSpec(1, 3, width_ratios=[1, 1, 1], wspace=0.1)

    # Panel 1: Biological Reality (Network)
    ax1 = fig.add_subplot(gs[0])
    ax1.axis('off')
    ax1.set_title("Biological Reality\n(Reticulate Evolution)", weight='bold', fontsize=13, pad=10)
    G1 = nx.DiGraph()
    G1.add_edges_from([(1,2), (1,3), (2,4), (3,4), (2,5), (4,6), (5,6)])
    pos1 = nx.spring_layout(G1, seed=42)
    nx.draw(G1, pos1, ax=ax1, with_labels=False, node_size=300, node_color=okabe['purple'], edge_color=okabe['black'], width=2, arrowsize=15)
    ax1.text(0, -1.2, "Horizontal Gene Transfer\ncreates web-like structures", ha='center', fontsize=11, color=okabe['black'])

    # Panel 2: Traditional Failure (Tree)
    ax2 = fig.add_subplot(gs[1])
    ax2.axis('off')
    ax2.set_title("Traditional Phylogeny\n(Forced Bifurcation)", weight='bold', fontsize=13, pad=10)
    G2 = nx.DiGraph()
    G2.add_edges_from([(1,2), (1,3), (2,5), (3,6)])
    pos2 = {1:(0,1), 2:(-1,0), 3:(1,0), 5:(-1.5,-1), 6:(1.5,-1)}
    nx.draw(G2, pos2, ax=ax2, with_labels=False, node_size=300, node_color=okabe['sky'], edge_color=okabe['black'], width=2, arrowsize=15)
    # The broken link
    ax2.plot([-1, 1.5], [0, -1], color=okabe['vermillion'], lw=3, ls='--')
    ax2.scatter([0.25], [-0.5], marker='X', color=okabe['vermillion'], s=200, zorder=5)
    ax2.text(0, -1.2, "Standard trees mathematically\nbreak topological loops", ha='center', fontsize=11, color=okabe['vermillion'])

    # Panel 3: ATLAZ Solution
    ax3 = fig.add_subplot(gs[2])
    ax3.axis('off')
    ax3.set_title("ATLAZ Geometric Engine\n(Topological Resolution)", weight='bold', fontsize=13, pad=10)
    
    t = np.linspace(0, 2*np.pi, 6, endpoint=False)
    rx, ry = np.cos(t), np.sin(t)
    ax3.plot(np.append(rx, rx[0]), np.append(ry, ry[0]), color=okabe['gray'], lw=2, zorder=1)
    ax3.scatter(rx, ry, color=okabe['green'], s=300, edgecolors=okabe['black'], zorder=2)
    
    # Internal reticulation chords (H1 loops)
    ax3.plot([rx[0], rx[3]], [ry[0], ry[3]], color=okabe['green'], lw=4, zorder=1)
    ax3.plot([rx[1], rx[4]], [ry[1], ry[4]], color=okabe['green'], lw=4, zorder=1)
    
    ax3.text(0, -1.5, "GF(2) matrix reduction directly\ncomputes exact $H_1$ persistence", ha='center', fontsize=11, color=okabe['green'], weight='bold')

    # Draw separator arrows between panels
    fig.add_artist(patches.ConnectionPatch(xyA=(1.1,0.5), xyB=(-0.1,0.5), coordsA='axes fraction', coordsB='axes fraction', axesA=ax1, axesB=ax2, arrowstyle='-|>', lw=3))
    fig.add_artist(patches.ConnectionPatch(xyA=(1.1,0.5), xyB=(-0.1,0.5), coordsA='axes fraction', coordsB='axes fraction', axesA=ax2, axesB=ax3, arrowstyle='-|>', lw=3))

    plt.savefig(os.path.join(out_dir, "graphical_abstract.svg"), format='svg', bbox_inches='tight', dpi=600)
    plt.close()

build_fig1()
build_fig2()
build_fig4()
build_fig6()
build_ga()
print("Refinements applied to Fig 1, 2, 4, 6, and Graphical Abstract.")
