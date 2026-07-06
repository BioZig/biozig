const std = @import("std");
const alg = @import("algorithms");
const mol = alg.molecular;
const hmm_mod = mol.hmm;

test "HMM - normal viterbi" {
    const alloc = std.testing.allocator;
    var hmm = try hmm_mod.HMM.init(alloc, 2, 2);
    defer hmm.deinit();

    hmm.initial_probs[0] = 0.6;
    hmm.initial_probs[1] = 0.4;

    hmm.transition_probs[0][0] = 0.7;
    hmm.transition_probs[0][1] = 0.3;
    hmm.transition_probs[1][0] = 0.4;
    hmm.transition_probs[1][1] = 0.6;

    hmm.emission_probs[0][0] = 0.5;
    hmm.emission_probs[0][1] = 0.5;
    hmm.emission_probs[1][0] = 0.1;
    hmm.emission_probs[1][1] = 0.9;

    const emissions = [_]usize{ 0, 1, 1 };
    const path = try hmm.viterbi(alloc, &emissions);
    defer alloc.free(path);

    try std.testing.expectEqual(@as(usize, 3), path.len);
    try std.testing.expectEqual(@as(usize, 0), path[0]);
    try std.testing.expectEqual(@as(usize, 1), path[1]);
    try std.testing.expectEqual(@as(usize, 1), path[2]);
}

test "HMM - empty emissions" {
    const alloc = std.testing.allocator;
    var hmm = try hmm_mod.HMM.init(alloc, 2, 2);
    defer hmm.deinit();

    const emissions = [_]usize{};
    const path = try hmm.viterbi(alloc, &emissions);
    defer alloc.free(path);

    try std.testing.expectEqual(@as(usize, 0), path.len);
}

test "HMM - single state" {
    const alloc = std.testing.allocator;
    var hmm = try hmm_mod.HMM.init(alloc, 1, 1);
    defer hmm.deinit();

    hmm.initial_probs[0] = 1.0;
    hmm.transition_probs[0][0] = 1.0;
    hmm.emission_probs[0][0] = 1.0;

    const emissions = [_]usize{ 0, 0, 0 };
    const path = try hmm.viterbi(alloc, &emissions);
    defer alloc.free(path);

    try std.testing.expectEqual(@as(usize, 3), path.len);
    for (path) |p| {
        try std.testing.expectEqual(@as(usize, 0), p);
    }
}

test "HMM - zero probability paths" {
    const alloc = std.testing.allocator;
    var hmm = try hmm_mod.HMM.init(alloc, 2, 2);
    defer hmm.deinit();

    hmm.initial_probs[0] = 1.0;
    hmm.initial_probs[1] = 0.0;

    hmm.transition_probs[0][0] = 0.0;
    hmm.transition_probs[0][1] = 1.0;
    hmm.transition_probs[1][0] = 1.0;
    hmm.transition_probs[1][1] = 0.0;

    hmm.emission_probs[0][0] = 1.0;
    hmm.emission_probs[0][1] = 0.0;
    hmm.emission_probs[1][0] = 0.0;
    hmm.emission_probs[1][1] = 1.0;

    const emissions = [_]usize{ 0, 1, 0, 1 };
    const path = try hmm.viterbi(alloc, &emissions);
    defer alloc.free(path);

    try std.testing.expectEqual(@as(usize, 4), path.len);
    try std.testing.expectEqual(@as(usize, 0), path[0]);
    try std.testing.expectEqual(@as(usize, 1), path[1]);
    try std.testing.expectEqual(@as(usize, 0), path[2]);
    try std.testing.expectEqual(@as(usize, 1), path[3]);
}

test "HMM - NaNs in probabilities" {
    const alloc = std.testing.allocator;
    var hmm = try hmm_mod.HMM.init(alloc, 2, 2);
    defer hmm.deinit();

    hmm.initial_probs[0] = std.math.nan(f64);
    hmm.initial_probs[1] = 0.4;

    hmm.transition_probs[0][0] = 0.7;
    hmm.transition_probs[0][1] = 0.3;
    hmm.transition_probs[1][0] = 0.4;
    hmm.transition_probs[1][1] = 0.6;

    hmm.emission_probs[0][0] = 0.5;
    hmm.emission_probs[0][1] = 0.5;
    hmm.emission_probs[1][0] = 0.1;
    hmm.emission_probs[1][1] = 0.9;

    const emissions = [_]usize{ 0, 1, 1 };
    const path = try hmm.viterbi(alloc, &emissions);
    defer alloc.free(path);

    // Verify it doesn't crash and returns a valid length path.
    try std.testing.expectEqual(@as(usize, 3), path.len);
}
