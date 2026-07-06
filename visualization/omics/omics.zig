const std = @import("std");

/// A container representing a pre-calculated gene expression matrix.
pub const ExpressionMatrix = struct {
    row_names: []const []const u8,
    col_names: []const []const u8,
    data: []const []const f64,

    pub fn init(
        row_names: []const []const u8,
        col_names: []const []const u8,
        data: []const []const f64,
    ) ExpressionMatrix {
        return .{
            .row_names = row_names,
            .col_names = col_names,
            .data = data,
        };
    }
};

/// A heatmap rendering structure.
pub const Heatmap = struct {
    matrix: ExpressionMatrix,
    title: []const u8,

    pub fn init(matrix: ExpressionMatrix, title: []const u8) Heatmap {
        return .{
            .matrix = matrix,
            .title = title,
        };
    }

    /// Renders a deterministic SVG representation of the heatmap grid.
    /// Uses a professional Blue-White-Red double gradient for negative/positive values.
    pub fn renderSvg(self: Heatmap, writer: anytype) !void {
        const rows = self.matrix.row_names.len;
        const cols = self.matrix.col_names.len;
        if (rows == 0 or cols == 0) return;

        const cell_w: f64 = @min(30.0, 400.0 / @as(f64, @floatFromInt(cols)));
        const cell_h: f64 = @min(30.0, 400.0 / @as(f64, @floatFromInt(rows)));

        const grid_w = cell_w * @as(f64, @floatFromInt(cols));
        const grid_h = cell_h * @as(f64, @floatFromInt(rows));

        const margin_left: f64 = 80.0;
        const margin_right: f64 = 40.0;
        const margin_top: f64 = 50.0;
        const margin_bottom: f64 = 80.0;

        const width = grid_w + margin_left + margin_right;
        const height = grid_h + margin_top + margin_bottom;

        // Find max absolute value for normalization
        var max_abs: f64 = 0.0;
        for (self.matrix.data) |row| {
            for (row) |val| {
                max_abs = @max(max_abs, @abs(val));
            }
        }
        if (max_abs == 0.0) max_abs = 1.0;

        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="14" font-weight="bold" text-anchor="middle" fill="#333333">{s}</text>
        , .{ width, height, width, height, width / 2.0, margin_top - 20.0, self.title });

        for (self.matrix.data, 0..) |row, r| {
            const y = margin_top + @as(f64, @floatFromInt(r)) * cell_h;

            // Row label
            try writer.print(
                \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="9" text-anchor="end" fill="#333333" dominant-baseline="middle">{s}</text>
            , .{ margin_left - 5.0, y + cell_h / 2.0, self.matrix.row_names[r] });

            for (row, 0..) |val, c| {
                const x = margin_left + @as(f64, @floatFromInt(c)) * cell_w;

                // Color interpolation: blue (-max) -> white (0) -> red (+max)
                const norm_val = val / max_abs;
                var rgb_str = [_]u8{0} ** 16;
                var fbs = std.Io.Writer.fixed(&rgb_str);

                if (norm_val < 0.0) {
                    const factor = 1.0 + norm_val; // goes from 0 at -max to 1 at 0
                    const rb = @as(u8, @intFromFloat(factor * 255.0));
                    try fbs.print("rgb({},{}.255)", .{ rb, rb });
                } else {
                    const factor = 1.0 - norm_val; // goes from 1 at 0 to 0 at +max
                    const gb = @as(u8, @intFromFloat(factor * 255.0));
                    try fbs.print("rgb(255,{},{})", .{ gb, gb });
                }

                try writer.print(
                    \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" fill="{s}" stroke="#ffffff" stroke-width="0.5"/>
                , .{ x, y, cell_w, cell_h, fbs.buffered() });
            }
        }

        // Column labels (rotated 90 degrees)
        for (self.matrix.col_names, 0..) |col_name, c| {
            const x = margin_left + @as(f64, @floatFromInt(c)) * cell_w;
            try writer.print(
                \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="9" text-anchor="start" fill="#333333" transform="rotate(90 {d} {d})">{s}</text>
            , .{ x + cell_w / 2.0, margin_top + grid_h + 5.0, x + cell_w / 2.0, margin_top + grid_h + 5.0, col_name });
        }

        try writer.writeAll("</svg>\n");
    }
};

