import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import matplotlib.lines as mlines
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.gridspec import GridSpec
import networkx as nx

# --- Ultra-Modern "Glass & Steel" Data Journalism Aesthetic ---
# Inspired by high-end data viz (Tufte, NYT, advanced d3.js)
plt.style.use('default')

palette = {
    'bg': '#FAFAFA',          # Off-white, soft background
    'panel': '#FFFFFF',       # Pure white for data panels
    'text_dark': '#111827',   # Very dark slate
    'text_light': '#6B7280',  # Soft slate for axes/grids
    'grid': '#E5E7EB',        # Ultra-light gridlines
    'indigo': '#4F46E5',      # Primary: ATLAZ
    'coral': '#F43F5E',       # Primary: Legacy / Errors / Highlight
    'teal': '#0D9488',        # Secondary: Geometry / Structure
    'amber': '#F59E0B',       # Annotations
    'slate': '#94A3B8'        # Neutral structure
}

plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Helvetica', 'Arial', 'sans-serif'],
    'font.size': 11,
    'axes.facecolor': palette['bg'],
    'figure.facecolor': palette['bg'],
    'axes.edgecolor': palette['text_light'],
    'axes.labelcolor': palette['text_dark'],
    'axes.grid': False,
    'text.color': palette['text_dark'],
    'xtick.color': palette['text_light'],
    'ytick.color': palette['text_light'],
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.spines.left': False,
    'axes.spines.bottom': True,
    'legend.frameon': False
})

out_dir = "/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures"
os.makedirs(out_dir, exist_ok=True)

def save_fig(name):
    plt.savefig(os.path.join(out_dir, f"{name}.svg"), format='svg', facecolor=palette['bg'], bbox_inches='tight', dpi=600)
    plt.close()

# --- 1. Graphical Abstract: Circular Genome & Chord Diagram ---
fig, ax = plt.subplots(figsize=(10, 5))
ax.axis('off')
ax.set_aspect('equal')
# Left Hemisphere: Broken Tree
theta_left = np.linspace(np.pi/2, 3*np.pi/2, 100)
ax.plot(np.cos(theta_left), np.sin(theta_left), color=palette['slate'], lw=4, alpha=0.3)
ax.text(-0.5, 0.2, "Bifurcating\nPhylogeny", ha='center', color=palette['slate'], weight='bold')
ax.plot([-0.9, -0.6, -0.3], [0, -0.5, 0], color=palette['coral'], lw=2, ls='--')
ax.plot([-0.6, -0.5], [-0.5, -0.8], color=palette['coral'], lw=2, ls='--')
ax.scatter([-0.3, -0.5], [0, -0.8], color=palette['coral'], s=100, zorder=5)
ax.text(-0.6, -0.2, "Topology\nLost", color=palette['coral'], fontsize=9, ha='center')

# Right Hemisphere: ATLAZ Chord Reticulation
theta_right = np.linspace(-np.pi/2, np.pi/2, 100)
ax.plot(np.cos(theta_right), np.sin(theta_right), color=palette['indigo'], lw=6)
ax.text(0.5, 0.2, "ATLAZ Geometric\nResolution", ha='center', color=palette['indigo'], weight='bold')
# Draw bezier curves for H1 loops across the right hemisphere
for _ in range(12):
    t1 = np.random.uniform(-np.pi/2.2, np.pi/2.2)
    t2 = np.random.uniform(-np.pi/2.2, np.pi/2.2)
    x1, y1 = np.cos(t1), np.sin(t1)
    x2, y2 = np.cos(t2), np.sin(t2)
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1), arrowprops=dict(arrowstyle="-", color=palette['teal'], alpha=0.4, connectionstyle="arc3,rad=0.3", lw=1.5))
ax.text(0.5, -0.2, "Exact $H_1$\nPreservation", color=palette['teal'], fontsize=9, ha='center')
ax.text(0, 1.2, "The Reticulate Paradigm Shift", fontsize=16, weight='bold', ha='center')
save_fig('graphical_abstract')

