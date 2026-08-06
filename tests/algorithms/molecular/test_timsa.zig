const std = @import("std");
const timsa = @import("algorithms").molecular.timsa;
const alignment = @import("algorithms").molecular.alignment;
const srf = @import("core").scheduling.srf;

test "Tier 1.1: TiMSA execution on Random Sequences (Deterministic and Complete)" {
    const alloc = std.testing.allocator;

    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    
    // Some small artificial test sequences
    var sequences = [_][]const u8{
        "ATGCATGCATGC",
        "ATGCGCATGC",
        "ATGCATGC",
    };
    
    // We expect TiMSA to run without memory violations and output alignment and consensus.
    const res = try ms.executeAlignment(&sequences);
    defer {
        for (res.aligned_sequences) |s| alloc.free(s);
        alloc.free(res.aligned_sequences);
        alloc.free(res.consensus);
    }
    
    try std.testing.expect(res.aligned_sequences.len == 3);
    try std.testing.expect(res.consensus.len >= 8); // at least max length of sequences
}

test "Tier 1.2: TiMSA Edge Cases (identical, single base)" {
    const alloc = std.testing.allocator;

    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    
    var sequences = [_][]const u8{
        "A",
        "A",
    };
    
    const res = try ms.executeAlignment(&sequences);
    defer {
        for (res.aligned_sequences) |s| alloc.free(s);
        alloc.free(res.aligned_sequences);
        alloc.free(res.consensus);
    }
    
    try std.testing.expectEqualStrings("A", res.consensus);
    try std.testing.expectEqualStrings("A", res.aligned_sequences[0]);
    try std.testing.expectEqualStrings("A", res.aligned_sequences[1]);
}

test "Tier 1.3: TiMSA Determinism Check" {
    const alloc = std.testing.allocator;

    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    
    var sequences = [_][]const u8{
        "GATTACA",
        "GATCACA",
        "GATCA",
    };
    
    const res1 = try ms.executeAlignment(&sequences);
    const res2 = try ms.executeAlignment(&sequences);
    
    defer {
        for (res1.aligned_sequences) |s| alloc.free(s);
        alloc.free(res1.aligned_sequences);
        alloc.free(res1.consensus);
        
        for (res2.aligned_sequences) |s| alloc.free(s);
        alloc.free(res2.aligned_sequences);
        alloc.free(res2.consensus);
    }
    
    try std.testing.expectEqualStrings(res1.consensus, res2.consensus);
    try std.testing.expectEqualStrings(res1.aligned_sequences[0], res2.aligned_sequences[0]);
    try std.testing.expectEqualStrings(res1.aligned_sequences[1], res2.aligned_sequences[1]);
    try std.testing.expectEqualStrings(res1.aligned_sequences[2], res2.aligned_sequences[2]);
}

test "Tier 1.4: TiMSA Memory Budget enforcement (fail-fast if too low)" {
    const alloc = std.testing.allocator;
    // Tiny memory budget to force an error. SRF enforces budget checks.
    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 10 });
    
    var sequences = [_][]const u8{
        "GATTACAGATTACA",
        "GATCACAGATCACA",
    };
    
    const res = ms.executeAlignment(&sequences);
    try std.testing.expectError(error.OutOfMemoryBudget, res);
}

test "Tier 1.5: TiMSA Exhaustive Edge Cases (empty sequences, unequal extremes, total mismatches)" {
    const alloc = std.testing.allocator;
    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    
    // Case 1: Total mismatches
    var seq_mismatch = [_][]const u8{
        "AAAA",
        "TTTT",
        "GGGG",
    };
    
    const res_mismatch = try ms.executeAlignment(&seq_mismatch);
    defer {
        for (res_mismatch.aligned_sequences) |s| alloc.free(s);
        alloc.free(res_mismatch.aligned_sequences);
        alloc.free(res_mismatch.consensus);
    }
    try std.testing.expect(res_mismatch.aligned_sequences.len == 3);
    
    // Case 2: One empty sequence and one normal
    var seq_empty = [_][]const u8{
        "",
        "ATGC",
    };
    
    const res_empty = try ms.executeAlignment(&seq_empty);
    defer {
        for (res_empty.aligned_sequences) |s| alloc.free(s);
        alloc.free(res_empty.aligned_sequences);
        alloc.free(res_empty.consensus);
    }
    try std.testing.expectEqualStrings("ATGC", res_empty.consensus);
    try std.testing.expectEqualStrings("----", res_empty.aligned_sequences[0]);
    try std.testing.expectEqualStrings("ATGC", res_empty.aligned_sequences[1]);
    
    // Case 3: Both empty
    var seq_both_empty = [_][]const u8{
        "",
        "",
    };
    
    const res_both_empty = try ms.executeAlignment(&seq_both_empty);
    defer {
        for (res_both_empty.aligned_sequences) |s| alloc.free(s);
        alloc.free(res_both_empty.aligned_sequences);
        alloc.free(res_both_empty.consensus);
    }
    try std.testing.expectEqualStrings("", res_both_empty.consensus);
    try std.testing.expectEqualStrings("", res_both_empty.aligned_sequences[0]);
    try std.testing.expectEqualStrings("", res_both_empty.aligned_sequences[1]);
}

