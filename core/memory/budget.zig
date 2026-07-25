const std = @import("std");

/// Strict memory budgeting guardrail for the Structural Recomputation Framework (SRF).
/// This structure enforces deterministic, user-defined memory upper bounds.
pub const MemoryBudget = struct {
    max_bytes: usize,
    chunk_size: usize,
    current_usage: usize,

    pub fn init(max_bytes: usize) MemoryBudget {
        return .{
            .max_bytes = max_bytes,
            .chunk_size = 0,
            .current_usage = 0,
        };
    }

    /// Calculates the optimal physical block (chunk) size to keep the matrix within budget.
    /// Panics immediately if the minimum viable block (2 rows) cannot fit.
    pub fn calculateChunkSize(self: *MemoryBudget, cell_size_bytes: usize, sequence_len: usize) void {
        const row_size = sequence_len * cell_size_bytes;
        
        if (self.max_bytes < row_size * 2) {
            @panic("SRF Memory Budget insufficient: requires memory for at least 2 complete rows.");
        }
        
        self.chunk_size = self.max_bytes / row_size;
    }

    /// Tracks allocations dynamically. Fails fast if budget is exceeded.
    pub fn trackUsage(self: *MemoryBudget, bytes: usize) void {
        self.current_usage += bytes;
        if (self.current_usage > self.max_bytes) {
            @panic("SRF Memory Budget Exceeded: OOM within deterministic boundary.");
        }
    }

    /// Releases allocations. Asserts no underflow.
    pub fn releaseUsage(self: *MemoryBudget, bytes: usize) void {
        std.debug.assert(self.current_usage >= bytes);
        self.current_usage -= bytes;
    }
};
