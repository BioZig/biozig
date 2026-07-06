const std = @import("std");
const reporting = @import("../reporting.zig");

/// Deterministically exports a Report to a Markdown formatted document.
pub fn exportMarkdown(report: reporting.Report, writer: anytype) !void {
    // 1. Title, Authors, and Abstract
    try writer.print("# {s}\n\n", .{report.title});
    try writer.print("**Authors:** {s}\n\n", .{report.authors});
    if (report.abstract.len > 0) {
        try writer.print("## Abstract\n\n{s}\n\n", .{report.abstract});
    }

    // 2. Sections
    for (report.sections) |sec| {
        try writer.print("## {s}\n\n{s}\n\n", .{ sec.title, sec.content });
    }

    // 3. Figures
    if (report.figures.len > 0) {
        try writer.writeAll("## Figures\n\n");
        for (report.figures) |fig| {
            try writer.print("### {s}\n\n", .{fig.label});
            try writer.print("*{s}*\n\n", .{fig.caption.text});
            // Embed placeholder for figure in markdown
            try writer.print("![{s}](media/figure_{}.svg)\n\n", .{ fig.label, fig.number });
        }
    }

    // 4. Tables
    if (report.tables.len > 0) {
        try writer.writeAll("## Tables\n\n");
        for (report.tables) |tbl| {
            try writer.print("### {s}\n\n", .{tbl.label});
            try writer.print("*{s}*\n\n", .{tbl.caption.text});

            // Render table headers
            try writer.writeAll("|");
            for (tbl.headers) |h| {
                try writer.print(" {s} |", .{h});
            }
            try writer.writeAll("\n|");
            for (tbl.headers) |_| {
                try writer.writeAll("---|");
            }
            try writer.writeAll("\n");

            // Render table rows
            for (tbl.rows) |row| {
                try writer.writeAll("|");
                for (row) |cell| {
                    try writer.print(" {s} |", .{cell});
                }
                try writer.writeAll("\n");
            }
            try writer.writeAll("\n");
        }
    }

    // 5. References
    if (report.references.len > 0) {
        try writer.writeAll("## References\n\n");
        for (report.references) |ref| {
            try writer.print("- **[{s}]** {s}. \"{s}\". *{s}* ({}), ", .{
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
            try writer.writeAll(".\n");
        }
        try writer.writeAll("\n");
    }

    // 6. Reproducibility metadata block
    if (report.reproducibility) |rec| {
        try writer.writeAll("## Reproducibility & Execution Metadata\n\n");
        try writer.print("- **Timestamp:** {}\n", .{rec.timestamp});
        try writer.print("- **Compiler Version:** {s}\n", .{rec.compiler_version});
        try writer.print("- **Platform OS:** {s}\n", .{rec.target_os});
        try writer.print("- **Platform CPU:** {s}\n", .{rec.target_cpu});
        try writer.print("- **Random Seed:** 0x{x}\n", .{rec.random_seed});

        if (rec.inputs.items.len > 0) {
            try writer.writeAll("\n### Input Files\n\n");
            try writer.writeAll("| File Path | SHA256 Hash |\n|---|---|\n");
            for (rec.inputs.items) |inp| {
                const hex_hash = std.fmt.bytesToHex(inp.hash, .lower);
                try writer.print("| `{s}` | `{s}` |\n", .{ inp.path, &hex_hash });
            }
        }

        if (rec.outputs.items.len > 0) {
            try writer.writeAll("\n### Output Files\n\n");
            try writer.writeAll("| File Path | SHA256 Hash |\n|---|---|\n");
            for (rec.outputs.items) |out| {
                const hex_hash = std.fmt.bytesToHex(out.hash, .lower);
                try writer.print("| `{s}` | `{s}` |\n", .{ out.path, &hex_hash });
            }
        }
    }
}

test "Markdown report generation" {
    const pub_mod = @import("visualization").publication;

    const ref = pub_mod.Reference.init("Key1", "Author A", "Paper Title", "Bio J", 2026, null, null);
    const refs = [_]pub_mod.Reference{ref};

    const sec = reporting.Section{ .title = "Introduction", .content = "This is the introduction." };
    const sections = [_]reporting.Section{sec};

    const report = reporting.Report.init(
        "Study Title",
        "Researcher X",
        "This is the abstract.",
        &sections,
        &[_]pub_mod.Figure{},
        &[_]pub_mod.Table{},
        &refs,
        &[_]pub_mod.Figure{},
        &[_]pub_mod.Table{},
        null,
    );

    var buf: [8192]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try exportMarkdown(report, &fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