test "Tier 2.1: TiMSA Protein integration (5-bit packed Amino Acids)" {
    const alloc = std.testing.allocator;
    const protein_mod = @import("molecular").protein;

    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    ms.config.match_score = 5;
    ms.config.mismatch_score = -4;

    const raw_seqs = [_][]const u8{
        "MKTIIALSYIFCLVFADYKDDDDK",
        "MKTIIALSYIFCLVFADYK",
        "MKTIIALSYIFCLVF",
    };

    // Pack into Protein structures
    var proteins = std.ArrayList(protein_mod.Protein).empty;
    defer {
        for (proteins.items) |*p| p.deinit();
        proteins.deinit(alloc);
    }

    for (raw_seqs) |rs| {
        try proteins.append(alloc, try protein_mod.Protein.init(rs, alloc));
    }

    // Unpack for TiMSA
    var str_seqs = std.ArrayList([]const u8).empty;
    defer {
        for (str_seqs.items) |s| alloc.free(s);
        str_seqs.deinit(alloc);
    }

    for (proteins.items) |p| {
        var view = p.view();
        var str = try alloc.alloc(u8, view.len);
        for (0..view.len) |i| {
            str[i] = protein_mod.aminoAcidToChar(view.get(i));
        }
        try str_seqs.append(alloc, str);
    }

    const res = try ms.executeAlignment(str_seqs.items);
    defer {
        for (res.aligned_sequences) |s| alloc.free(s);
        alloc.free(res.aligned_sequences);
        alloc.free(res.consensus);
    }

    try std.testing.expectEqual(raw_seqs.len, res.aligned_sequences.len);
    // Print the consensus to visually confirm it merged them properly
    // std.debug.print("Protein Consensus: {s}\n", .{res.consensus});
}

test "Tier 2.1.1: TiMSA Protein Edge Cases" {
    const alloc = std.testing.allocator;
    const protein_mod = @import("molecular").protein;

    var ms = timsa.TiMSA.init(alloc, .{ .memory_budget_bytes = 100 * 1024 * 1024 });
    
    // Test A: Empty Proteins
    {
        var p1 = try protein_mod.Protein.init("", alloc);
        defer p1.deinit();
        var p2 = try protein_mod.Protein.init("", alloc);
        defer p2.deinit();

        var seqs = [_][]const u8{ "", "" };
        const res = try ms.executeAlignment(&seqs);
        defer {
            for (res.aligned_sequences) |s| alloc.free(s);
            alloc.free(res.aligned_sequences);
            alloc.free(res.consensus);
        }
        try std.testing.expectEqualStrings("", res.consensus);
    }

    // Test B: Identical Proteins
    {
        var seqs = [_][]const u8{ "MKVLA", "MKVLA", "MKVLA" };
        const res = try ms.executeAlignment(&seqs);
        defer {
            for (res.aligned_sequences) |s| alloc.free(s);
            alloc.free(res.aligned_sequences);
            alloc.free(res.consensus);
        }
        try std.testing.expectEqualStrings("MKVLA", res.consensus);
    }

    // Test C: Completely distinct Proteins (All mismatches)
    {
        var seqs = [_][]const u8{ "AAAA", "DDDD", "WWWW" };
        const res = try ms.executeAlignment(&seqs);
        defer {
            for (res.aligned_sequences) |s| alloc.free(s);
            alloc.free(res.aligned_sequences);
            alloc.free(res.consensus);
        }
        try std.testing.expect(res.consensus.len >= 4);
    }
}
