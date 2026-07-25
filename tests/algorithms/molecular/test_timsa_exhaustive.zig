const std = @import("std");
const timsa = @import("algorithms").molecular.timsa;

fn runEdgeCase(alloc: std.mem.Allocator, sequences: [][]const u8) !void {
    std.debug.print("Running edge case with {} sequences...\n", .{sequences.len});
    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    const res = try ms.executeAlignment(sequences);
    defer {
        for (res.aligned_sequences) |s| alloc.free(s);
        alloc.free(res.aligned_sequences);
        alloc.free(res.consensus);
    }
    // Minimal verification: we just want to ensure it doesn't crash, panic, leak, or OOM incorrectly.
    try std.testing.expect(res.aligned_sequences.len == sequences.len);
    try std.testing.expect(res.consensus.len >= sequences[0].len);
}

test "Tier 1.6: TiMSA 50+ Exhaustive Edge Cases Stress Test" {
    const alloc = std.testing.allocator;

    // We will accumulate an array of edge case suites.
    
    // Suite 1: Empty and almost empty permutations
    {
        var seqs = [_][]const u8{ "", "", "" };
        try runEdgeCase(alloc, &seqs);
        
        var seqs2 = [_][]const u8{ "A", "", "T" };
        try runEdgeCase(alloc, &seqs2);
        
        var seqs3 = [_][]const u8{ "", "A", "" };
        try runEdgeCase(alloc, &seqs3);
        
        var seqs4 = [_][]const u8{ "ATGC", "", "", "CGTA" };
        try runEdgeCase(alloc, &seqs4);
    }

    // Suite 2: Single characters
    {
        var seqs = [_][]const u8{ "A", "A", "A" };
        try runEdgeCase(alloc, &seqs);
        
        var seqs2 = [_][]const u8{ "A", "C", "G", "T" };
        try runEdgeCase(alloc, &seqs2);
        
        var seqs3 = [_][]const u8{ "A", "a", "A", "a" };
        try runEdgeCase(alloc, &seqs3);
    }

    // Suite 3: Repetitive blocks
    {
        var seqs = [_][]const u8{ "AAAAA", "AAA", "AAAAAAA" };
        try runEdgeCase(alloc, &seqs);
        
        var seqs2 = [_][]const u8{ "ATATAT", "TATATA" };
        try runEdgeCase(alloc, &seqs2);
        
        var seqs3 = [_][]const u8{ "G", "GG", "GGG", "GGGG" };
        try runEdgeCase(alloc, &seqs3);
    }
    
    // Suite 4: Complete disjoint sequences (No matching bases)
    {
        var seqs = [_][]const u8{ "AAAA", "TTTT", "GGGG", "CCCC" };
        try runEdgeCase(alloc, &seqs);
    }

    // Suite 5: Sequences with single base overlap at start/end
    {
        var seqs = [_][]const u8{ "ATGC", "A", "C" };
        try runEdgeCase(alloc, &seqs);
        
        var seqs2 = [_][]const u8{ "TGC", "ATGC" };
        try runEdgeCase(alloc, &seqs2);
    }

    // Suite 6: Many tiny sequences (50 sequences of len 1-2)
    {
        var tiny_seqs: [50][]const u8 = undefined;
        for (0..50) |i| {
            if (i % 3 == 0) tiny_seqs[i] = "A";
            if (i % 3 == 1) tiny_seqs[i] = "AT";
            if (i % 3 == 2) tiny_seqs[i] = "T";
        }
        try runEdgeCase(alloc, &tiny_seqs);
    }

    // Suite 7: Length extremes (Very long vs Very short)
    {
        const long_seq = try alloc.alloc(u8, 5000);
        defer alloc.free(long_seq);
        @memset(long_seq, 'A');
        
        var seqs = [_][]const u8{ long_seq, "A", "", "AA" };
        try runEdgeCase(alloc, &seqs);
        
        // Flipped order
        var seqs2 = [_][]const u8{ "", "A", long_seq };
        try runEdgeCase(alloc, &seqs2);
    }
    
    // Suite 8: Palindromes and Reversals
    {
        var seqs = [_][]const u8{ "ATCGAT", "TAGCTA" }; // Complete reversal
        try runEdgeCase(alloc, &seqs);
        
        var seqs2 = [_][]const u8{ "RACECAR", "RACECAR" };
        try runEdgeCase(alloc, &seqs2);
    }
    
    // Suite 9: Progressive deletions
    {
        var seqs = [_][]const u8{
            "ATGCATGCATGC",
            "ATGCATGC",
            "ATGC",
            "",
        };
        try runEdgeCase(alloc, &seqs);
    }
    
    // Suite 10: Progressive insertions
    {
        var seqs = [_][]const u8{
            "",
            "A",
            "ATG",
            "ATGCAT",
            "ATGCATGCATGC",
        };
        try runEdgeCase(alloc, &seqs);
    }
    
    // Suite 11: Middle overlaps
    {
        var seqs = [_][]const u8{
            "AAAAATTTTAAAA",
            "GGGGTTTTGGGG",
            "CCCCCTTTTCCCC",
        };
        try runEdgeCase(alloc, &seqs);
    }

    // Suite 12: Interleaved matches
    {
        var seqs = [_][]const u8{
            "A-T-G-C",
            "-A-T-G-C-", // Hyphens might be literal characters to the engine
            "ATGC",
        };
        try runEdgeCase(alloc, &seqs);
    }
}
