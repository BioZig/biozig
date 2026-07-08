// mock_chaos_server.zig
const std = @import("std");
const mem = std.mem;

pub const ChaosType = enum {
    normal,
    slow_drip,
    random_close,
    http_429,
    http_502,
};

pub const MockStream = struct {
    chaos_type: ChaosType,
    cursor: usize = 0,
    buffer: []const u8,

    pub const ReadError = error{
        ConnectionResetByPeer,
        EndOfStream,
    };

    pub fn read(self: *MockStream, dest: []u8) ReadError!usize {
        if (self.cursor >= self.buffer.len) {
            return error.EndOfStream;
        }

        switch (self.chaos_type) {
            .random_close => {
                // Simulate sudden close mid-stream simulating poison pills
                if (self.cursor >= self.buffer.len / 2) {
                    return error.ConnectionResetByPeer;
                }
            },
            .slow_drip => {
                // Return exactly 1 byte at a time to test double-buffer starvation
                dest[0] = self.buffer[self.cursor];
                self.cursor += 1;
                return 1;
            },
            else => {},
        }

        const remaining = self.buffer.len - self.cursor;
        const to_read = @min(dest.len, remaining);
        @memcpy(dest[0..to_read], self.buffer[self.cursor..][0..to_read]);
        self.cursor += to_read;
        return to_read;
    }

    pub fn write(self: *MockStream, data: []const u8) !usize {
        // Accept the write (e.g. HTTP GET request) and do nothing for mock
        _ = self;
        return data.len;
    }
};

pub const ChaosServer = struct {
    chaos_type: ChaosType,

    pub fn init(chaos_type: ChaosType) ChaosServer {
        return .{ .chaos_type = chaos_type };
    }

    pub fn accept(self: *ChaosServer) MockStream {
        const response = switch (self.chaos_type) {
            .normal => "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK",
            .slow_drip => "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nSLOW_DRIP!",
            .random_close => "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nCH",
            .http_429 => "HTTP/1.1 429 Too Many Requests\r\nRetry-After: 1\r\n\r\nToo Many Requests",
            .http_502 => "HTTP/1.1 502 Bad Gateway\r\n\r\nBad Gateway",
        };

        return MockStream{
            .chaos_type = self.chaos_type,
            .buffer = response,
        };
    }
};
