const std = @import("std");
const pub_mod = @import("visualization").publication;

/// Represents supplementary research materials.
pub const Supplement = struct {
    supplement_figures: []const pub_mod.Figure,
    supplement_tables: []const pub_mod.Table,
    config_snapshot_json: []const u8, // JSON representation of the configuration snapshot

    /// Initializes a Supplement.
    pub fn init(
        figs: []const pub_mod.Figure,
        tabs: []const pub_mod.Table,
        config_json: []const u8,
    ) Supplement {
        return .{
            .supplement_figures = figs,
            .supplement_tables = tabs,
            .config_snapshot_json = config_json,
        };
    }

    /// Exports supplementary figures, tables, and config snapshots as Markdown.
    pub fn exportMarkdown(self: Supplement, writer: anytype) !void {
        try writer.writeAll("# Supplementary Material\n\n");

        if (self.supplement_figures.len > 0) {
            try writer.writeAll("## Supplementary Figures\n\n");
            for (self.supplement_figures) |fig| {
                try writer.print("### {s}\n\n*{s}*\n\n", .{ fig.label, fig.caption.text });
                try writer.print("![{s}](media/supp_figure_{}.svg)\n\n", .{ fig.label, fig.number });
            }
        }

        if (self.supplement_tables.len > 0) {
            try writer.writeAll("## Supplementary Tables\n\n");
            for (self.supplement_tables) |tbl| {
                try writer.print("### {s}\n\n*{s}*\n\n", .{ tbl.label, tbl.caption.text });

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

        if (self.config_snapshot_json.len > 0) {
            try writer.print("## Configuration Snapshot\n\n```json\n{s}\n```\n", .{self.config_snapshot_json});
        }
    }
};

test "Supplement markdown generation" {
    const sec = pub_mod.Caption.init("Supplementary Caption");
    const fig = pub_mod.Figure.init(1, "Supp Fig 1", sec, &[_]pub_mod.Panel{}, &[_]pub_mod.Reference{});
    const figs = [_]pub_mod.Figure{fig};

    const supp = Supplement.init(&figs, &[_]pub_mod.Table{}, "{\"learning_rate\":0.001}");

    var buf: [8192]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try supp.exportMarkdown(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
