const std = @import("std");

pub const ParsedArgs = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
    file: ?[]const u8 = null,
    run: ?[]const u8 = null,
    path: ?[]const u8 = null,
    threads: ?u16 = null,
    k: ?usize = null,
    eps: ?f64 = null,
    min_pts: ?usize = null,
    help: bool = false,
};

pub fn parseSlice(args: []const []const u8) ParsedArgs {
    var parsed = ParsedArgs{};
    var idx: usize = 0;
    while (idx < args.len) : (idx += 1) {
        const arg = args[idx];
        const is_i = std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input");
        const is_o = std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output");
        const is_f = std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--file");
        const is_r = std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--run");
        const is_p = std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--path");
        const is_t = std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--threads");
        const is_k = std.mem.eql(u8, arg, "-k");
        const is_eps = std.mem.eql(u8, arg, "--eps");
        const is_minpts = std.mem.eql(u8, arg, "--min-pts");
        const is_h = std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help");

        if (is_i or is_o or is_f or is_r or is_p or is_t or is_k or is_eps or is_minpts) {
            if (idx + 1 < args.len) {
                idx += 1;
                const val = args[idx];
                if (is_i) parsed.input = val;
                if (is_o) parsed.output = val;
                if (is_f) parsed.file = val;
                if (is_r) parsed.run = val;
                if (is_p) parsed.path = val;
                if (is_t) parsed.threads = std.fmt.parseInt(u16, val, 10) catch null;
                if (is_k) parsed.k = std.fmt.parseInt(usize, val, 10) catch null;
                if (is_eps) parsed.eps = std.fmt.parseFloat(f64, val) catch null;
                if (is_minpts) parsed.min_pts = std.fmt.parseInt(usize, val, 10) catch null;
            }
        } else if (is_h) {
            parsed.help = true;
        } else if (!std.mem.startsWith(u8, arg, "-") and parsed.run == null) {
            parsed.run = arg; 
        }
    }
    return parsed;
}
