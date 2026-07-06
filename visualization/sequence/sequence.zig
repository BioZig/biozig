const std = @import("std");

/// Plot data for GC content across sliding windows of a sequence.
pub const GcContentPlot = struct {
    window_sizes: []const usize,
    gc_fractions: []const f64,
    title: []const u8,
    x_label: []const u8,
    y_label: []const u8,

    pub fn init(
        window_sizes: []const usize,
        gc_fractions: []const f64,
        title: []const u8,
        x_label: []const u8,
        y_label: []const u8,
    ) GcContentPlot {
        return .{
            .window_sizes = window_sizes,
            .gc_fractions = gc_fractions,
            .title = title,
            .x_label = x_label,
            .y_label = y_label,
        };
    }

    /// Renders a deterministic SVG representation of the GC content line plot.
    pub fn renderSvg(self: GcContentPlot, writer: anytype) !void {
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
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#666666">{s}</text>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#666666" transform="rotate(-90 {d} {d})">{s}</text>
        , .{
            width, height, width, height,
            width / 2.0, margin_top - 20.0, self.title,
            margin_left, height - margin_bottom, width - margin_right, height - margin_bottom, // X-axis
            margin_left, margin_top, margin_left, height - margin_bottom, // Y-axis
            width / 2.0, height - 15.0, self.x_label,
            20.0, height / 2.0, 20.0, height / 2.0, self.y_label,
        });

        if (self.gc_fractions.len > 1) {
            var min_w: f64 = @as(f64, @floatFromInt(self.window_sizes[0]));
            var max_w: f64 = min_w;
            for (self.window_sizes) |w| {
                const wf = @as(f64, @floatFromInt(w));
                min_w = @min(min_w, wf);
                max_w = @max(max_w, wf);
            }
            const w_range = if (max_w == min_w) 1.0 else max_w - min_w;

            // Plot line path
            try writer.writeAll("<path d=\"");
            for (self.gc_fractions, 0..) |gf, i| {
                const w_val = @as(f64, @floatFromInt(self.window_sizes[i]));
                const pct_x = (w_val - min_w) / w_range;
                const x = margin_left + pct_x * (width - margin_left - margin_right);
                // Clamp Y between 0.0 and 1.0
                const y_val = @min(1.0, @max(0.0, gf));
                const y = height - margin_bottom - y_val * (height - margin_top - margin_bottom);

                if (i == 0) {
                    try writer.print("M {d:.2} {d:.2}", .{ x, y });
                } else {
                    try writer.print(" L {d:.2} {d:.2}", .{ x, y });
                }
            }
            try writer.writeAll("\" fill=\"none\" stroke=\"#1f77b4\" stroke-width=\"2\"/>\n");
        }

        try writer.writeAll("</svg>\n");
    }

    /// Renders a JSON specification of the plot data.
    pub fn renderJsonSpec(self: GcContentPlot, writer: anytype) !void {
        try writer.print(
            \\{{"title": "{s}", "x_label": "{s}", "y_label": "{s}", "type": "line_plot", "data": [
        , .{ self.title, self.x_label, self.y_label });
        for (self.gc_fractions, 0..) |gf, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{{\"window\": {}, \"gc\": {d:.4}}}", .{ self.window_sizes[i], gf });
        }
        try writer.writeAll("]}\n");
    }
};

/// Plot data for k-mer frequencies (e.g. top 10 k-mers).
pub const KmerFrequencyPlot = struct {
    kmers: []const []const u8,
    counts: []const u64,
    title: []const u8,

    pub fn init(kmers: []const []const u8, counts: []const u64, title: []const u8) KmerFrequencyPlot {
        return .{
            .kmers = kmers,
            .counts = counts,
            .title = title,
        };
    }

    /// Renders a deterministic SVG representation of the k-mer frequency bar chart.
    pub fn renderSvg(self: KmerFrequencyPlot, writer: anytype) !void {
        const width: f64 = 600.0;
        const height: f64 = 400.0;
        const margin_left: f64 = 80.0;
        const margin_right: f64 = 40.0;
        const margin_top: f64 = 50.0;
        const margin_bottom: f64 = 60.0;

        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
            \\<text x="{d}" y="{d}" font-family="sans-serif" font-size="16" font-weight="bold" text-anchor="middle" fill="#333333">{s}</text>
            \\<line x1="{d}" y1="{d}" x2="{d}" y2="{d}" stroke="#cccccc" stroke-width="1"/>
            \\<line x1="{d}" y1="{d}" x2="{d}" y2="{d}" stroke="#cccccc" stroke-width="1"/>
        , .{
            width, height, width, height,
            width / 2.0, margin_top - 20.0, self.title,
            margin_left, height - margin_bottom, width - margin_right, height - margin_bottom,
            margin_left, margin_top, margin_left, height - margin_bottom,
        });

        if (self.counts.len > 0) {
            var max_c: f64 = 0.0;
            for (self.counts) |c| {
                max_c = @max(max_c, @as(f64, @floatFromInt(c)));
            }
            if (max_c == 0.0) max_c = 1.0;

            const num_bars = self.kmers.len;
            const plot_w = width - margin_left - margin_right;
            const plot_h = height - margin_top - margin_bottom;
            const bar_spacing = plot_w / @as(f64, @floatFromInt(num_bars));
            const bar_w = bar_spacing * 0.7;

            for (self.counts, 0..) |c, i| {
                const val = @as(f64, @floatFromInt(c));
                const bar_h = (val / max_c) * plot_h;
                const x = margin_left + @as(f64, @floatFromInt(i)) * bar_spacing + (bar_spacing - bar_w) / 2.0;
                const y = height - margin_bottom - bar_h;

                // Draw bar
                try writer.print(
                    \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" fill="#2ca02c"/>
                    \\<text x="{d:.2}" y="{d:.2}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#333333" transform="rotate(45 {d:.2} {d:.2})">{s}</text>
                    \\<text x="{d:.2}" y="{d:.2}" font-family="sans-serif" font-size="9" text-anchor="middle" fill="#666666">{d}</text>
                , .{
                    x, y, bar_w, bar_h,
                    x + bar_w / 2.0, height - margin_bottom + 15.0, x + bar_w / 2.0, height - margin_bottom + 15.0, self.kmers[i],
                    x + bar_w / 2.0, y - 5.0, c,
                });
            }
        }

        try writer.writeAll("</svg>\n");
    }

    /// Renders a JSON specification of the plot data.
    pub fn renderJsonSpec(self: KmerFrequencyPlot, writer: anytype) !void {
        try writer.print(
            \\{{"title": "{s}", "type": "bar_chart", "data": [
        , .{self.title});
        for (self.counts, 0..) |c, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{{\"kmer\": \"{s}\", \"count\": {}}}", .{ self.kmers[i], c });
        }
        try writer.writeAll("]}\n");
    }
};

/// Plot data for read coverage depth across a genomic region.
pub const CoveragePlot = struct {
    positions: []const u32,
    depths: []const u32,
    title: []const u8,

    pub fn init(positions: []const u32, depths: []const u32, title: []const u8) CoveragePlot {
        return .{
            .positions = positions,
            .depths = depths,
            .title = title,
        };
    }

    /// Renders a deterministic SVG representation of the coverage area chart.
    pub fn renderSvg(self: CoveragePlot, writer: anytype) !void {
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
        , .{
            width, height, width, height,
            width / 2.0, margin_top - 20.0, self.title,
            margin_left, height - margin_bottom, width - margin_right, height - margin_bottom,
            margin_left, margin_top, margin_left, height - margin_bottom,
        });

        if (self.positions.len > 1) {
            var min_p = self.positions[0];
            var max_p = min_p;
            for (self.positions) |p| {
                min_p = @min(min_p, p);
                max_p = @max(max_p, p);
            }
            const p_range = @as(f64, @floatFromInt(if (max_p == min_p) 1 else max_p - min_p));

            var max_d: f64 = 0.0;
            for (self.depths) |d| {
                max_d = @max(max_d, @as(f64, @floatFromInt(d)));
            }
            if (max_d == 0.0) max_d = 1.0;

            const plot_w = width - margin_left - margin_right;
            const plot_h = height - margin_top - margin_bottom;

            // Plot area path
            try writer.writeAll("<path d=\"");
            for (self.positions, 0..) |p, i| {
                const x_val = @as(f64, @floatFromInt(p));
                const x = margin_left + ((x_val - @as(f64, @floatFromInt(min_p))) / p_range) * plot_w;
                const y_val = @as(f64, @floatFromInt(self.depths[i]));
                const y = height - margin_bottom - (y_val / max_d) * plot_h;

                if (i == 0) {
                    try writer.print("M {d:.2} {d:.2}", .{ x, height - margin_bottom });
                    try writer.print(" L {d:.2} {d:.2}", .{ x, y });
                } else {
                    try writer.print(" L {d:.2} {d:.2}", .{ x, y });
                }
            }
            // Close the path to the baseline
            const last_x = margin_left + ((@as(f64, @floatFromInt(self.positions[self.positions.len - 1])) - @as(f64, @floatFromInt(min_p))) / p_range) * plot_w;
            try writer.print(" L {d:.2} {d:.2} Z\" fill=\"#d62728\" fill-opacity=\"0.3\" stroke=\"#d62728\" stroke-width=\"1.5\"/>\n", .{ last_x, height - margin_bottom });
        }

        try writer.writeAll("</svg>\n");
    }

    /// Renders a JSON specification of the plot data.
    pub fn renderJsonSpec(self: CoveragePlot, writer: anytype) !void {
        try writer.print(
            \\{{"title": "{s}", "type": "area_chart", "data": [
        , .{self.title});
        for (self.depths, 0..) |d, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{{\"position\": {}, \"depth\": {}}}", .{ self.positions[i], d });
        }
        try writer.writeAll("]}\n");
    }
};

test "Sequence plots SVG and JSON emission" {
    const window_sizes = [_]usize{ 100, 200, 300, 400 };
    const gc_fractions = [_]f64{ 0.45, 0.52, 0.49, 0.41 };
    const plot = GcContentPlot.init(&window_sizes, &gc_fractions, "GC Profile", "Position", "GC Ratio");

    var buf: [1024]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try plot.renderSvg(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);

    var fbs_json = std.Io.Writer.fixed(&buf);
    try plot.renderJsonSpec(&fbs_json);
    try std.testing.expect(fbs_json.buffered().len > 0);
}
