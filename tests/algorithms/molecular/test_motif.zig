const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;
const motif = mol.motif;
const molecular = @import("molecular");
const dna = molecular.dna;

test "searchMotifExact - Empty sequence and empty motif" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("", alloc);
    defer seq.deinit();
    var m = try dna.DNA2.init("", alloc);
    defer m.deinit();
    
    const res = try motif.searchMotifExact(alloc, seq.view(), m.view());
    defer alloc.free(res);
    try testing.expectEqual(@as(usize, 0), res.len);
}

test "searchMotifExact - Motif longer than sequence" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("AT", alloc);
    defer seq.deinit();
    var m = try dna.DNA2.init("ATG", alloc);
    defer m.deinit();
    
    const res = try motif.searchMotifExact(alloc, seq.view(), m.view());
    defer alloc.free(res);
    try testing.expectEqual(@as(usize, 0), res.len);
}

test "searchMotifExact - Normal Match" {
    const alloc = testing.allocator;
    var seq = try dna.DNA2.init("GATTACAGAT", alloc);
    defer seq.deinit();
    
    var m = try dna.DNA2.init("GAT", alloc);
    defer m.deinit();

    const res = try motif.searchMotifExact(alloc, seq.view(), m.view());
    defer alloc.free(res);
    
    try testing.expectEqual(@as(usize, 2), res.len);
    try testing.expectEqual(@as(usize, 0), res[0]);
    try testing.expectEqual(@as(usize, 7), res[1]);
}

test "PWM - Empty Sequence" {
    const alloc = testing.allocator;
    const pwm_data = [_][4]f64{
        .{ 0.1, 0.1, 0.1, 0.9 },
    };
    const pwm = motif.PWM{ .matrix = &pwm_data };
    
    var seq = try dna.DNA2.init("", alloc);
    defer seq.deinit();
    
    const hits = try pwm.scanThreshold(alloc, seq.view(), 0.0);
    defer alloc.free(hits);
    try testing.expectEqual(@as(usize, 0), hits.len);
}

test "PWM - Normal Match" {
    const alloc = testing.allocator;
    const pwm_data = [_][4]f64{
        .{ 0.1, 0.1, 0.1, 0.9 }, // T
        .{ 0.9, 0.1, 0.1, 0.1 }, // A
        .{ 0.1, 0.1, 0.1, 0.9 }, // T
        .{ 0.9, 0.1, 0.1, 0.1 }, // A
    };
    const pwm = motif.PWM{ .matrix = &pwm_data };

    var seq = try dna.DNA2.init("GCTATAAA", alloc);
    defer seq.deinit();

    const hits = try pwm.scanThreshold(alloc, seq.view(), 3.0);
    defer alloc.free(hits);

    try testing.expectEqual(@as(usize, 1), hits.len);
    try testing.expectEqual(@as(usize, 2), hits[0].position);
    try testing.expect(hits[0].score > 3.5);
}

test "PWM - Threshold NaNs or Edge" {
    const alloc = testing.allocator;
    const pwm_data = [_][4]f64{
        .{ 0.1, 0.1, 0.1, 0.9 }, // T
    };
    const pwm = motif.PWM{ .matrix = &pwm_data };

    var seq = try dna.DNA2.init("T", alloc);
    defer seq.deinit();

    const hits = try pwm.scanThreshold(alloc, seq.view(), std.math.nan(f64));
    defer alloc.free(hits);
    // score >= NaN evaluates to false
    try testing.expectEqual(@as(usize, 0), hits.len);
}
