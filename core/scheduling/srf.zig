const std = @import("std");
const memory = @import("../memory/budget.zig");

/// Universal representation of a resolved Dynamic Programming alignment.
pub const DPResult = struct {
    score: i32,
    align_a: []const u8,
    align_b: []const u8,
};

/// Interface constraints for SRF-compatible recurrences.
/// Recurrences must define how to process a single block and how to trace it back.
///
/// Expected methods on Recurrence:
/// - fn cellSizeBytes() usize
/// - fn fillForwardRow(self, a_char: anytype, b_seq: anytype, prev_row: []i32, curr_row: []i32) void
/// - fn fillBlock(self, a_seq: anytype, b_seq: anytype, start_row: []i32, block_matrix: []i32) void
/// - fn tracebackBlock(self, a_seq: anytype, b_seq: anytype, block_matrix: []i32, start_row_idx: usize, start_col_idx: usize, align_a: *std.ArrayListUnmanaged(u8), align_b: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) struct { row: usize, col: usize }
pub fn SRFScheduler(comptime Recurrence: type) type {
    comptime {
        if (!@hasDecl(Recurrence, "cellSizeBytes") or
            !@hasDecl(Recurrence, "fillForwardRow") or
            !@hasDecl(Recurrence, "fillBlock") or
            !@hasDecl(Recurrence, "tracebackBlock")) {
            @compileError("Recurrence does not fulfill the SRF Trait requirements.");
        }
    }

    return struct {
        allocator: std.mem.Allocator,
        recurrence: Recurrence,
        budget: memory.MemoryBudget,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, recurrence: Recurrence, max_bytes: usize) Self {
            return .{
                .allocator = allocator,
                .recurrence = recurrence,
                .budget = memory.MemoryBudget.init(max_bytes),
            };
        }

        pub fn execute(self: *Self, comptime SeqType: type, seq_a: SeqType, seq_b: SeqType) !DPResult {
            const cell_size = Recurrence.cellSizeBytes();
            const cols = seq_b.len + 1;
            const row_bytes = cols * cell_size;
            
            // 1. Memory Budgeting
            // Ensure we can hold at least 2 rows (for linear forward pass)
            if (self.budget.max_bytes < row_bytes * 2) {
                return error.OutOfMemoryBudget;
            }
            
            // Calculate K (chunk size / block height)
            // We need memory for:
            // - The local block matrix (K * row_bytes)
            // - The checkpoints ( (seq_a.len / K) * row_bytes )
            // Budget >= K * row_bytes + (N / K) * row_bytes
            // For optimal K, K = sqrt(N). Let's maximize K based on budget.
            const optimal_k = @as(usize, @intFromFloat(@sqrt(@as(f64, @floatFromInt(seq_a.len)))));
            var K: usize = if (optimal_k > 0) optimal_k else 1;
            
            if (K > seq_a.len) K = seq_a.len;
            if (K == 0) K = 1;
            
            const block_mem = K * row_bytes;
            const cp_count = (seq_a.len / K) + 1;
            const cp_mem = cp_count * row_bytes;
            
            if (block_mem + cp_mem > self.budget.max_bytes) {
                // If the absolute minimum memory configuration exceeds budget, we truly OOM.
                self.budget.trackUsage(block_mem + cp_mem);
            }

            self.budget.trackUsage(K * row_bytes); // Block memory
            defer self.budget.releaseUsage(K * row_bytes);

            // 2. Checkpoint Array (Forward Pass)
            const num_checkpoints = (seq_a.len / K) + 1;
            var checkpoints = try self.allocator.alloc([]i32, num_checkpoints);
            defer self.allocator.free(checkpoints);
            
            self.budget.trackUsage(num_checkpoints * row_bytes);
            defer self.budget.releaseUsage(num_checkpoints * row_bytes);

            for (0..num_checkpoints) |i| {
                checkpoints[i] = try self.allocator.alloc(i32, cols);
            }
            defer {
                for (checkpoints) |cp| self.allocator.free(cp);
            }

            // Initialize first row (checkpoint 0)
            // In a real recurrence, this handles leading gaps (e.g., 0, -1, -2...)
            self.recurrence.initRowZero(checkpoints[0], seq_b);

            const curr_row = try self.allocator.alloc(i32, cols);
            const prev_row = try self.allocator.alloc(i32, cols);
            defer self.allocator.free(curr_row);
            defer self.allocator.free(prev_row);

            @memcpy(prev_row, checkpoints[0]);

            if (@hasDecl(Recurrence, "resetGlobalMax")) {
                self.recurrence.resetGlobalMax();
            }

            // Forward Pass
            for (1..seq_a.len + 1) |i| {
                self.recurrence.fillForwardRow(seq_a[i - 1], seq_b, prev_row, curr_row);
                
                if (@hasDecl(Recurrence, "updateGlobalMax")) {
                    self.recurrence.updateGlobalMax(curr_row, i);
                }
                
                // Save checkpoint at block boundaries
                if (i % K == 0) {
                    const cp_idx = i / K;
                    @memcpy(checkpoints[cp_idx], curr_row);
                }
                
                @memcpy(prev_row, curr_row);
            }

            var final_score: i32 = 0;
            if (@hasDecl(Recurrence, "isLocal") and Recurrence.isLocal) {
                final_score = self.recurrence.max_score_ptr.*;
            } else {
                if (seq_a.len == 0) {
                    final_score = prev_row[cols - 1];
                } else {
                    final_score = curr_row[cols - 1];
                }
            }
            // 3. Reverse Traceback with Structural Recomputation
            var align_a = std.ArrayListUnmanaged(u8).empty;
            var align_b = std.ArrayListUnmanaged(u8).empty;
            errdefer align_a.deinit(self.allocator);
            errdefer align_b.deinit(self.allocator);

            const block_matrix = try self.allocator.alloc(i32, (K + 1) * cols);
            defer self.allocator.free(block_matrix);
            
            var current_row_idx = seq_a.len;
            var current_col_idx = seq_b.len;
            
            if (@hasDecl(Recurrence, "getTracebackStart")) {
                if (self.recurrence.getTracebackStart()) |start_coords| {
                    current_row_idx = start_coords.row;
                    current_col_idx = start_coords.col;
                }
            }
            var prev_row_idx: usize = std.math.maxInt(usize);
            var prev_col_idx: usize = std.math.maxInt(usize);

            while (current_row_idx > 0 or current_col_idx > 0) {
                // Infinite loop failsafe: if no progress was made, break out
                if (current_row_idx == prev_row_idx and current_col_idx == prev_col_idx) {
                    break;
                }
                prev_row_idx = current_row_idx;
                prev_col_idx = current_col_idx;

                // Determine block boundaries
                const block_end = current_row_idx;
                const remainder = block_end % K;
                const block_start = if (block_end == 0) 0 else if (remainder == 0) block_end - K else block_end - remainder;
                const cp_idx = block_start / K;
                
                const local_block_height = block_end - block_start;
                
                // std.debug.print("Traceback state: row={}, col={}, block_start={}, block_end={}, block_height={}\n", .{current_row_idx, current_col_idx, block_start, block_end, local_block_height});
                
                if (local_block_height > 0) {
                    // Recompute the block dynamically
                    const block_seq_a = seq_a[block_start..block_end];
                    self.recurrence.fillBlock(block_seq_a, seq_b, checkpoints[cp_idx], block_matrix);
                    
                    // Traceback through this local block
                    const new_coords = self.recurrence.tracebackBlock(
                        block_seq_a, seq_b, block_matrix, 
                        local_block_height, current_col_idx, 
                        &align_a, &align_b, self.allocator
                    );
                    
                    current_row_idx = block_start + new_coords.row;
                    current_col_idx = new_coords.col;
                    
                    if (@hasDecl(Recurrence, "isLocal") and Recurrence.isLocal) {
                        if (new_coords.row > 0) break; // Local alignment hit 0 and stopped early
                    }
                } else if (current_row_idx > 0) {
                    // We hit a checkpoint exactly, move to previous block
                    current_row_idx -= 1;
                    // Handle pure deletion step across boundary if needed (handled by Recurrence)
                }
                
                // If we are at row 0, remaining path must be pure insertions (col > 0)
                // Skip padding if the recurrence handles local alignment
                if (!@hasDecl(Recurrence, "isLocal") or !Recurrence.isLocal) {
                    if (current_row_idx == 0 and current_col_idx > 0) {
                        while (current_col_idx > 0) {
                            try align_a.append(self.allocator, '-');
                            if (SeqType == []const u8) {
                                try align_b.append(self.allocator, seq_b[current_col_idx - 1]);
                            } else {
                                try align_b.append(self.allocator, 'I');
                            }
                            current_col_idx -= 1;
                        }
                    }
                } else {
                    // For local alignments, we just stop when we hit the edge or 0
                    if (current_row_idx == 0) {
                        break;
                    }
                }
            }

            // The traceback builds sequences in reverse
            std.mem.reverse(u8, align_a.items);
            std.mem.reverse(u8, align_b.items);

            return DPResult{
                .score = @as(i32, final_score),
                .align_a = try align_a.toOwnedSlice(self.allocator),
                .align_b = try align_b.toOwnedSlice(self.allocator),
            };
        }
    };
}
