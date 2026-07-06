const std = @import("std");
const reporting = @import("../reporting.zig");

/// Escapes parentheses and backslashes in PDF string literals.
fn writePdfString(writer: anytype, text: []const u8) !void {
    try writer.writeByte('(');
    for (text) |c| {
        if (c == '(' or c == ')' or c == '\\') {
            try writer.writeByte('\\');
        }
        try writer.writeByte(c);
    }
    try writer.writeByte(')');
}

/// Deterministically generates a compliant, stand-alone PDF report from the Report structure.
/// Calculates byte offsets dynamically to write a valid cross-reference (xref) table.
pub fn exportPdf(report: reporting.Report, writer: anytype, allocator: std.mem.Allocator) !void {
    var alloc_writer = std.Io.Writer.Allocating.init(allocator);
    defer alloc_writer.deinit();
    const w = &alloc_writer.writer;

    var offsets = std.ArrayList(usize).empty;
    defer offsets.deinit(allocator);

    // PDF Header
    try w.writeAll("%PDF-1.4\n");

    // 1. Catalog Object (1 0 obj)
    try offsets.append(allocator, alloc_writer.written().len);
    try w.writeAll("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

    // 2. Pages Tree Object (2 0 obj)
    try offsets.append(allocator, alloc_writer.written().len);
    try w.writeAll("2 0 obj\n<< /Type /Pages /Kids [ 3 0 R ] /Count 1 >>\nendobj\n");

    // 3. Page Object (3 0 obj)
    try offsets.append(allocator, alloc_writer.written().len);
    try w.writeAll("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [ 0 0 595.28 841.89 ] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n");

    // 4. Font Object (4 0 obj)
    try offsets.append(allocator, alloc_writer.written().len);
    try w.writeAll("4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");

    // 5. Generate content stream data
    var stream_writer = std.Io.Writer.Allocating.init(allocator);
    defer stream_writer.deinit();
    const sw = &stream_writer.writer;

    try sw.writeAll("BT\n/F1 16 Tf\n72 750 Td\n");
    try writePdfString(sw, report.title);
    try sw.writeAll(" Tj\n");

    try sw.writeAll("0 -24 Td\n/F1 11 Tf\n");
    try sw.writeAll("() Tj\n0 -14 Td\n");
    try sw.writeAll("(Authors: ) Tj\n0 0 Td\n");
    try writePdfString(sw, report.authors);
    try sw.writeAll(" Tj\n");

    if (report.abstract.len > 0) {
        try sw.writeAll("0 -30 Td\n/F1 12 Tf\n(Abstract) Tj\n0 -16 Td\n/F1 10 Tf\n");
        // Simple paragraph wrapper for abstract
        try writePdfString(sw, report.abstract);
        try sw.writeAll(" Tj\n");
    }

    // Write sections
    for (report.sections) |sec| {
        try sw.writeAll("0 -30 Td\n/F1 12 Tf\n");
        try writePdfString(sw, sec.title);
        try sw.writeAll(" Tj\n0 -16 Td\n/F1 10 Tf\n");
        try writePdfString(sw, sec.content);
        try sw.writeAll(" Tj\n");
    }

    try sw.writeAll("ET\n");

    // 6. Contents Stream Object (5 0 obj)
    try offsets.append(allocator, alloc_writer.written().len);
    try w.print("5 0 obj\n<< /Length {} >>\nstream\n", .{stream_writer.written().len});
    try w.writeAll(stream_writer.written());
    try w.writeAll("\nendstream\nendobj\n");

    // 7. Xref Table
    const xref_offset = alloc_writer.written().len;
    try w.print("xref\n0 {}\n", .{offsets.items.len + 1});
    try w.writeAll("0000000000 65535 f \n");
    for (offsets.items) |offset| {
        try w.print("{0:0>10} 00000 n \n", .{offset});
    }

    // 8. Trailer and EOF
    try w.print("trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{}\n%%EOF\n", .{ offsets.items.len + 1, xref_offset });

    // Output all compiled bytes to the target writer
    try writer.writeAll(alloc_writer.written());
}

test "PDF report generation validation" {
    const allocator = std.testing.allocator;
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

    var buf: [4096]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try exportPdf(report, &fbs, allocator);
    try std.testing.expect(fbs.buffered().len > 0);
}
