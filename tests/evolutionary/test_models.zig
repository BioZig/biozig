const std = @import("std");
const testing = std.testing;

const evolutionary = @import("evolutionary");

test "SubstitutionModels JC69" {
    const d1 = evolutionary.SubstitutionModels.JC69.distance(0.0);
    try testing.expectEqual(@as(f64, 0.0), d1);

    const d2 = evolutionary.SubstitutionModels.JC69.distance(0.75);
    try testing.expectEqual(std.math.inf(f64), d2);

    const d3 = evolutionary.SubstitutionModels.JC69.distance(0.5);
    try testing.expect(d3 > 0.0);
}

test "SubstitutionModels K80" {
    const d1 = evolutionary.SubstitutionModels.K80.distance(0.0, 0.0);
    try testing.expectEqual(@as(f64, 0.0), d1);

    const d2 = evolutionary.SubstitutionModels.K80.distance(0.5, 0.5);
    try testing.expectEqual(std.math.inf(f64), d2);
}
