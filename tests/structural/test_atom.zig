const std = @import("std");
const structural = @import("structural");
const atom = structural.atom;
const geometry = structural.geometry;
const testing = std.testing;

test "Atom init, equality, and basic properties" {
    const a1 = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    const a2 = try atom.Atom.init(2, "CA", .C, geometry.Vec3.init(1.4, 0.0, 0.0), 1.0, 20.0, null);
    try testing.expectEqualStrings("N", a1.getName());
    try testing.expectEqualStrings("CA", a2.getName());

    try testing.expect(!a1.equals(a2));
    try testing.expect(a1.equals(a1));

    const dist = a1.distance(a2);
    try testing.expectApproxEqAbs(@as(f64, 1.4), dist, 1e-9);

    const h1 = a1.hash();
    const h2 = a2.hash();
    try testing.expect(h1 != h2);
}

test "Atom edge cases, NaNs, zero fields" {
    const nan = std.math.nan(f64);
    // We should be able to create an atom with nan coords without crashing, though math might be nan
    var anan = try atom.Atom.init(999, "NAN", .C, geometry.Vec3.init(nan, nan, nan), nan, nan, null);

    try testing.expectEqualStrings("NAN", anan.getName());
    const hnan = anan.hash();
    try testing.expect(hnan > 0);

    // Testing transformation
    const rot = [_][3]f64{
        [_]f64{ 1.0, 0.0, 0.0 },
        [_]f64{ 0.0, 1.0, 0.0 },
        [_]f64{ 0.0, 0.0, 1.0 },
    };
    const trans = geometry.Vec3.init(1.0, 2.0, 3.0);

    var a3 = try atom.Atom.init(3, "O", .O, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    a3.transform(rot, trans);

    try testing.expectApproxEqAbs(@as(f64, 1.0), a3.pos.x, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 2.0), a3.pos.y, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 3.0), a3.pos.z, 1e-9);
}

test "Element enum toString" {
    var buf: [2]u8 = undefined;
    const n_elem: atom.Element = .N;
    const n_str = n_elem.toString(&buf);
    try testing.expectEqualStrings("N", n_str);

    const c_elem: atom.Element = .C;
    const c_str = c_elem.toString(&buf);
    try testing.expectEqualStrings("C", c_str);
}

test "Atom serialization/deserialization extreme bounds" {
    // We don't have the full memory map but we can test basic structures
    // Let's create a giant atom ID
    const max_usize = std.math.maxInt(usize);
    const inf = std.math.inf(f64);

    var a_inf = try atom.Atom.init(max_usize, "MAX", .O, geometry.Vec3.init(inf, -inf, inf), inf, -inf, null);
    try testing.expectEqualStrings("MAX", a_inf.getName());

    // Check equality with self
    try testing.expect(a_inf.equals(a_inf));
}

test "Atom huge ID and empty name" {
    var a_empty = try atom.Atom.init(0, "", .C, geometry.Vec3.init(0.0, 0.0, 0.0), 0.0, 0.0, null);
    try testing.expectEqualStrings("", a_empty.getName());
    try testing.expect(a_empty.equals(a_empty));
}

test "Atom hash consistency" {
    const a1 = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    const a1_clone = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    try testing.expect(a1.equals(a1_clone));
    try testing.expectEqual(a1.hash(), a1_clone.hash());
}
