const std = @import("std");
const algorithms = @import("algorithms");
const timsa = algorithms.molecular.timsa;
const testing = std.testing;

test "TiMSA - Single sequence edge case" {
    var seqs = [_][]const u8{"ACGTACGT"};
    const config = timsa.TiMSAConfig{
        .mode = .Align,
    };
    var ms = timsa.TiMSA.init(testing.allocator, config);
    const dummy_mat = algorithms.molecular.matrices.SubstitutionMatrix.init(.BLOSUM62);
    ms.sub_matrix = &dummy_mat;
    
    const result = try ms.executeAlignment(seqs[0..]);
    defer {
        for (result.aligned_sequences) |s| testing.allocator.free(s);
        testing.allocator.free(result.aligned_sequences);
        testing.allocator.free(result.consensus);
    }
    
    try testing.expectEqual(@as(usize, 1), result.aligned_sequences.len);
    try testing.expectEqualStrings("ACGTACGT", result.aligned_sequences[0]);
    try testing.expectEqualStrings("ACGTACGT", result.consensus);
}

test "TiMSA - Cluster mode early exit" {
    var seqs = [_][]const u8{
        "ACGTACGTACGTACGT",
        "ACGTACGTACGTACGT",
        "TGCATGCATGCATGCA",
    };
    const config = timsa.TiMSAConfig{
        .mode = .Cluster,
    };
    var ms = timsa.TiMSA.init(testing.allocator, config);
    
    const result = try ms.executeAlignment(seqs[0..]);
    defer {
        for (result.aligned_sequences) |s| testing.allocator.free(s);
        testing.allocator.free(result.aligned_sequences);
        testing.allocator.free(result.consensus);
    }
    
    try testing.expectEqual(@as(usize, 3), result.aligned_sequences.len);
    // Cluster mode should return the unaligned sequences
    try testing.expectEqualStrings("ACGTACGTACGTACGT", result.aligned_sequences[0]);
    try testing.expectEqualStrings("", result.consensus);
}

test "TiMSA - Completely orthogonal sequences (No match)" {
    var seqs = [_][]const u8{
        "AAAAAAAAAAAAA",
        "CCCCCCCCCCCCC",
    };
    const config = timsa.TiMSAConfig{
        .mode = .Align,
        .refinement_strategy = .Targeted,
    };
    var ms = timsa.TiMSA.init(testing.allocator, config);
    const dummy_mat = algorithms.molecular.matrices.SubstitutionMatrix.init(.BLOSUM62);
    ms.sub_matrix = &dummy_mat;
    
    const result = try ms.executeAlignment(seqs[0..]);
    defer {
        for (result.aligned_sequences) |s| testing.allocator.free(s);
        testing.allocator.free(result.aligned_sequences);
        testing.allocator.free(result.consensus);
    }
    
    try testing.expectEqual(@as(usize, 2), result.aligned_sequences.len);
    // We just verify it doesn't crash and returns valid slices.
    try testing.expect(result.aligned_sequences[0].len >= 13);
    try testing.expect(result.aligned_sequences[1].len >= 13);
}

test "TiMSA - Domain (Local) mode isolation" {
    var seqs = [_][]const u8{
        "XXXXXACGTXXXXX",
        "YYYYYACGTYYYYY",
    };
    const config = timsa.TiMSAConfig{
        .mode = .Domain,
        .recurrence_type = .Local,
        .refinement_strategy = .None,
    };
    var ms = timsa.TiMSA.init(testing.allocator, config);
    const dummy_mat = algorithms.molecular.matrices.SubstitutionMatrix.init(.BLOSUM62);
    ms.sub_matrix = &dummy_mat;
    
    const result = try ms.executeAlignment(seqs[0..]);
    defer {
        for (result.aligned_sequences) |s| testing.allocator.free(s);
        testing.allocator.free(result.aligned_sequences);
        testing.allocator.free(result.consensus);
    }
    
    // As it uses NW in Phase 3/4 internally, we just ensure local recurrence config runs without OOM.
    try testing.expectEqual(@as(usize, 2), result.aligned_sequences.len);
}
