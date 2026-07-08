const std = @import("std");
const net = @import("net");
const c_api = @import("c_api.zig");

pub const NetStreamHandle = struct {
    sieve: *net.bitsieve.BitSieve,
    network_stream: net.NetworkStream,
    producer_thread: std.Thread,
    threaded_io: *std.Io.Threaded,
    io_context: std.Io,
    allocator: std.mem.Allocator,
    
    // Internal state for the consumer
    sieve_reader: net.bitsieve.BitSieve.Reader,
    
    pub fn init(allocator: std.mem.Allocator, db: []const u8, query: []const u8) !*NetStreamHandle {
        var handle = try allocator.create(NetStreamHandle);
        errdefer allocator.destroy(handle);
        
        handle.allocator = allocator;
        handle.threaded_io = try allocator.create(std.Io.Threaded);
        handle.threaded_io.* = std.Io.Threaded.init(allocator, .{});
        handle.io_context = handle.threaded_io.io();
        
        handle.network_stream = try net.createStream(allocator, handle.io_context, db, query);
        errdefer handle.network_stream.deinit(handle.io_context);
        
        handle.sieve = try allocator.create(net.bitsieve.BitSieve);
        errdefer allocator.destroy(handle.sieve);
        handle.sieve.* = net.bitsieve.BitSieve.init(handle.io_context);
        
        handle.sieve_reader = handle.sieve.reader();
        
        const is_gz = std.mem.endsWith(u8, query, ".gz");
        
        handle.producer_thread = try std.Thread.spawn(.{}, struct {
            fn run(h: *NetStreamHandle, gz: bool) !void {
                if (h.network_stream.child.stdout) |stdout| {
                    var transfer_buffer: [8192]u8 = undefined;
                    var curl_reader = stdout.readerStreaming(h.io_context, &transfer_buffer);
                    
                    if (gz) {
                        var decomp_buf: [std.compress.flate.max_window_len]u8 = undefined;
                        var decompressor = std.compress.flate.Decompress.init(&curl_reader.interface, .gzip, &decomp_buf);
                        try h.sieve.produce(&decompressor.reader);
                    } else {
                        try h.sieve.produce(&curl_reader.interface);
                    }
                }
            }
        }.run, .{ handle, is_gz });
        
        return handle;
    }
    
    pub fn deinit(self: *NetStreamHandle) void {
        self.producer_thread.join();
        self.network_stream.deinit(self.io_context);
        self.threaded_io.deinit();
        self.allocator.destroy(self.threaded_io);
        self.allocator.destroy(self.sieve);
        self.allocator.destroy(self);
    }
};

export fn biozig_net_start(db_c: [*c]const u8, query_c: [*c]const u8) callconv(.c) ?*NetStreamHandle {
    const arena = c_api.c_arena orelse return null;
    const db = std.mem.span(db_c);
    const query = std.mem.span(query_c);
    
    return NetStreamHandle.init(arena.allocator(), db, query) catch null;
}

export fn biozig_net_read_chunk(handle: ?*NetStreamHandle, out_buffer: [*c]u8, max_len: usize) callconv(.c) usize {
    if (handle) |h| {
        // We construct a slice of length max_len from the out_buffer.
        var data: [1][]u8 = .{ out_buffer[0..max_len] };
        
        // readVec blocks securely via Condition variable inside BitSieve
        const read_amt = h.sieve_reader.readVec(&data) catch return 0;
        return read_amt;
    }
    return 0;
}

export fn biozig_net_stop(handle: ?*NetStreamHandle) callconv(.c) void {
    if (handle) |h| {
        h.deinit();
    }
}
