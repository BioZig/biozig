import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches

plt.style.use('default')

okabe = {
    'black': '#000000', 'sky': '#56B4E9', 'blue': '#0072B2',
    'vermillion': '#D55E00', 'green': '#009E73', 'gray': '#999999', 'bg': '#FFFFFF'
}

plt.rcParams.update({
    'font.family': 'sans-serif', 'font.sans-serif': ['Helvetica', 'Arial'],
    'axes.facecolor': okabe['bg'], 'figure.facecolor': okabe['bg']
})

fig, ax = plt.subplots(figsize=(12, 6))
ax.axis('off')

# Title
ax.text(0.5, 0.95, "ATLAZ: Zero-Cost Topological Engine Architecture", ha='center', weight='bold', fontsize=16)

# Main Engine Box (The ATLAZ Boundary)
engine_box = patches.FancyBboxPatch((0.25, 0.2), 0.5, 0.6, boxstyle="round,pad=0.02,rounding_size=0.03", fill=True, facecolor='#F0F8FF', edgecolor=okabe['blue'], lw=2, zorder=1)
ax.add_patch(engine_box)
ax.text(0.5, 0.82, "Zig Native C-ABI Kernel", ha='center', weight='bold', color=okabe['blue'], fontsize=12, zorder=2)

# Sub-components inside Engine
def draw_node(x, y, text, color, w=0.18, h=0.1):
    box = patches.FancyBboxPatch((x - w/2, y - h/2), w, h, boxstyle="round,pad=0.02,rounding_size=0.02", fill=True, facecolor='white', edgecolor=color, lw=1.5, zorder=3)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', weight='bold', fontsize=10, zorder=4)

draw_node(0.35, 0.65, "Zero-Copy\nmmap()", okabe['sky'])
draw_node(0.65, 0.65, "2-bit SoA\n(L1/L2 Cache)", okabe['sky'])
draw_node(0.5, 0.45, "Arena Allocator\n[O(1) Memory]", okabe['green'])
draw_node(0.35, 0.28, "Vietoris-Rips\nFiltration", okabe['blue'])
draw_node(0.65, 0.28, "GF(2) Matrix\nReduction", okabe['blue'])

# Internal Flow Arrows
kw = dict(arrowstyle="-|>", color=okabe['black'], lw=1.5)
ax.annotate("", xy=(0.54, 0.65), xytext=(0.46, 0.65), arrowprops=kw, zorder=2)
ax.annotate("", xy=(0.5, 0.52), xytext=(0.65, 0.58), arrowprops=dict(arrowstyle="-|>", color=okabe['gray'], lw=1.5, connectionstyle="arc3,rad=-0.2"), zorder=2)
ax.annotate("", xy=(0.5, 0.52), xytext=(0.35, 0.58), arrowprops=dict(arrowstyle="-|>", color=okabe['gray'], lw=1.5, connectionstyle="arc3,rad=0.2"), zorder=2)
ax.annotate("", xy=(0.35, 0.35), xytext=(0.45, 0.4), arrowprops=dict(arrowstyle="-|>", color=okabe['gray'], lw=1.5, connectionstyle="arc3,rad=-0.2"), zorder=2)
ax.annotate("", xy=(0.65, 0.28), xytext=(0.46, 0.28), arrowprops=kw, zorder=2)

# Inputs
draw_node(0.08, 0.65, "Raw Genomic\nFASTA/FASTQ", okabe['black'])
ax.annotate("", xy=(0.24, 0.65), xytext=(0.19, 0.65), arrowprops=dict(arrowstyle="-|>", color=okabe['black'], lw=2), zorder=2)

# Outputs
draw_node(0.92, 0.28, "Topological\nSignatures ($H_1$)", okabe['black'])
ax.annotate("", xy=(0.81, 0.28), xytext=(0.76, 0.28), arrowprops=dict(arrowstyle="-|>", color=okabe['black'], lw=2), zorder=2)

# Legacy Failure Path
legacy_box = patches.FancyBboxPatch((0.25, 0.0), 0.5, 0.12, boxstyle="round,pad=0.02,rounding_size=0.02", fill=True, facecolor='#FFEBEE', edgecolor=okabe['vermillion'], lw=2, ls='--', zorder=1)
ax.add_patch(legacy_box)
ax.text(0.5, 0.06, "Legacy Interpreted Languages (Python / R)", ha='center', weight='bold', color=okabe['vermillion'], fontsize=11, zorder=2)
ax.annotate("", xy=(0.25, 0.06), xytext=(0.1, 0.58), arrowprops=dict(arrowstyle="->", color=okabe['vermillion'], lw=2, ls='--', connectionstyle="angle,angleA=0,angleB=-90,rad=10"), zorder=2)
ax.text(0.12, 0.3, "Object\nDeserialization\n(GC Overhead)", color=okabe['vermillion'], fontsize=9, ha='left')
ax.scatter([0.25], [0.06], color=okabe['vermillion'], marker='X', s=200, zorder=5)
ax.text(0.28, 0.06, "OOM Crash", color=okabe['vermillion'], weight='bold', va='center')

plt.savefig("/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/figures/figure_1_architecture.svg", format='svg', bbox_inches='tight', dpi=600)
plt.close()
print("Figure 1 Re-rendered.")
