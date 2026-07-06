const std = @import("std");
const reporting = @import("../reporting.zig");

/// Deterministically exports a Report to a self-contained static HTML document.
pub fn exportHtml(report: reporting.Report, writer: anytype) !void {
    // HTML Header and styles
    try writer.print(
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\  <meta charset="UTF-8">
        \\  <title>{s}</title>
        \\  <style>
        \\    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333333; max-width: 850px; margin: 40px auto; padding: 0 20px; }}
        \\    h1 {{ border-bottom: 2px solid #eaecef; padding-bottom: 10px; color: #111111; }}
        \\    h2 {{ border-bottom: 1px solid #eaecef; padding-bottom: 5px; color: #222222; margin-top: 30px; }}
        \\    .authors {{ font-size: 1.1em; color: #555555; margin-bottom: 20px; }}
        \\    .abstract {{ background: #f6f8fa; padding: 15px; border-radius: 6px; margin: 20px 0; border-left: 4px solid #0366d6; }}
        \\    .figure {{ border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px; margin: 30px 0; text-align: center; background: #fafbfc; }}
        \\    .figure svg {{ max-width: 100%; height: auto; }}
        \\    .caption {{ font-size: 0.95em; font-style: italic; color: #586069; margin-top: 10px; }}
        \\    table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        \\    th, td {{ border: 1px solid #dfe2e5; padding: 8px 12px; text-align: left; }}
        \\    th {{ background-color: #f6f8fa; }}
        \\    .reproducibility {{ background-color: #f9fdf9; border: 1px solid #d4ebd4; border-radius: 6px; padding: 20px; margin-top: 40px; }}
        \\    .reproducibility h3 {{ color: #228b22; margin-top: 0; }}
        \\    .code-block {{ background-color: #f6f8fa; padding: 10px; border-radius: 4px; font-family: monospace; font-size: 0.9em; }}
        \\  </style>
        \\</head>
        \\<body>
        \\  <h1>{s}</h1>
        \\  <div class="authors"><strong>Authors:</strong> {s}</div>
        \\
    , .{ report.title, report.title, report.authors });

    // Abstract
    if (report.abstract.len > 0) {
        try writer.print(
            \\  <div class="abstract">
            \\    <h3>Abstract</h3>
            \\    <p>{s}</p>
            \\  </div>
            \\
        , .{report.abstract});
    }

    // Sections
    for (report.sections) |sec| {
        try writer.print(
            \\  <h2>{s}</h2>
            \\  <p>{s}</p>
            \\
        , .{ sec.title, sec.content });
    }

    // Figures (Composed inline SVGs)
    if (report.figures.len > 0) {
        try writer.writeAll("  <h2>Figures</h2>\n");
        for (report.figures) |fig| {
            try writer.print(
                \\  <div id="figure_{}" class="figure">
                \\
            , .{fig.number});

            // Inline the multi-panel composed SVG directly!
            try fig.composeSvg(writer);

            try writer.print(
                \\    <div class="caption"><strong>{s}:</strong> {s}</div>
                \\  </div>
                \\
            , .{ fig.label, fig.caption.text });
        }
    }

    // Tables
    if (report.tables.len > 0) {
        try writer.writeAll("  <h2>Tables</h2>\n");
        for (report.tables) |tbl| {
            try writer.print(
                \\  <div id="table_{}">
                \\    <div class="caption"><strong>{s}:</strong> {s}</div>
                \\    <table>
                \\      <thead>
                \\        <tr>
                \\
            , .{ tbl.number, tbl.label, tbl.caption.text });

            for (tbl.headers) |h| {
                try writer.print("          <th>{s}</th>\n", .{h});
            }
            try writer.writeAll(
                \\        </tr>
                \\      </thead>
                \\      <tbody>
                \\
            );

            for (tbl.rows) |row| {
                try writer.writeAll("        <tr>\n");
                for (row) |cell| {
                    try writer.print("          <td>{s}</td>\n", .{cell});
                }
                try writer.writeAll("        </tr>\n");
            }

            try writer.writeAll(
                \\      </tbody>
                \\    </table>
                \\  </div>
                \\
            );
        }
    }

    // References
    if (report.references.len > 0) {
        try writer.writeAll("  <h2>References</h2>\n  <ul>\n");
        for (report.references) |ref| {
            try writer.print("    <li id=\"ref_{s}\"><strong>[{s}]</strong> {s}. \"{s}\". <em>{s}</em> ({}), ", .{
                ref.key,
                ref.key,
                ref.authors,
                ref.title,
                ref.journal,
                ref.year,
            });
            if (ref.volume) |v| {
                try writer.print("Vol. {s}", .{v});
            }
            if (ref.pages) |p| {
                try writer.print(", pp. {s}", .{p});
            }
            try writer.writeAll(".</li>\n");
        }
        try writer.writeAll("  </ul>\n");
    }

    // Reproducibility Metadata
    if (report.reproducibility) |rec| {
        try writer.writeAll(
            \\  <div class="reproducibility">
            \\    <h3>Reproducibility &amp; Execution Metadata</h3>
            \\
        );
        try writer.print("    <p><strong>Timestamp:</strong> {}</p>\n", .{rec.timestamp});
        try writer.print("    <p><strong>Compiler Version:</strong> <code>{s}</code></p>\n", .{rec.compiler_version});
        try writer.print("    <p><strong>Platform CPU:</strong> <code>{s}</code></p>\n", .{rec.target_cpu});
        try writer.print("    <p><strong>Platform OS:</strong> <code>{s}</code></p>\n", .{rec.target_os});
        try writer.print("    <p><strong>Random Seed:</strong> <code>0x{x}</code></p>\n", .{rec.random_seed});

        if (rec.inputs.items.len > 0) {
            try writer.writeAll("    <h4>Input Datasets</h4>\n    <table>\n      <thead><tr><th>File Path</th><th>SHA256 Hash</th></tr></thead>\n      <tbody>\n");
            for (rec.inputs.items) |inp| {
                const hex_hash = std.fmt.bytesToHex(inp.hash, .lower);
                try writer.print("        <tr><td><code>{s}</code></td><td><code>{s}</code></td></tr>\n", .{ inp.path, &hex_hash });
            }
            try writer.writeAll("      </tbody>\n    </table>\n");
        }

        if (rec.outputs.items.len > 0) {
            try writer.writeAll("    <h4>Output Artifacts</h4>\n    <table>\n      <thead><tr><th>File Path</th><th>SHA256 Hash</th></tr></thead>\n      <tbody>\n");
            for (rec.outputs.items) |out| {
                const hex_hash = std.fmt.bytesToHex(out.hash, .lower);
                try writer.print("        <tr><td><code>{s}</code></td><td><code>{s}</code></td></tr>\n", .{ out.path, &hex_hash });
            }
            try writer.writeAll("      </tbody>\n    </table>\n");
        }
        try writer.writeAll("  </div>\n");
    }

    try writer.writeAll("</body>\n</html>\n");
}

test "HTML report generation" {
    const pub_mod = @import("visualization").publication;
    const sec = reporting.Section{ .title = "Results", .content = "These are the results." };
    const sections = [_]reporting.Section{sec};

    const report = reporting.Report.init(
        "Study Title",
        "Researcher X",
        "Abstract...",
        &sections,
        &[_]pub_mod.Figure{},
        &[_]pub_mod.Table{},
        &[_]pub_mod.Reference{},
        &[_]pub_mod.Figure{},
        &[_]pub_mod.Table{},
        null,
    );

    var buf: [8192]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try exportHtml(report, &fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
