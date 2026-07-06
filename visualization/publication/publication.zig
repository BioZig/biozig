const std = @import("std");

/// Represents a citation reference in a publication.
pub const Reference = struct {
    key: []const u8,
    authors: []const u8,
    title: []const u8,
    journal: []const u8,
    year: u32,
    volume: ?[]const u8 = null,
    pages: ?[]const u8 = null,

    pub fn init(
        key: []const u8,
        authors: []const u8,
        title: []const u8,
        journal: []const u8,
        year: u32,
        volume: ?[]const u8,
        pages: ?[]const u8,
    ) Reference {
        return .{
            .key = key,
            .authors = authors,
            .title = title,
            .journal = journal,
            .year = year,
            .volume = volume,
            .pages = pages,
        };
    }
};

/// Represents a figure caption.
pub const Caption = struct {
    text: []const u8,

    pub fn init(text: []const u8) Caption {
        return .{ .text = text };
    }
};

/// Represents a single panel inside a multi-panel figure.
pub const Panel = struct {
    /// Panel label (e.g. "A", "B")
    label: []const u8,
    /// Raw SVG code representing this panel
    svg_content: []const u8,

    pub fn init(label: []const u8, svg_content: []const u8) Panel {
        return .{
            .label = label,
            .svg_content = svg_content,
        };
    }
};

/// Represents a publication figure. Can contain multiple panels and reference citations.
pub const Figure = struct {
    number: usize,
    label: []const u8, // e.g. "Figure 1"
    caption: Caption,
    panels: []const Panel,
    references: []const Reference,

    pub fn init(
        number: usize,
        label: []const u8,
        caption: Caption,
        panels: []const Panel,
        references: []const Reference,
    ) Figure {
        return .{
            .number = number,
            .label = label,
            .caption = caption,
            .panels = panels,
            .references = references,
        };
    }

    /// Composes all panels into a single multi-panel SVG layout.
    /// Arranges them in columns (defaults to 2 columns).
    pub fn composeSvg(self: Figure, writer: anytype) !void {
        const panels_count = self.panels.len;
        if (panels_count == 0) return;

        const cols: usize = if (panels_count >= 2) 2 else 1;
        const rows = (panels_count + cols - 1) / cols;

        // Assume standard size per panel (e.g. 600 x 400)
        const panel_w: f64 = 600.0;
        const panel_h: f64 = 400.0;

        const total_w = panel_w * @as(f64, @floatFromInt(cols));
        const total_h = panel_h * @as(f64, @floatFromInt(rows));

        try writer.print(
            \\<svg width="{d}" height="{d}" viewBox="0 0 {d} {d}" xmlns="http://www.w3.org/2000/svg">
            \\<rect width="100%" height="100%" fill="#ffffff"/>
        , .{ total_w, total_h, total_w, total_h });

        for (self.panels, 0..) |panel, i| {
            const col = i % cols;
            const row = i / cols;
            const x = @as(f64, @floatFromInt(col)) * panel_w;
            const y = @as(f64, @floatFromInt(row)) * panel_h;

            // Nest the panel SVG inside a sub-group translation
            try writer.print(
                \\<g transform="translate({d:.2}, {d:.2})">
            , .{ x, y });

            // Write raw panel SVG (stripping XML header/SVG wrapper if present is nice,
            // but SVG parser allows nesting <svg> elements inside <g> directly!)
            // To ensure compatibility, we just embed the svg content inside a nested <svg> element.
            try writer.print(
                \\<svg x="0" y="0" width="{d}" height="{d}">
                \\{s}
                \\</svg>
            , .{ panel_w, panel_h, panel.svg_content });

            // Draw panel label (e.g. "A") in bold at the top left corner
            try writer.print(
                \\<text x="15" y="25" font-family="sans-serif" font-size="18" font-weight="bold" fill="#000000">{s}</text>
            , .{panel.label});

            try writer.writeAll("</g>\n");
        }

        try writer.writeAll("</svg>\n");
    }
};

/// A list of figures forming a composite figure view.
pub const CompositeFigure = struct {
    figures: []const Figure,

    pub fn init(figures: []const Figure) CompositeFigure {
        return .{ .figures = figures };
    }
};

/// Represents a publication table.
pub const Table = struct {
    number: usize,
    label: []const u8, // e.g. "Table 1"
    headers: []const []const u8,
    rows: []const []const []const u8,
    caption: Caption,

    pub fn init(
        number: usize,
        label: []const u8,
        headers: []const []const u8,
        rows: []const []const []const u8,
        caption: Caption,
    ) Table {
        return .{
            .number = number,
            .label = label,
            .headers = headers,
            .rows = rows,
            .caption = caption,
        };
    }
};

test "Publication layouts and compositing" {
    const p1 = Panel.init("A", "<rect x=\"50\" y=\"50\" width=\"100\" height=\"100\" fill=\"blue\"/>");
    const p2 = Panel.init("B", "<circle cx=\"100\" cy=\"100\" r=\"50\" fill=\"red\"/>");
    const panels = [_]Panel{ p1, p2 };

    const ref = Reference.init("Ref1", "Smith et al.", "A Bio Study", "J. Bio.", 2026, "10", "12-34");
    const refs = [_]Reference{ref};

    const fig = Figure.init(
        1,
        "Figure 1",
        Caption.init("Diagram of blue square and red circle."),
        &panels,
        &refs,
    );

    var buf: [2048]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try fig.composeSvg(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
