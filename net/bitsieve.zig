const std = @import("std");

pub const BitSieve = struct {
    io: std.Io,
    mutex: std.Io.Mutex = std.Io.Mutex.init,
    cond: std.Io.Condition = std.Io.Condition.init,
    
    // Two 64KB buffers
    buffer_a: [65536]u8 = undefined,
    buffer_b: [65536]u8 = undefined,
    
    // State tracking
    a_len: usize = 0,
    b_len: usize = 0,
    
    // Which buffer is currently being read by the consumer (0 = A, 1 = B)
    read_index: u8 = 0,
    
    // Which buffer is currently being filled by the producer (0 = A, 1 = B)
    write_index: u8 = 0,
    
    // Flags for coordinating handoffs
    a_ready: bool = false,
    b_ready: bool = false,
    
    // Position inside the currently consumed buffer
    consume_pos: usize = 0,
    
    eof: bool = false,

    const Self = @This();

    pub fn init(io: std.Io) Self {
        return .{ .io = io };
    }

    /// Called by the Network Thread to produce data
    pub fn produce(self: *Self, stream_reader: anytype) !void {
        while (true) {
            self.mutex.lockUncancelable(self.io);
            
            // Wait until the buffer we want to write to is NOT ready (meaning it was consumed)
            while ((self.write_index == 0 and self.a_ready) or 
                   (self.write_index == 1 and self.b_ready)) {
                self.cond.waitUncancelable(self.io, &self.mutex);
            }
            
            // We hold the lock, but we can unlock it while we read from the network 
            // into the inactive buffer to allow the consumer to keep crunching the active buffer.
            self.mutex.unlock(self.io);

            var read_amt: usize = 0;
            if (self.write_index == 0) {
                read_amt = try stream_reader.readSliceShort(self.buffer_a[4096..]);
                self.mutex.lockUncancelable(self.io);
                self.a_len = read_amt;
                self.a_ready = true;
            } else {
                read_amt = try stream_reader.readSliceShort(self.buffer_b[4096..]);
                self.mutex.lockUncancelable(self.io);
                self.b_len = read_amt;
                self.b_ready = true;
            }
            
            if (read_amt == 0) {
                self.eof = true;
                self.cond.signal(self.io);
                self.mutex.unlock(self.io);
                return;
            }

            self.write_index = 1 - self.write_index;
            self.cond.signal(self.io);
            self.mutex.unlock(self.io);
        }
    }

    /// Called by the Analytics Thread to consume data.
    /// Returns a slice to the ready buffer (the data starts at index 4096).
    /// The caller can copy up to 4096 bytes of carry-over data into indices 0..4095.
    pub fn consume(self: *Self) ?[]u8 {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);

        while (true) {
            if (self.read_index == 0) {
                if (self.a_ready) {
                    return self.buffer_a[0 .. 4096 + self.a_len];
                } else if (self.eof) {
                    return null;
                }
            } else {
                if (self.b_ready) {
                    return self.buffer_b[0 .. 4096 + self.b_len];
                } else if (self.eof) {
                    return null;
                }
            }
            self.cond.waitUncancelable(self.io, &self.mutex);
        }
    }

    /// Called by the Analytics Thread to mark the buffer as fully processed
    pub fn release(self: *Self) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        
        if (self.read_index == 0) {
            self.a_ready = false;
        } else {
            self.b_ready = false;
        }
        
        self.read_index = 1 - self.read_index;
        self.consume_pos = 0;
        self.cond.signal(self.io);
    }

    /// Reader interface struct for drop-in compatibility
    pub const Reader = struct {
        sieve: *BitSieve,

        pub fn readVec(self: Reader, dest: []const []u8) !usize {
            if (dest.len == 0 or dest[0].len == 0) return 0;
            const dest_buf = dest[0];
            
            self.sieve.mutex.lockUncancelable(self.sieve.io);
            defer self.sieve.mutex.unlock(self.sieve.io);

            while (true) {
                var ready_buf: []const u8 = undefined;
                
                if (self.sieve.read_index == 0) {
                    if (self.sieve.a_ready) {
                        ready_buf = self.sieve.buffer_a[4096 .. 4096 + self.sieve.a_len];
                    } else if (self.sieve.eof) {
                        return 0;
                    } else {
                        self.sieve.cond.waitUncancelable(self.sieve.io, &self.sieve.mutex);
                        continue;
                    }
                } else {
                    if (self.sieve.b_ready) {
                        ready_buf = self.sieve.buffer_b[4096 .. 4096 + self.sieve.b_len];
                    } else if (self.sieve.eof) {
                        return 0;
                    } else {
                        self.sieve.cond.waitUncancelable(self.sieve.io, &self.sieve.mutex);
                        continue;
                    }
                }

                const remain = ready_buf.len - self.sieve.consume_pos;
                if (remain == 0) {
                    // Buffer is fully consumed, mark it released and wait for next
                    if (self.sieve.read_index == 0) {
                        self.sieve.a_ready = false;
                    } else {
                        self.sieve.b_ready = false;
                    }
                    self.sieve.read_index = 1 - self.sieve.read_index;
                    self.sieve.consume_pos = 0;
                    self.sieve.cond.signal(self.sieve.io);
                    continue;
                }

                const copy_len = @min(dest_buf.len, remain);
                std.mem.copyForwards(u8, dest_buf[0..copy_len], ready_buf[self.sieve.consume_pos .. self.sieve.consume_pos + copy_len]);
                self.sieve.consume_pos += copy_len;
                return copy_len;
            }
        }
    };

    pub fn reader(self: *Self) Reader {
        return .{ .sieve = self };
    }
};
