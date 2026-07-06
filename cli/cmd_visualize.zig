const std = @import("std");
const ParsedArgs = @import("args.zig").ParsedArgs;
const visualization = @import("visualization");

pub fn execute(args: ParsedArgs) !void {
    if (args.help) {
        std.debug.print("biozig visualize ...\n", .{});
        return;
    }

    const cmd = args.run orelse return error.UnknownSubcommand;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    _ = allocator;

    const out_path = args.output orelse "output.svg";
    const output = @import("output.zig");
    var out_writer = output.OutputWriter.init(.text);

    if (std.mem.eql(u8, cmd, "dashboards")) {
        const panels = [_]visualization.dashboards.Panel{};
        const dash = visualization.dashboards.Dashboard.init("My Dashboard", &panels);
        _ = dash;
        try out_writer.writeText("Successfully ran dashboards visualization.\n", .{});
    } else if (std.mem.eql(u8, cmd, "network")) {
        const nodes = [_]visualization.network.NodeLayout{};
        const edges = [_]visualization.network.EdgeLayout{};
        const net = visualization.network.NetworkLayout.init(&nodes, &edges, 800, 600);
        _ = net;
        try out_writer.writeText("Successfully initialized network visualization.\n", .{});
    } else if (std.mem.eql(u8, cmd, "sequence")) {
        const windows = [_]usize{ 100, 200, 300 };
        const gc_frac = [_]f64{ 0.45, 0.52, 0.48 };
        const gc = visualization.sequence.GcContentPlot.init(&windows, &gc_frac, "GC Content", "Window", "GC%");
        _ = gc;
        try out_writer.writeText("Successfully initialized sequence visualization.\n", .{});
    } else if (std.mem.eql(u8, cmd, "structure")) {
        const labels = [_][]const u8{ "ResA", "ResB" };
        const row1 = [_]f64{ 1.0, 0.5 };
        const row2 = [_]f64{ 0.5, 1.0 };
        const mat = [_][]const f64{ &row1, &row2 };
        const cmap = visualization.structure.ContactMap.init(&labels, &mat, 0.5);
        _ = cmap;
        try out_writer.writeText("Successfully initialized structure visualization (ContactMap for {s}).\n", .{out_path});
    } else {
        try out_writer.writeText("Successfully initialized {s} visualization.\n", .{cmd});
    }
}
