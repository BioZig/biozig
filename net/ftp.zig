const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const net = std.Io.net;

pub const FtpClient = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    control_stream: net.Stream,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, host: []const u8, port: u16) !FtpClient {
        const address = try net.IpAddress.resolve(io, host, port);
        const stream = try address.connect(io, .{ .mode = .stream });
        var client = FtpClient{
            .allocator = allocator,
            .io = io,
            .control_stream = stream,
        };
        try client.readResponse(); // Read initial greeting
        return client;
    }

    pub fn deinit(self: *FtpClient) void {
        self.control_stream.close(self.io);
    }

    fn readResponse(self: *FtpClient) !void {
        var buf: [1024]u8 = undefined;
        var io_reader = self.control_stream.reader(self.io, &buf);
        var read_buf: [1024]u8 = undefined;
        const bytes_read = try io_reader.interface.readSliceShort(&read_buf);
        if (bytes_read == 0) return error.ConnectionClosed;
    }

    pub fn sendCommand(self: *FtpClient, cmd: []const u8) !void {
        var write_buf: [1024]u8 = undefined;
        var io_writer = self.control_stream.writer(self.io, &write_buf);
        const msg = try fmt.allocPrint(self.allocator, "{s}\r\n", .{cmd});
        defer self.allocator.free(msg);
        try io_writer.interface.writeAll(msg);
        try self.readResponse();
    }

    pub fn login(self: *FtpClient, user: []const u8, pass: []const u8) !void {
        var buf: [256]u8 = undefined;
        const user_cmd = try fmt.bufPrint(&buf, "USER {s}", .{user});
        try self.sendCommand(user_cmd);
        
        const pass_cmd = try fmt.bufPrint(&buf, "PASS {s}", .{pass});
        try self.sendCommand(pass_cmd);
    }

    pub fn enterPassiveMode(self: *FtpClient) !net.Stream {
        var write_buf: [1024]u8 = undefined;
        var io_writer = self.control_stream.writer(self.io, &write_buf);
        try io_writer.interface.writeAll("PASV\r\n");
        
        var buf: [1024]u8 = undefined;
        var io_reader = self.control_stream.reader(self.io, &buf);
        var read_buf: [1024]u8 = undefined;
        const bytes_read = try io_reader.interface.readSliceShort(&read_buf);
        const response = read_buf[0..bytes_read];
        
        // Parse "227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)"
        const start = mem.indexOfScalar(u8, response, '(') orelse return error.InvalidPasvResponse;
        const end = mem.indexOfScalar(u8, response, ')') orelse return error.InvalidPasvResponse;
        
        const inner = response[start + 1 .. end];
        var it = mem.splitScalar(u8, inner, ',');
        
        var parts: [6]u8 = undefined;
        var i: usize = 0;
        while (it.next()) |part| {
            if (i >= 6) return error.InvalidPasvResponse;
            parts[i] = try fmt.parseInt(u8, part, 10);
            i += 1;
        }
        if (i != 6) return error.InvalidPasvResponse;
        
        var ip_buf: [32]u8 = undefined;
        const ip_str = try fmt.bufPrint(&ip_buf, "{d}.{d}.{d}.{d}", .{parts[0], parts[1], parts[2], parts[3]});
        const port = (@as(u16, parts[4]) << 8) | @as(u16, parts[5]);
        
        const address = try net.IpAddress.parse(ip_str, port);
        return address.connect(self.io, .{ .mode = .stream });
    }

    pub fn retr(self: *FtpClient, filename: []const u8) !net.Stream {
        const data_stream = try self.enterPassiveMode();
        
        var buf: [256]u8 = undefined;
        const retr_cmd = try fmt.bufPrint(&buf, "RETR {s}", .{filename});
        const msg = try fmt.allocPrint(self.allocator, "{s}\r\n", .{retr_cmd});
        defer self.allocator.free(msg);
        
        var write_buf: [1024]u8 = undefined;
        var io_writer = self.control_stream.writer(self.io, &write_buf);
        try io_writer.interface.writeAll(msg);
        try self.readResponse(); // Read 150 File status okay; about to open data connection
        
        return data_stream;
    }
};
