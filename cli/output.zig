const std = @import("std");

pub const OutputFormat = enum {
    text,
    json,
    csv,
    report,
};

pub const OutputWriter = struct {
    format: OutputFormat,

    pub fn init(format: OutputFormat) OutputWriter {
        return .{
            .format = format,
        };
    }

    pub fn writeText(self: *OutputWriter, comptime fmt: []const u8, args: anytype) !void {
        _ = self;
        std.debug.print(fmt ++ "\n", args);
    }
};
