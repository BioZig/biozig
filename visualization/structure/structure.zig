const std = @import("std");
const structural = @import("structural");
const Vec3 = structural.geometry.Vec3;

/// Visual properties for representing an atom.
pub const AtomVisual = struct {
    id: usize,
    pos: Vec3,
    label: []const u8,
    color: []const u8, // Hex code or standard CSS color name
    radius: f64,       // Visual display radius

    pub fn init(id: usize, pos: Vec3, label: []const u8, color: []const u8, radius: f64) AtomVisual {
        return .{
            .id = id,
            .pos = pos,
            .label = label,
            .color = color,
            .radius = radius,
        };
    }
};

/// Visual properties for representing a residue.
pub const ResidueVisual = struct {
    id: usize,
    name: []const u8,
    atoms: []const AtomVisual,
    color: []const u8,

    pub fn init(id: usize, name: []const u8, atoms: []const AtomVisual, color: []const u8) ResidueVisual {
        return .{
            .id = id,
            .name = name,
            .atoms = atoms,
            .color = color,
        };
    }
};

/// Visual properties for representing a chain.
pub const ChainVisual = struct {
    id: []const u8,
    residues: []const ResidueVisual,
    color: []const u8,

    pub fn init(id: []const u8, residues: []const ResidueVisual, color: []const u8) ChainVisual {
        return .{
            .id = id,
            .residues = residues,
            .color = color,
        };
    }
};

/// A 2D contact map representation of distance contacts between residues.
pub const ContactMap = struct {
    /// Residue labels (e.g. "ALA1", "GLY2")
    labels: []const []const u8,
    /// N x N matrix of pairwise distances
    matrix: []const []const f64,
    /// Distance threshold defining a contact (typically 8.0 A)
    threshold: f64,

    pub fn init(labels: []const []const u8, matrix: []const []const f64, threshold: f64) ContactMap {
        return .{
            .labels = labels,
            .matrix = matrix,
            .threshold = threshold,
        };
    }

    /// Renders a deterministic SVG representation of the contact map grid.
    /// Contacts (distance <= threshold) are filled with a dark color, non-contacts are light.
    pub fn renderSvg(self: ContactMap, writer: anytype) !void {
        const n = self.labels.len;
        if (n == 0) return;

        const cell_size: f64 = @min(10.0, 400.0 / @as(f64, @floatFromInt(n)));
        const grid_size: f64 = cell_size * @as(f64, @floatFromInt(n));
        const margin: f64 = 50.0;
        const width: f64 = grid_size + margin * 2.0;
        const height: f64 = grid_size + margin * 2.0;

        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
            \\<rect x="{d}" y="{d}" width="{d}" height="{d}" fill="none" stroke="#333333" stroke-width="1.5"/>
        , .{ width, height, width, height, margin, margin, grid_size, grid_size });

        var i: usize = 0;
        while (i < n) : (i += 1) {
            const y = margin + @as(f64, @floatFromInt(i)) * cell_size;
            var j: usize = 0;
            while (j < n) : (j += 1) {
                const x = margin + @as(f64, @floatFromInt(j)) * cell_size;
                const d = self.matrix[i][j];
                const is_contact = d <= self.threshold;

                const color = if (is_contact) "#1a1a1a" else "#f0f0f0";
                try writer.print(
                    \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" fill="{s}" stroke="#e0e0e0" stroke-width="0.5"/>
                , .{ x, y, cell_size, cell_size, color });
            }
        }

        // Draw basic corner labels
        if (n > 1) {
            try writer.print(
                \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="10" text-anchor="end" fill="#666666" dominant-baseline="middle">{s}</text>
                \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="10" text-anchor="end" fill="#666666" dominant-baseline="middle">{s}</text>
                \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#666666">{s}</text>
                \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#666666">{s}</text>
            , .{
                margin - 5.0, margin + cell_size / 2.0, self.labels[0],
                margin - 5.0, margin + grid_size - cell_size / 2.0, self.labels[n - 1],
                margin + cell_size / 2.0, margin - 5.0, self.labels[0],
                margin + grid_size - cell_size / 2.0, margin - 5.0, self.labels[n - 1],
            });
        }

        try writer.writeAll("</svg>\n");
    }
};

/// Visual representation of a binding pocket cavity.
pub const PocketVisual = struct {
    pocket_id: usize,
    volume: f64,
    centroid: Vec3,
    lining_residues: []const []const u8,
    color: []const u8,

    pub fn init(
        pocket_id: usize,
        volume: f64,
        centroid: Vec3,
        lining_residues: []const []const u8,
        color: []const u8,
    ) PocketVisual {
        return .{
            .pocket_id = pocket_id,
            .volume = volume,
            .centroid = centroid,
            .lining_residues = lining_residues,
            .color = color,
        };
    }
};

test "Structure visualization primitives" {
    const atom_vis = AtomVisual.init(1, Vec3.init(0.0, 1.2, 3.4), "CA", "#ff0000", 1.5);
    try std.testing.expectEqual(atom_vis.id, 1);
    try std.testing.expectEqualStrings("#ff0000", atom_vis.color);

    const labels = [_][]const u8{ "R1", "R2" };
    const row0 = [_]f64{ 0.0, 4.5 };
    const row1 = [_]f64{ 4.5, 0.0 };
    const matrix = [_][]const f64{ &row0, &row1 };

    const cmap = ContactMap.init(&labels, &matrix, 8.0);

    var buf: [4096]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try cmap.renderSvg(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
