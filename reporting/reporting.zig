const std = @import("std");

pub const markdown = @import("markdown/markdown.zig");
pub const html = @import("html/html.zig");
pub const pdf = @import("pdf/pdf.zig");
pub const latex = @import("latex/latex.zig");
pub const manuscript = @import("manuscript/manuscript.zig");
pub const supplement = @import("supplement/supplement.zig");

test {
    // Force compilation and execution of submodule tests
    _ = markdown;
    _ = html;
    _ = pdf;
    _ = latex;
    _ = manuscript;
    _ = supplement;
}

/// Represents a numbered section in a report.
pub const Section = struct {
    title: []const u8,
    content: []const u8,
};

/// Structured report container consolidating scientific narratives, visualizations, and reproducibility metrics.
pub const Report = struct {
    title: []const u8,
    authors: []const u8,
    abstract: []const u8,
    sections: []const Section,
    figures: []const @import("visualization").publication.Figure,
    tables: []const @import("visualization").publication.Table,
    references: []const @import("visualization").publication.Reference,
    supplement_figures: []const @import("visualization").publication.Figure,
    supplement_tables: []const @import("visualization").publication.Table,
    reproducibility: ?*@import("core").reproducibility.ReproducibilityRecord,

    /// Initializes a Report container.
    pub fn init(
        title: []const u8,
        authors: []const u8,
        abstract: []const u8,
        sections: []const Section,
        figures: []const @import("visualization").publication.Figure,
        tables: []const @import("visualization").publication.Table,
        references: []const @import("visualization").publication.Reference,
        supplement_figures: []const @import("visualization").publication.Figure,
        supplement_tables: []const @import("visualization").publication.Table,
        reproducibility: ?*@import("core").reproducibility.ReproducibilityRecord,
    ) Report {
        return .{
            .title = title,
            .authors = authors,
            .abstract = abstract,
            .sections = sections,
            .figures = figures,
            .tables = tables,
            .references = references,
            .supplement_figures = supplement_figures,
            .supplement_tables = supplement_tables,
            .reproducibility = reproducibility,
        };
    }
};

test "Master Report Compilation and Exporters Integration" {
    const allocator = std.testing.allocator;
    const pub_mod = @import("visualization").publication;
    const core = @import("core");

    // 1. Setup reproducibility record
    var record = try core.reproducibility.ReproducibilityRecord.init(allocator, 0x12345);
    defer record.deinit();
    try record.trackInputData("raw_data.fa", ">seq\nACGTACGT");
    try record.trackOutputData("report.html", "<html>...</html>");
    try record.addMetadata("analysis_pipeline", "deconvolve");

    // 2. Setup visual assets
    const p1 = pub_mod.Panel.init("A", "<circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"blue\"/>");
    const p2 = pub_mod.Panel.init("B", "<rect x=\"10\" y=\"10\" width=\"80\" height=\"80\" fill=\"red\"/>");
    const panels = [_]pub_mod.Panel{ p1, p2 };
    const ref = pub_mod.Reference.init("Key1", "Smith et al.", "Studies in GVAE", "J. Bio.", 2026, null, null);
    const refs = [_]pub_mod.Reference{ref};

    const fig1 = pub_mod.Figure.init(
        1,
        "Figure 1",
        pub_mod.Caption.init("Composed scatter and shape visuals."),
        &panels,
        &refs,
    );
    const figures = [_]pub_mod.Figure{fig1};

    // 3. Setup tables
    const headers = [_][]const u8{ "Sample", "Value" };
    const r0 = [_][]const u8{ "Ctrl_1", "1.24" };
    const r1 = [_][]const u8{ "Treat_1", "4.56" };
    const rows = [_][]const []const u8{ &r0, &r1 };
    const tbl1 = pub_mod.Table.init(1, "Table 1", &headers, &rows, pub_mod.Caption.init("Experimental measurements."));
    const tables = [_]pub_mod.Table{tbl1};

    // 4. Setup narrative sections
    const sec1 = Section{ .title = "Introduction", .content = "Scientific research deconvolution details." };
    const sec2 = Section{ .title = "Results", .content = "High modular significance was observed in GATv2 latents." };
    const sections = [_]Section{ sec1, sec2 };

    // 5. Build full report
    const report = Report.init(
        "PPI Network Deconvolution via GVAE",
        "Arshad, M.",
        "Abstract explaining the Graph Attention network clustering.",
        &sections,
        &figures,
        &tables,
        &refs,
        &[_]pub_mod.Figure{},
        &[_]pub_mod.Table{},
        record,
    );

    // 6. Exercise all exporters and verify non-empty output
    var alloc_writer = std.Io.Writer.Allocating.init(allocator);
    defer alloc_writer.deinit();

    // Markdown
    alloc_writer.clearRetainingCapacity();
    try markdown.exportMarkdown(report, &alloc_writer.writer);
    try std.testing.expect(alloc_writer.written().len > 0);

    // HTML
    alloc_writer.clearRetainingCapacity();
    try html.exportHtml(report, &alloc_writer.writer);
    try std.testing.expect(alloc_writer.written().len > 0);

    // LaTeX
    alloc_writer.clearRetainingCapacity();
    try latex.exportLatex(report, &alloc_writer.writer);
    try std.testing.expect(alloc_writer.written().len > 0);

    // PDF
    alloc_writer.clearRetainingCapacity();
    try pdf.exportPdf(report, &alloc_writer.writer, allocator);
    try std.testing.expect(alloc_writer.written().len > 0);
}