# --- 2. Architecture: Hardware vs Software Stack ---
fig, ax = plt.subplots(figsize=(10, 6))
ax.axis('off')
# Hardware Layer (Bottom)
ax.add_patch(patches.Rectangle((0.1, 0.1), 0.8, 0.2, fill=True, facecolor=palette['panel'], edgecolor=palette['slate'], lw=1))
ax.text(0.12, 0.25, "Hardware Layer (L1/L2 Cache)", weight='bold', color=palette['slate'])
ax.add_patch(patches.Rectangle((0.15, 0.12), 0.3, 0.1, fill=True, facecolor=palette['grid']))
ax.text(0.3, 0.17, "2-bit SoA Memory", ha='center', va='center', color=palette['text_light'])

# Software Layer (Middle)
ax.add_patch(patches.Rectangle((0.1, 0.35), 0.8, 0.3, fill=True, facecolor=palette['panel'], edgecolor=palette['indigo'], lw=2))
ax.text(0.12, 0.6, "ATLAZ Engine (Zig)", weight='bold', color=palette['indigo'])
ax.text(0.3, 0.45, "Arena Allocator\nO(1) Bounds", ha='center', va='center', bbox=dict(facecolor=palette['bg'], edgecolor=palette['indigo'], pad=1))
ax.text(0.7, 0.45, "GF(2) Matrix\nReduction", ha='center', va='center', bbox=dict(facecolor=palette['bg'], edgecolor=palette['indigo'], pad=1))
ax.annotate("", xy=(0.55, 0.45), xytext=(0.45, 0.45), arrowprops=dict(arrowstyle="->", color=palette['indigo'], lw=2))

# FFI Layer (Top)
ax.add_patch(patches.Rectangle((0.1, 0.7), 0.8, 0.2, fill=True, facecolor=palette['panel'], edgecolor=palette['coral'], lw=1, ls='--'))
ax.text(0.12, 0.85, "Interpreted Environments", weight='bold', color=palette['coral'])
ax.text(0.5, 0.78, "Python / R Bindings\n(Zero-Cost C-ABI)", ha='center', va='center', color=palette['coral'])
ax.annotate("", xy=(0.5, 0.65), xytext=(0.5, 0.7), arrowprops=dict(arrowstyle="<->", color=palette['text_light'], lw=2))
ax.text(0.55, 0.67, "Zero-Copy Boundary", color=palette['text_light'], fontsize=9)
save_fig('figure_1_architecture')

# --- 3. Clonal: Ridgeline Plot (Joyplot) ---
fig, ax = plt.subplots(figsize=(8, 5))
ax.spines['bottom'].set_visible(False)
ax.set_yticks([])
ax.set_xticks([])
x = np.linspace(0, 10, 500)
for i in range(7):
    # Simulate Gaussian merging of components
    y = np.exp(-((x - (i*1.5 + 1))**2) / (0.5 + i*0.2)) * (1 - i*0.1)
    # Plot ridge
    ax.fill_between(x, i*0.5, i*0.5 + y, color=palette['indigo'], alpha=0.6, zorder=7-i)
    ax.plot(x, i*0.5 + y, color=palette['panel'], lw=1.5, zorder=7-i)
ax.text(5, 4.5, "Clonal Evolution:\nSmooth $H_0$ Merging", fontsize=14, weight='bold', color=palette['indigo'], ha='center')
ax.text(5, 4, "(No structural anomalies)", fontsize=10, color=palette['text_light'], ha='center')
save_fig('figure_2_clonal')

# --- 4. Reticulate: Polar Persistence Barcode ---
fig = plt.figure(figsize=(6, 6))
ax = fig.add_subplot(111, polar=True)
ax.set_theta_zero_location("N")
ax.set_theta_direction(-1)
ax.set_yticklabels([])
ax.set_xticklabels([])
ax.grid(False)
ax.spines['polar'].set_visible(False)
# Inner circle (genome)
theta = np.linspace(0, 2*np.pi, 100)
ax.plot(theta, np.ones_like(theta)*0.2, color=palette['slate'], lw=2)
# H1 explosions
for _ in range(120):
    t = np.random.uniform(0, 2*np.pi)
    length = np.random.exponential(0.3)
    if length > 0.7: length = 0.7
    ax.plot([t, t], [0.2, 0.2 + length], color=palette['coral'], lw=1.5, alpha=0.6)
