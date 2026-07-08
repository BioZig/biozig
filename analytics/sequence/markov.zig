const std = @import("std");

/// Computes the 1st-order Markov chain transition frequencies from `sequence`.
/// Frequencies are stored in a 256x256 array where `matrix[a][b]` is the number
/// of times character `b` immediately follows character `a`.
pub fn computeTransitions(allocator: std.mem.Allocator, sequence: []const u8, threads: u16) !*[256][256]u64 {
    const matrix = try allocator.create([256][256]u64);
    for (matrix) |*row| {
        @memset(row, 0);
    }

    if (sequence.len < 2) return matrix;

    const num_threads = if (threads == 0) 1 else threads;

    if (num_threads == 1 or sequence.len < 10000) {
        computeTransitionsSerial(sequence, matrix);
        return matrix;
    }

    const chunk_size = sequence.len / num_threads;
    var thread_pool = try allocator.alloc(std.Thread, num_threads);
    defer allocator.free(thread_pool);

    var thread_matrices = try allocator.alloc([256][256]u64, num_threads);
    defer allocator.free(thread_matrices);

    for (thread_matrices) |*tm| {
        for (tm) |*row| {
            @memset(row, 0);
        }
    }

    for (0..num_threads) |i| {
        const start = i * chunk_size;
        const end = if (i == num_threads - 1) sequence.len else (i + 1) * chunk_size + 1; // +1 to capture transition across boundary

        const chunk = sequence[start..@min(end, sequence.len)];
        thread_pool[i] = try std.Thread.spawn(.{}, computeTransitionsSerial, .{ chunk, &thread_matrices[i] });
    }

    for (0..num_threads) |i| {
        thread_pool[i].join();
        for (0..256) |row| {
            for (0..256) |col| {
                matrix[row][col] += thread_matrices[i][row][col];
            }
        }
    }

    return matrix;
}

fn computeTransitionsSerial(sequence: []const u8, matrix: *[256][256]u64) void {
    if (sequence.len < 2) return;
    var i: usize = 0;
    while (i < sequence.len - 1) : (i += 1) {
        const from = sequence[i];
        const to = sequence[i + 1];
        matrix[from][to] += 1;
    }
}

test "markov computeTransitions serial" {
    const allocator = std.testing.allocator;
    const seq = "ACGTACGT";
    const matrix = try computeTransitions(allocator, seq, 1);
    defer allocator.destroy(matrix);

    try std.testing.expectEqual(@as(u64, 2), matrix['A']['C']);
    try std.testing.expectEqual(@as(u64, 2), matrix['C']['G']);
    try std.testing.expectEqual(@as(u64, 2), matrix['G']['T']);
    try std.testing.expectEqual(@as(u64, 1), matrix['T']['A']);
    try std.testing.expectEqual(@as(u64, 0), matrix['A']['A']);
}

test "markov computeTransitions parallel" {
    const allocator = std.testing.allocator;
    var seq_buf: [10005]u8 = undefined;
    for (0..seq_buf.len) |i| {
        seq_buf[i] = "ACGT"[i % 4];
    }
    const seq = seq_buf[0..];

    const matrix = try computeTransitions(allocator, seq, 4);
    defer allocator.destroy(matrix);

    try std.testing.expectEqual(@as(u64, 2501), matrix['A']['C']);
    try std.testing.expectEqual(@as(u64, 2501), matrix['C']['G']);
    try std.testing.expectEqual(@as(u64, 2501), matrix['G']['T']);
    try std.testing.expectEqual(@as(u64, 2501), matrix['T']['A']);
}

pub fn streamingTransitions(allocator: std.mem.Allocator, iterator: anytype) !*[256][256]u64 {
    const matrix = try allocator.create([256][256]u64);
    for (matrix) |*row| {
        @memset(row, 0);
    }
    
    var last_char: ?u8 = null;
    while (try iterator.nextSequenceChunk()) |chunk| {
        for (chunk) |c| {
            if (last_char) |prev| {
                matrix[prev][c] += 1;
            }
            last_char = c;
        }
    }
    return matrix;
}