/// Volcano plot container storing pre-computed significance data.
pub const VolcanoPlot = struct {
    log2_fc: []const f64,
    neg_log10_p: []const f64,
    labels: []const []const u8,
    title: []const u8,
    fc_threshold: f64, // e.g. 1.0
    p_threshold: f64, // e.g. 1.3 (equivalent to p-value 0.05)

    pub fn init(
        log2_fc: []const f64,
        neg_log10_p: []const f64,
        labels: []const []const u8,
        title: []const u8,
        fc_threshold: f64,
        p_threshold: f64,
    ) VolcanoPlot {
        return .{
            .log2_fc = log2_fc,
            .neg_log10_p = neg_log10_p,
            .labels = labels,
            .title = title,
            .fc_threshold = fc_threshold,
            .p_threshold = p_threshold,
        };
    }

    /// Renders a deterministic SVG scatter plot.
    /// Significant points are colored: red (upregulated), blue (downregulated). Non-significant points are gray.
    pub fn renderSvg(self: VolcanoPlot, writer: anytype) !void {
        const width: f64 = 600.0;
        const height: f64 = 400.0;
        const margin_left: f64 = 60.0;
        const margin_right: f64 = 40.0;
        const margin_top: f64 = 50.0;
        const margin_bottom: f64 = 50.0;

        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="16" font-weight="bold" text-anchor="middle" fill="#333333">{s}</text>
            \\<line x1="{d}" y1="{d}" x2="{d}" y2="{d}" stroke="#cccccc" stroke-width="1"/>
            \\<line x1="{d}" y1="{d}" x2="{d}" y2="{d}" stroke="#cccccc" stroke-width="1"/>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#666666">log2 Fold Change</text>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#666666" transform="rotate(-90 {d} {d})">-log10 p-value</text>
        , .{
            width,                  height,               width,                  height,
            width / 2.0,            margin_top - 20.0,    self.title,             margin_left,
            height - margin_bottom, width - margin_right, height - margin_bottom, margin_left,
            margin_top,             margin_left,          height - margin_bottom, width / 2.0,
            height - 15.0,          20.0,                 height / 2.0,           20.0,
            height / 2.0,
        });

        if (self.log2_fc.len > 0) {
            // Find ranges
            var min_x = self.log2_fc[0];
            var max_x = min_x;
            var max_y = self.neg_log10_p[0];
            for (self.log2_fc) |x| {
                min_x = @min(min_x, x);
                max_x = @max(max_x, x);
            }
            for (self.neg_log10_p) |y| {
                max_y = @max(max_y, y);
            }
            if (max_y == 0.0) max_y = 1.0;

            // symmetrize X-axis around 0
            const abs_max_x = @max(@abs(min_x), @abs(max_x));
            const x_range = if (abs_max_x == 0.0) 2.0 else abs_max_x * 2.0;

            const plot_w = width - margin_left - margin_right;
            const plot_h = height - margin_top - margin_bottom;

            for (self.log2_fc, 0..) |fc, i| {
                const p = self.neg_log10_p[i];

                // Map coordinates
                const pct_x = (fc + abs_max_x) / x_range;
                const cx = margin_left + pct_x * plot_w;
                const cy = height - margin_bottom - (p / max_y) * plot_h;

                // Determine classification color
                var color: []const u8 = "#aaaaaa"; // default non-significant gray
                if (p >= self.p_threshold) {
                    if (fc >= self.fc_threshold) {
                        color = "#d62728"; // significant upregulated (red)
                    } else if (fc <= -self.fc_threshold) {
                        color = "#1f77b4"; // significant downregulated (blue)
                    }
                }

                try writer.print(
                    \\<circle cx="{d:.2}" cy="{d:.2}" r="3.5" fill="{s}" fill-opacity="0.75"/>
                , .{ cx, cy, color });
            }
        }

        try writer.writeAll("</svg>\n");
    }
};

