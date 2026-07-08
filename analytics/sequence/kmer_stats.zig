const std = @import("std");

/// Computes k-mer frequencies for a given `sequence`.
/// Returns a `std.StringHashMap(u64)` where keys are k-mer substrings of `sequence` (zero-copy).
/// The caller is responsible for calling `deinit` on the returned map.
pub fn computeKmerFrequencies(allocator: std.mem.Allocator, sequence: []const u8, k: usize, threads: u16) !std.StringHashMap(u64) {
    var global_map = std.StringHashMap(u64).init(allocator);

    if (sequence.len < k or k == 0) return global_map;

    const num_threads = if (threads == 0) 1 else threads;

    if (num_threads == 1 or sequence.len < 10000) {
        try computeKmerFrequenciesSerial(sequence, k, &global_map);
        return global_map;
    }

    const chunk_size = sequence.len / num_threads;
    var thread_pool = try allocator.alloc(std.Thread, num_threads);
    defer allocator.free(thread_pool);

    var thread_maps = try allocator.alloc(std.StringHashMap(u64), num_threads);
    defer allocator.free(thread_maps);

    for (0..num_threads) |i| {
        thread_maps[i] = std.StringHashMap(u64).init(allocator);
    }

    // We use a struct since we can't easily handle errors inside spawn directly if we aren't joining correctly for errors
    const Context = struct {
        sequence: []const u8,
        k: usize,
        map: *std.StringHashMap(u64),
        err: ?anyerror = null,
    };

    var contexts = try allocator.alloc(Context, num_threads);
    defer allocator.free(contexts);

    for (0..num_threads) |i| {
        const start = i * chunk_size;
        const end = if (i == num_threads - 1) sequence.len else @min(sequence.len, (i + 1) * chunk_size + k - 1);

        contexts[i] = Context{
            .sequence = sequence[start..end],
            .k = k,
            .map = &thread_maps[i],
        };

        thread_pool[i] = try std.Thread.spawn(.{}, threadRunner, .{&contexts[i]});
    }

    var has_error = false;
    for (0..num_threads) |i| {
        thread_pool[i].join();
        if (contexts[i].err != null) {
            has_error = true;
        }
    }

    if (has_error) {
        for (0..num_threads) |i| {
            thread_maps[i].deinit();
        }
        return error.OutOfMemory; // Most likely error from HashMap
    }

    for (0..num_threads) |i| {
        var it = thread_maps[i].iterator();
        while (it.next()) |entry| {
            const res = try global_map.getOrPut(entry.key_ptr.*);
            if (res.found_existing) {
                res.value_ptr.* += entry.value_ptr.*;
            } else {
                res.value_ptr.* = entry.value_ptr.*;
            }
        }
        thread_maps[i].deinit();
    }

    return global_map;
}

fn threadRunner(ctx: anytype) void {
    computeKmerFrequenciesSerial(ctx.sequence, ctx.k, ctx.map) catch |err| {
        ctx.err = err;
    };
}

fn computeKmerFrequenciesSerial(sequence: []const u8, k: usize, map: *std.StringHashMap(u64)) !void {
    if (sequence.len < k) return;

    var i: usize = 0;
    while (i <= sequence.len - k) : (i += 1) {
        const kmer = sequence[i .. i + k];
        const res = try map.getOrPut(kmer);
        if (res.found_existing) {
            res.value_ptr.* += 1;
        } else {
            res.value_ptr.* = 1;
        }
    }
}

test "kmer_stats computeKmerFrequencies serial" {
    const allocator = std.testing.allocator;
    const seq = "ACGTACGT";
    var freqs = try computeKmerFrequencies(allocator, seq, 4, 1);
    defer freqs.deinit();

    try std.testing.expectEqual(@as(u64, 2), freqs.get("ACGT").?);
    try std.testing.expectEqual(@as(u64, 1), freqs.get("CGTA").?);
    try std.testing.expectEqual(@as(u64, 1), freqs.get("GTAC").?);
    try std.testing.expectEqual(@as(u64, 1), freqs.get("TACG").?);
}

test "kmer_stats computeKmerFrequencies parallel" {
    const allocator = std.testing.allocator;
    var seq_buf: [10005]u8 = undefined;
    for (0..seq_buf.len) |i| {
        seq_buf[i] = "ACGT"[i % 4];
    }
    const seq = seq_buf[0..];

    var freqs = try computeKmerFrequencies(allocator, seq, 4, 4);
    defer freqs.deinit();

    try std.testing.expectEqual(@as(u64, 2501), freqs.get("ACGT").?);
    try std.testing.expectEqual(@as(u64, 2501), freqs.get("CGTA").?);
    try std.testing.expectEqual(@as(u64, 2500), freqs.get("GTAC").?);
    try std.testing.expectEqual(@as(u64, 2500), freqs.get("TACG").?);
}

pub fn streamingDipeptideFrequencies(allocator: std.mem.Allocator, iterator: anytype) !*[256][256]u64 {
    const dipeptides = try allocator.create([256][256]u64);
    for (dipeptides) |*row| {
        @memset(row, 0);
    }
    
    var last_char: ?u8 = null;
    while (try iterator.nextSequenceChunk()) |chunk| {
        for (chunk) |c| {
            if (last_char) |prev| {
                dipeptides[prev][c] += 1;
            }
            last_char = c;
        }
    }
    return dipeptides;
}
