const std = @import("std");
const reporting = @import("../reporting.zig");

/// Helper to escape special LaTeX characters to ensure the output is valid and compilable.
pub fn writeEscaped(writer: anytype, text: []const u8) !void {
    for (text) |c| {
        switch (c) {
            '&', '%', '$', '#', '_', '{', '}' => {
                try writer.writeByte('\\');
                try writer.writeByte(c);
            },
            '~' => try writer.writeAll("\\textasciitilde{}"),
            '^' => try writer.writeAll("\\textasciicircum{}"),
            '\\' => try writer.writeAll("\\textbackslash{}"),
            else => try writer.writeByte(c),
        }
    }
}

/// Deterministically exports a Report to a compilable LaTeX document.
pub fn exportLatex(report: reporting.Report, writer: anytype) !void {
    // 1. Preamble
    try writer.writeAll(
        \\\documentclass{article}
        \\\usepackage[utf8]{inputenc}
        \\\usepackage{booktabs}
        \\\usepackage{graphicx}
        \\\usepackage{amsmath}
        \\\usepackage{hyperref}
        \\\usepackage{verbatim}
        \\
    );

    // Title & Author
    try writer.writeAll("\\title{");
    try writeEscaped(writer, report.title);
    try writer.writeAll("}\n\\author{");
    try writeEscaped(writer, report.authors);
    try writer.writeAll("}\n\\date{\\today}\n\n\\begin{document}\n\\maketitle\n\n");

    // 2. Abstract
    if (report.abstract.len > 0) {
        try writer.writeAll("\\begin{abstract}\n");
        try writeEscaped(writer, report.abstract);
        try writer.writeAll("\n\\end{abstract}\n\n");
    }

    // 3. Sections
    for (report.sections) |sec| {
        try writer.writeAll("\\section{");
        try writeEscaped(writer, sec.title);
        try writer.writeAll("}\n");
        try writeEscaped(writer, sec.content);
        try writer.writeAll("\n\n");
    }

    // 4. Figures
    if (report.figures.len > 0) {
        for (report.figures) |fig| {
            try writer.print(
                \\\begin{{figure}}[htbp]
                \\\centering
                \\% \includegraphics[width=0.8\textwidth]{{figure_{}.pdf}}
                \\\caption{{
            , .{fig.number});
            try writeEscaped(writer, fig.caption.text);
            try writer.print(
                \\}}
                \\\label{{fig:figure_{}}}
                \\\end{{figure}}
                \\
                \\
            , .{fig.number});
        }
    }

    // 5. Tables
    if (report.tables.len > 0) {
        for (report.tables) |tbl| {
            try writer.writeAll("\\begin{table}[htbp]\n\\centering\n\\caption{");
            try writeEscaped(writer, tbl.caption.text);
            try writer.print("}}\n\\label{{tab:table_{}}}\n", .{tbl.number});

            // Calculate tabular column alignment spec: "l l l"
            try writer.writeAll("\\begin{tabular}{");
            for (tbl.headers) |_| {
                try writer.writeAll("l ");
            }
            try writer.writeAll("}\n\\toprule\n");

            // Write headers
            for (tbl.headers, 0..) |h, i| {
                if (i > 0) try writer.writeAll(" & ");
                try writeEscaped(writer, h);
            }
            try writer.writeAll(" \\\\\n\\midrule\n");

            // Write rows
            for (tbl.rows) |row| {
                for (row, 0..) |cell, i| {
                    if (i > 0) try writer.writeAll(" & ");
                    try writeEscaped(writer, cell);
                }
                try writer.writeAll(" \\\\\n");
            }
            try writer.writeAll("\\bottomrule\n\\end{tabular}\n\\end{table}\n\n");
        }
    }

    // 6. References
    if (report.references.len > 0) {
        try writer.writeAll("\\begin{thebibliography}{99}\n");
        for (report.references) |ref| {
            try writer.print("\\bibitem{{{s}}} ", .{ref.key});
            try writeEscaped(writer, ref.authors);
            try writer.writeAll(". \"");
            try writeEscaped(writer, ref.title);
            try writer.writeAll("\". \\emph{");
            try writeEscaped(writer, ref.journal);
            try writer.print("}} ({}), ", .{ref.year});
            if (ref.volume) |v| {
                try writer.writeAll("Vol. ");
                try writeEscaped(writer, v);
            }
            if (ref.pages) |p| {
                try writer.writeAll(", pp. ");
                try writeEscaped(writer, p);
            }
            try writer.writeAll(".\n");
        }
        try writer.writeAll("\\end{thebibliography}\n\n");
    }

    // 7. Reproducibility metadata block
    if (report.reproducibility) |rec| {
        try writer.writeAll("\\section{Reproducibility \\& Execution Metadata}\n\\begin{verbatim}\n");
        try writer.print("Timestamp: {}\n", .{rec.timestamp});
        try writer.print("Compiler Version: {s}\n", .{rec.compiler_version});
        try writer.print("Platform OS: {s}\n", .{rec.target_os});
        try writer.print("Platform CPU: {s}\n", .{rec.target_cpu});
        try writer.print("Random Seed: 0x{x}\n", .{rec.random_seed});

        if (rec.inputs.items.len > 0) {
            try writer.writeAll("\nInput Files:\n");
            for (rec.inputs.items) |inp| {
                const hex_hash = std.fmt.bytesToHex(inp.hash, .lower);
                try writer.print("  - {s} : {s}\n", .{ inp.path, &hex_hash });
            }
        }
        if (rec.outputs.items.len > 0) {
            try writer.writeAll("\nOutput Files:\n");
            for (rec.outputs.items) |out| {
                const hex_hash = std.fmt.bytesToHex(out.hash, .lower);
                try writer.print("  - {s} : {s}\n", .{ out.path, &hex_hash });
            }
        }
        try writer.writeAll("\\end{verbatim}\n");
    }

    try writer.writeAll("\\end{document}\n");
}

test "LaTeX report generation" {
    const pub_mod = @import("visualization").publication;
    const sec = reporting.Section{ .title = "Introduction", .content = "This is research on DNA & RNA." };
    const sections = [_]reporting.Section{sec};

    const report = reporting.Report.init(
        "Study & Results",
        "Author & Partner",
        "Abstract content...",
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
    try exportLatex(report, &fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