/// PCA coordinates container for plotting PC1/PC2.
pub const PcaPlotContainer = struct {
    pc1: []const f64,
    pc2: []const f64,
    groups: []const []const u8,
    sample_names: []const []const u8,
    title: []const u8,

    pub fn init(
        pc1: []const f64,
        pc2: []const f64,
        groups: []const []const u8,
        sample_names: []const []const u8,
        title: []const u8,
    ) PcaPlotContainer {
        return .{
            .pc1 = pc1,
            .pc2 = pc2,
            .groups = groups,
            .sample_names = sample_names,
            .title = title,
        };
    }

    /// Renders a deterministic SVG scatter plot of the PCA projection.
    pub fn renderSvg(self: PcaPlotContainer, writer: anytype) !void {
        const width: f64 = 600.0;
        const height: f64 = 400.0;
        const margin_left: f64 = 60.0;
        const margin_right: f64 = 40.0;
        const margin_top: f64 = 50.0;
        const margin_bottom: f64 = 50.0;

        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="16" font-weight="bold" text-anchor="middle" fill="#333333">{s}</text>
            \\<line x1="{d}" y1="{d}" x2="{d}" y2="{d}" stroke="#cccccc" stroke-width="1"/>
            \\<line x1="{d}" y1="{d}" x2="{d}" y2="{d}" stroke="#cccccc" stroke-width="1"/>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#666666">PC1</text>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#666666" transform="rotate(-90 {d} {d})">PC2</text>
        , .{
            width,                  height,               width,                  height,
            width / 2.0,            margin_top - 20.0,    self.title,             margin_left,
            height - margin_bottom, width - margin_right, height - margin_bottom, margin_left,
            margin_top,             margin_left,          height - margin_bottom, width / 2.0,
            height - 15.0,          20.0,                 height / 2.0,           20.0,
            height / 2.0,
        });

        if (self.pc1.len > 0) {
            var min_x = self.pc1[0];
            var max_x = min_x;
            var min_y = self.pc2[0];
            var max_y = min_y;

            for (self.pc1) |x| {
                min_x = @min(min_x, x);
                max_x = @max(max_x, x);
            }
            for (self.pc2) |y| {
                min_y = @min(min_y, y);
                max_y = @max(max_y, y);
            }

            const x_range = if (max_x == min_x) 1.0 else max_x - min_x;
            const y_range = if (max_y == min_y) 1.0 else max_y - min_y;

            const plot_w = width - margin_left - margin_right;
            const plot_h = height - margin_top - margin_bottom;

            for (self.pc1, 0..) |x_val, i| {
                const y_val = self.pc2[i];

                const cx = margin_left + ((x_val - min_x) / x_range) * plot_w;
                const cy = height - margin_bottom - ((y_val - min_y) / y_range) * plot_h;

                // Color selection based on group name
                var color: []const u8 = "#9467bd";
                if (self.groups.len > i) {
                    const g = self.groups[i];
                    if (std.mem.eql(u8, g, "Control") or std.mem.eql(u8, g, "Ctrl")) {
                        color = "#1f77b4";
                    } else if (std.mem.eql(u8, g, "Treatment") or std.mem.eql(u8, g, "Treat")) {
                        color = "#ff7f0e";
                    }
                }

                try writer.print(
                    \\<circle cx="{d:.2}" cy="{d:.2}" r="5" fill="{s}" stroke="#ffffff" stroke-width="1"/>
                , .{ cx, cy, color });
            }
        }

        try writer.writeAll("</svg>\n");
    }
};

test "Omics plots rendering validation" {
    const row_names = [_][]const u8{ "GeneA", "GeneB" };
    const col_names = [_][]const u8{ "Ctrl1", "Treat1" };
    const r0 = [_]f64{ -1.5, 2.0 };
    const r1 = [_]f64{ 0.5, -0.8 };
    const data = [_][]const f64{ &r0, &r1 };

    const matrix = ExpressionMatrix.init(&row_names, &col_names, &data);
    const hm = Heatmap.init(matrix, "Gene Expression Heatmap");

    var buf: [2048]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try hm.renderSvg(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);

    const log2_fc = [_]f64{ -2.0, 0.5, 3.2 };
    const neg_log10_p = [_]f64{ 4.1, 0.2, 5.0 };
    const labels = [_][]const u8{ "GeneA", "GeneB", "GeneC" };
    const volcano = VolcanoPlot.init(&log2_fc, &neg_log10_p, &labels, "Volcano Plot", 1.0, 1.3);

    var fbs_v = std.Io.Writer.fixed(&buf);
    try volcano.renderSvg(&fbs_v);
    try std.testing.expect(fbs_v.buffered().len > 0);
}
