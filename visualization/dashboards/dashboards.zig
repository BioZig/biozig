const std = @import("std");

/// Types of widgets supported in a dashboard panel.
pub const WidgetType = enum(u8) {
    plot,
    table,
    text,
    metric,
};

/// Represents a widget displaying specific content.
pub const Widget = struct {
    id: []const u8,
    widget_type: WidgetType,
    title: []const u8,
    /// JSON serialization specification representing the content/data of this widget
    content_spec: []const u8,

    pub fn init(id: []const u8, w_type: WidgetType, title: []const u8, content_spec: []const u8) Widget {
        return .{
            .id = id,
            .widget_type = w_type,
            .title = title,
            .content_spec = content_spec,
        };
    }
};

/// Represents a dashboard panel positioned in a grid layout.
pub const Panel = struct {
    id: []const u8,
    title: []const u8,
    row: usize,
    col: usize,
    row_span: usize,
    col_span: usize,
    widget: Widget,

    pub fn init(
        id: []const u8,
        title: []const u8,
        row: usize,
        col: usize,
        row_span: usize,
        col_span: usize,
        widget: Widget,
    ) Panel {
        return .{
            .id = id,
            .title = title,
            .row = row,
            .col = col,
            .row_span = row_span,
            .col_span = col_span,
            .widget = widget,
        };
    }
};

/// Represents the overall dashboard model.
pub const Dashboard = struct {
    title: []const u8,
    panels: []const Panel,

    pub fn init(title: []const u8, panels: []const Panel) Dashboard {
        return .{
            .title = title,
            .panels = panels,
        };
    }

    /// Serializes the dashboard layout and panel widget specifications to JSON.
    pub fn serializeSpec(self: Dashboard, writer: anytype) !void {
        try writer.print(
            \\{{"dashboard_title": "{s}", "panels": [
        , .{self.title});
        for (self.panels, 0..) |panel, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print(
                \\{{"id": "{s}", "title": "{s}", "row": {}, "col": {}, "row_span": {}, "col_span": {}, "widget": {{"id": "{s}", "type": "{s}", "title": "{s}", "spec": {s}}}}}
            , .{
                panel.id,
                panel.title,
                panel.row,
                panel.col,
                panel.row_span,
                panel.col_span,
                panel.widget.id,
                @tagName(panel.widget.widget_type),
                panel.widget.title,
                panel.widget.content_spec,
            });
        }
        try writer.writeAll("]}\n");
    }
};

test "Dashboard model and serialization" {
    const w = Widget.init("w1", .plot, "GC Plot", "{\"type\":\"line\"}");
    const p = Panel.init("p1", "GC Content Overview", 0, 0, 1, 2, w);
    const panels = [_]Panel{p};

    const db = Dashboard.init("QC Dashboard", &panels);

    var buf: [1024]u8 = undefined;
    var fbs = std.Io.Writer.fixed(&buf);
    try db.serializeSpec(&fbs);
    try std.testing.expect(fbs.buffered().len > 0);
}