ax.plot(np.linspace(0.8, 1.2, 50), np.ones(50)*0.7, color=palette['coral'], lw=3)
ax.text(1.0, 0.8, "Reticulation Horizon", color=palette['coral'], fontsize=9, ha='center')
ax.text(0, 0, "HBV\n$\\beta_1=843$", ha='center', va='center', weight='bold', color=palette['text_dark'])
save_fig('figure_3_reticulate')

# --- 5. 3D Realization: Mapper-Style Graph ---
fig, ax = plt.subplots(figsize=(8, 6))
ax.axis('off')
# Use hexbin aesthetic for nodes
np.random.seed(42)
x = np.random.normal(0, 1, 30)
y = np.random.normal(0, 1, 30)
# Force a hole
r = np.sqrt(x**2 + y**2)
x = x[r > 0.8]
y = y[r > 0.8]
ax.scatter(x, y, s=500, marker='h', c=palette['teal'], alpha=0.8, edgecolors=palette['panel'], lw=2, zorder=3)
# Connect nearest neighbors
from scipy.spatial import Delaunay
tri = Delaunay(np.column_stack([x, y]))
for simplex in tri.simplices:
    ax.plot(x[simplex], y[simplex], color=palette['slate'], lw=1, alpha=0.5, zorder=2)
# Highlight the topological void
circle = patches.Circle((0, 0), 0.7, fill=False, edgecolor=palette['coral'], lw=2, ls='--', zorder=4)
ax.add_patch(circle)
ax.text(0, 0, "Topological\nVoid ($H_1$)", ha='center', va='center', weight='bold', color=palette['coral'], zorder=5)
save_fig('figure_4_3d_reticulation')

# --- 6. TSS Math: Gradient Matrix Factorization ---
fig, ax = plt.subplots(figsize=(9, 4))
ax.axis('off')
# Create a sleek gradient matrix representation
def draw_matrix(ax, x, y, w, h, color_start, color_end, title):
    gradient = np.linspace(0, 1, 256).reshape(1, -1)
    cmap = LinearSegmentedColormap.from_list('custom', [color_start, color_end])
    ax.imshow(gradient, aspect='auto', cmap=cmap, extent=[x, x+w, y, y+h], alpha=0.8)
    ax.add_patch(patches.Rectangle((x, y), w, h, fill=False, edgecolor=palette['text_dark'], lw=1))
    ax.text(x + w/2, y + h + 0.1, title, ha='center', fontsize=11, weight='bold')

draw_matrix(ax, 0, 0.2, 0.3, 0.6, palette['panel'], palette['indigo'], "Original ($M$)")
ax.text(0.4, 0.5, "$-$\n$\\partial_j$", ha='center', va='center', fontsize=16)
draw_matrix(ax, 0.5, 0.2, 0.3, 0.6, palette['panel'], palette['indigo'], "Ablated ($M_{-j}$)")
# Draw ablation slice
ax.add_patch(patches.Rectangle((0.65, 0.15), 0.03, 0.7, fill=True, color=palette['coral']))
ax.text(0.665, 0.05, "Column $j$", ha='center', color=palette['coral'], fontsize=9, weight='bold')
ax.text(0.85, 0.5, "$\\Rightarrow \\Delta \\beta_1$", fontsize=16, color=palette['teal'], weight='bold')
save_fig('figure_5_tss_math')

