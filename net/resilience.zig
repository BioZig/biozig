const std = @import("std");

pub const Cursor = struct {
    offset: usize,
    last_checkpoint: usize,

    pub fn init() Cursor {
        return .{ .offset = 0, .last_checkpoint = 0 };
    }

    pub fn advance(self: *Cursor, amount: usize) void {
        self.offset += amount;
    }

    pub fn commit(self: *Cursor) void {
        self.last_checkpoint = self.offset;
    }

    pub fn rollback(self: *Cursor) void {
        self.offset = self.last_checkpoint;
    }
};

pub const CircuitState = enum {
    closed,
    open,
    half_open,
};

pub const CircuitBreaker = struct {
    state: CircuitState,
    failures: usize,
    max_failures: usize,
    base_timeout_ms: u64,
    last_failure_time: i64,

    pub fn init(max_failures: usize, base_timeout_ms: u64) CircuitBreaker {
        return .{
            .state = .closed,
            .failures = 0,
            .max_failures = max_failures,
            .base_timeout_ms = base_timeout_ms,
            .last_failure_time = 0,
        };
    }

    pub fn record_failure(self: *CircuitBreaker, current_time: i64) void {
        self.failures += 1;
        self.last_failure_time = current_time;
        if (self.failures >= self.max_failures) {
            self.state = .open;
        }
    }

    pub fn record_success(self: *CircuitBreaker) void {
        self.failures = 0;
        self.state = .closed;
    }

    pub fn allow_request(self: *CircuitBreaker, current_time: i64) bool {
        switch (self.state) {
            .closed => return true,
            .open => {
                const backoff = self.base_timeout_ms * (std.math.pow(u64, 2, self.failures) catch 1);
                if (current_time - self.last_failure_time >= backoff) {
                    self.state = .half_open;
                    return true;
                }
                return false;
            },
            .half_open => return true,
        }
    }
};
