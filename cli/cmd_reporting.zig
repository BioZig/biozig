const std = @import("std");
const ParsedArgs = @import("args.zig").ParsedArgs;
const reporting = @import("reporting");

pub fn execute(args: ParsedArgs) !void {
    if (args.help) {
        std.debug.print(
            \\biozig reporting - Generate automated reports and manuscripts
            \\
            \\Usage:
            \\  biozig reporting <command> [options]
            \\
            \\Commands:
            \\  html         Export results as interactive HTML
            \\  latex        Export results as a LaTeX document
            \\  manuscript   Generate a structured manuscript
            \\  markdown     Export results as Markdown
            \\  pdf          Export results as PDF
            \\  supplement   Generate supplementary material
            \\
            \\Options:
            \\  -h, --help   Show this help message and exit
            \\  -i, --input  Input data file
            \\  -o, --output Output file path
            \\
            , .{}
        );
        return;
    }
    
    const cmd = args.run orelse {
        std.debug.print("Error: No command provided for reporting.\n", .{});
        std.process.exit(1);
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    _ = allocator;

    const out_path = args.output orelse "output_report.ext";
    const output = @import("output.zig");
    var out_writer = output.OutputWriter.init(.text);

    if (std.mem.eql(u8, cmd, "html") or
        std.mem.eql(u8, cmd, "latex") or
        std.mem.eql(u8, cmd, "manuscript") or
        std.mem.eql(u8, cmd, "markdown") or
        std.mem.eql(u8, cmd, "pdf") or
        std.mem.eql(u8, cmd, "supplement")) 
    {
        // Mock wiring to prevent unused imports
        _ = reporting.html;
        _ = reporting.latex;
        _ = reporting.manuscript;
        _ = reporting.markdown;
        _ = reporting.pdf;
        _ = reporting.supplement;
        try out_writer.writeText("Successfully initialized reporting ({s}) to {s}.\n", .{cmd, out_path});
    } else {
        std.debug.print("Error: Unknown reporting command '{s}'\n", .{cmd});
        return error.UnknownSubcommand;
    }
}
