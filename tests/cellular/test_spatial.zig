const std = @import("std");
const testing = std.testing;
const cellular = @import("cellular");
const spatial = cellular.spatial;

test "SpatialCell - Distance Calculation 2D" {
    const c1 = spatial.SpatialCell{ .x = 0.0, .y = 0.0, .z = 0.0 };
    const c2 = spatial.SpatialCell{ .x = 3.0, .y = 4.0, .z = 0.0 };
    try testing.expectEqual(@as(f64, 5.0), c1.distanceTo(c2));
}

test "SpatialCell - Distance Calculation 3D" {
    const c1 = spatial.SpatialCell{ .x = 0.0, .y = 0.0, .z = 0.0 };
    const c2 = spatial.SpatialCell{ .x = 1.0, .y = 2.0, .z = 2.0 };
    try testing.expectEqual(@as(f64, 3.0), c1.distanceTo(c2));
}

test "SpatialCell - NaN handling" {
    const nan = std.math.nan(f64);
    const c1 = spatial.SpatialCell{ .x = nan, .y = 0.0, .z = 0.0 };
    const c2 = spatial.SpatialCell{ .x = 0.0, .y = 0.0, .z = 0.0 };
    const dist = c1.distanceTo(c2);
    try testing.expect(std.math.isNan(dist));
}
