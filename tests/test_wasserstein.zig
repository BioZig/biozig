const std = @import("std");
const wasserstein = @import("ATLAZ").wasserstein;
const sparse = @import("analytics").matrix.sparse;

// Helper to construct mock persistence pairs with f64 filtration values stored as ints
// (In a real scenario they are scaled or actual pointers to simplex indices mapped to floats)
fn makePair(birth: f64, death: f64) sparse.PersistencePair {
    return .{
        .birth = @intFromFloat(birth),
        .death = @intFromFloat(death),
        .dimension = 1,
    };
}

test "Wasserstein: Identity Test (Distance to self is 0)" {
    const allocator = std.testing.allocator;
    
    var diagram = [_]sparse.PersistencePair{
        makePair(0.0, 1.0),
        makePair(1.0, 2.0),
        makePair(2.0, 3.0),
    };
    
    const dist = try wasserstein.wassersteinDistance(allocator, &diagram, &diagram);
    try std.testing.expect(@abs(dist - 0.0) < 0.0001);
}

test "Wasserstein: Shifted Diagram Test" {
    const allocator = std.testing.allocator;
    
    // To represent 0.5 we need an integer representation or we can just use large integers 
    // to simulate the shift.
    // Since our metric maps birth/death from integers to f64 directly, we can just use integers.
    // We will shift by 5 units, expect distance sqrt(5^2 + 5^2) = sqrt(50) per point.
    // For 3 points, total distance = 3 * sqrt(50) = 3 * 7.0710678 = 21.2132
    
    var diagram_a = [_]sparse.PersistencePair{
        makePair(0.0, 10.0),
        makePair(10.0, 20.0),
        makePair(20.0, 30.0),
    };
    
    var diagram_b = [_]sparse.PersistencePair{
        makePair(5.0, 15.0),
        makePair(15.0, 25.0),
        makePair(25.0, 35.0),
    };
    
    const dist = try wasserstein.wassersteinDistance(allocator, &diagram_a, &diagram_b);
    
    const expected_per_point = @sqrt(25.0 + 25.0); // sqrt(50)
    const expected_total = 3.0 * expected_per_point;
    
    try std.testing.expect(@abs(dist - expected_total) < 0.0001);
}

test "Wasserstein: Diagonal Matching Test" {
    const allocator = std.testing.allocator;
    
    // Point A: (0, 0)
    var diagram_a = [_]sparse.PersistencePair{ makePair(0.0, 0.0) };
    var empty_b = [_]sparse.PersistencePair{};
    
    const dist_zero = try wasserstein.wassersteinDistance(allocator, &diagram_a, &empty_b);
    try std.testing.expect(@abs(dist_zero - 0.0) < 0.0001);
    
    // Point A: (50, 100). Distance to diagonal = (100 - 50) / 2 = 25.
    var diagram_a2 = [_]sparse.PersistencePair{ makePair(50.0, 100.0) };
    
    const dist_diag = try wasserstein.wassersteinDistance(allocator, &diagram_a2, &empty_b);
    try std.testing.expect(@abs(dist_diag - 25.0) < 0.0001);
}
