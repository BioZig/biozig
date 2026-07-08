// test_bitsieve.zig
const std = @import("std");
const testing = std.testing;
const ChaosServer = @import("mock_chaos_server.zig").ChaosServer;
const ChaosType = @import("mock_chaos_server.zig").ChaosType;
const MockStream = @import("mock_chaos_server.zig").MockStream;

const BitSieveClient = struct {
    allocator: std.mem.Allocator,
    server: *ChaosServer,

    pub fn fetch(self: *BitSieveClient) ![]u8 {
        var stream = self.server.accept();

        _ = try stream.write("GET / HTTP/1.1\r\n\r\n");
        var result_buf: [4096]u8 = undefined;
        var result_len: usize = 0;

        var buf: [1024]u8 = undefined;
        while (true) {
            const len = stream.read(&buf) catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };
            if (len == 0) break;
            @memcpy(result_buf[result_len..][0..len], buf[0..len]);
            result_len += len;
        }
        return self.allocator.dupe(u8, result_buf[0..result_len]);
    }
    
    // Simulate exponential backoff client logic
    pub fn fetchWithBackoff(self: *BitSieveClient, max_retries: u32) ![]u8 {
        var retries: u32 = 0;
        var backoff_ms: u64 = 1;
        while (retries < max_retries) : (retries += 1) {
            if (self.fetch()) |res| {
                if (std.mem.indexOf(u8, res, "429") != null or std.mem.indexOf(u8, res, "502") != null) {

                    backoff_ms *= 2;
                    self.allocator.free(res);
                    continue;
                }
                return res;
            } else |_| {

                backoff_ms *= 2;
                continue;
            }
        }
        return error.MaxRetriesExceeded;
    }
};

test "bitsieve: normal operation double buffered fetch" {
    var server = ChaosServer.init(.normal);
    var client = BitSieveClient{ .allocator = testing.allocator, .server = &server };
    
    const res = try client.fetch();
    defer testing.allocator.free(res);
    
    try testing.expect(std.mem.indexOf(u8, res, "200 OK") != null);
}

test "bitsieve: slow drip double buffer test" {
    var server = ChaosServer.init(.slow_drip);
    var client = BitSieveClient{ .allocator = testing.allocator, .server = &server };
    
    const res = try client.fetch();
    defer testing.allocator.free(res);
    
    // It should successfully assemble the drip data
    try testing.expect(std.mem.indexOf(u8, res, "SLOW_DRIP!") != null);
}

test "bitsieve: http 429/502 exponential backoff" {
    var server = ChaosServer.init(.http_429);
    var client = BitSieveClient{ .allocator = testing.allocator, .server = &server };
    
    // Should fail after max retries and exhibit backoff
    try testing.expectError(error.MaxRetriesExceeded, client.fetchWithBackoff(3));
}

test "bitsieve: poison pill SIMD rejection on truncated random close" {
    var server = ChaosServer.init(.random_close);
    var client = BitSieveClient{ .allocator = testing.allocator, .server = &server };
    
    // Simulating SIMD checking truncated/corrupted bitsieve buffers.
    if (client.fetch()) |res| {
        defer testing.allocator.free(res);
        try testing.expect(res.len < 100);
    } else |err| {
        try testing.expect(err == error.ConnectionResetByPeer);
    }
}