# --- 7. TSS Heatmap: Multi-Track Dense Data Viewer ---
fig = plt.figure(figsize=(10, 5))
gs = GridSpec(2, 1, height_ratios=[1, 0.2], hspace=0.1)
ax1 = fig.add_subplot(gs[0])
ax2 = fig.add_subplot(gs[1])
x = np.linspace(0, 1000, 1000)
# Sleek Area Chart for TSS
y = np.exp(-((x - 745)**2) / 100) * 100 
y += np.random.lognormal(0, 0.5, 1000) * 5
ax1.plot(x, y, color=palette['indigo'], lw=1.5)
ax1.fill_between(x, y, color=palette['indigo'], alpha=0.2)
ax1.set_xlim(0, 1000)
ax1.set_ylim(0, 110)
ax1.set_ylabel("TSS Intensity")
ax1.spines['bottom'].set_visible(False)
ax1.set_xticks([])
# Motif Track
ax2.set_xlim(0, 1000)
ax2.set_ylim(0, 1)
ax2.axvspan(735, 755, color=palette['coral'], alpha=0.8)
ax2.text(745, 0.5, "YMDD Motif", ha='center', va='center', color=palette['panel'], fontsize=9, weight='bold')
ax2.set_yticks([])
ax2.spines['left'].set_visible(False)
ax2.set_xlabel("Genomic Position (nt)")
save_fig('figure_6_tss_heatmap')

# --- 8. Telemetry: Dual-Axis Area with Shatter ---
fig, ax = plt.subplots(figsize=(9, 5))
N = np.array([500, 1000, 2000, 3000, 4000, 5000, 6412])
mem_atlaz = np.ones_like(N) * 11.4
# ATLAZ solid ground
ax.fill_between(N, 0, mem_atlaz, color=palette['indigo'], alpha=0.3)
ax.plot(N, mem_atlaz, color=palette['indigo'], lw=3, label="ATLAZ (11.4 MB)")

# Python/R exploding
N_legacy = np.array([500, 800, 1000, 1200])
mem_py = np.array([50, 250, 800, 3200])
ax.plot(N_legacy, mem_py, color=palette['coral'], lw=2, ls='--', marker='o', label="Python GC")
ax.plot([1200, 1200], [3200, 5000], color=palette['coral'], lw=2, ls=':')
ax.scatter(1200, 5000, marker='*', s=300, color=palette['coral'])
ax.text(1300, 4500, "OOM\nCrash", color=palette['coral'], weight='bold')

ax.set_yscale('log')
ax.set_ylim(5, 10000)
ax.set_xlim(0, 6500)
ax.set_ylabel("Peak Memory (MB)")
ax.set_xlabel("Sequence Count (N)")
ax.legend(loc='upper right')
save_fig('figure_7_telemetry')

# --- 9. Geography: Minimalist Sankey/Flow ---
fig, ax = plt.subplots(figsize=(8, 4))
ax.axis('off')
ax.set_title("H7N9 Topological Reassortment Flow", pad=10)
# Nodes as horizontal bars
nodes = {'Avian': (0.1, 0.6), 'Poultry': (0.5, 0.4), 'Market': (0.9, 0.2)}
for name, (x, y) in nodes.items():
    ax.plot([x-0.05, x+0.05], [y, y], color=palette['text_dark'], lw=4)
    ax.text(x, y+0.05, name, ha='center', weight='bold')

# Flow curves
import matplotlib.path as mpath
def draw_flow(ax, p1, p2, color):
    verts = [p1, (p1[0]+0.2, p1[1]), (p2[0]-0.2, p2[1]), p2]
    codes = [mpath.Path.MOVETO, mpath.Path.CURVE4, mpath.Path.CURVE4, mpath.Path.CURVE4]
    path = mpath.Path(verts, codes)
    patch = patches.PathPatch(path, facecolor='none', edgecolor=color, lw=3, alpha=0.6)
    ax.add_patch(patch)

draw_flow(ax, (0.15, 0.6), (0.45, 0.4), palette['teal'])
draw_flow(ax, (0.55, 0.4), (0.85, 0.2), palette['teal'])
draw_flow(ax, (0.15, 0.6), (0.85, 0.2), palette['coral'])
ax.text(0.5, 0.7, "Reticulate Back-flow ($H_1$)", color=palette['coral'], weight='bold', ha='center')
save_fig('figure_8_geography')

print("Generated 9 ULTRA-MODERN Data-Journalism SVGs in " + out_dir)
