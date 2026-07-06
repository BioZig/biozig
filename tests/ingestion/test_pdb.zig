const std = @import("std");
const testing = std.testing;
const ingestion = @import("ingestion");
const pdb = ingestion.structural.pdb;

// ─── Happy Path ───────────────────────────────────────────────────────────────

test "pdb: parse 3 canonical ATOM records" {
    const data =
        "ATOM      1  N   ALA A   1      11.104   6.134  -6.504  1.00  0.00           N  \n" ++
        "ATOM      2  CA  ALA A   1      11.639   6.071  -5.147  1.00  0.00           C  \n" ++
        "ATOM      3  C   ALA A   1      10.825   5.052  -4.326  1.00  0.00           C  \n";
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 3), coords.len);
    try testing.expectEqual(@as(f64, 11.104), coords[0].x);
    try testing.expectEqual(@as(f64, 6.134), coords[0].y);
    try testing.expectEqual(@as(f64, -6.504), coords[0].z);
}

test "pdb: HETATM records are also parsed" {
    const data =
        "HETATM    1  C1  LIG A 201      10.000  20.000  30.000  1.00  0.00           C  \n";
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 1), coords.len);
    try testing.expectEqual(@as(f64, 10.0), coords[0].x);
}

test "pdb: non-ATOM/HETATM lines are ignored" {
    const data =
        "HEADER    HYDROLASE                                01-JAN-00   1ABC\n" ++
        "REMARK   1 REFERENCE 1\n" ++
        "SEQRES   1 A   10  ALA GLY SER\n" ++
        "ATOM      1  N   ALA A   1      1.000   2.000   3.000  1.00  0.00           N  \n";
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 1), coords.len);
}

test "pdb: empty file yields no coords" {
    const coords = try pdb.parsePdbCoords(testing.allocator, "");
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 0), coords.len);
}

test "pdb: file with only non-coord lines yields no coords" {
    const data = "HEADER    TEST\nREMARK   999\nEND\n";
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 0), coords.len);
}

// ─── Line Length Edge Cases ───────────────────────────────────────────────────

test "pdb: short ATOM line (<54 chars) is skipped, no crash" {
    // The parser requires len >= 54 to extract coordinates.
    const data = "ATOM      1  N   ALA A   1\n"; // only 26 chars
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 0), coords.len);
}

test "pdb: line with whitespace-padded coordinates parsed correctly" {
    // Coordinates are at fixed columns 30-38 (x), 38-46 (y), 46-54 (z) — must be trimmed
    const data =
        "ATOM      1  N   ALA A   1      1.001   2.002   3.003  1.00  0.00           N  \n";
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 1), coords.len);
}

test "pdb: negative coordinates parsed correctly" {
    const data =
        "ATOM      1  N   ALA A   1     -11.104  -6.134   6.504  1.00  0.00           N  \n";
    const coords = try pdb.parsePdbCoords(testing.allocator, data);
    defer testing.allocator.free(coords);
    try testing.expectEqual(@as(usize, 1), coords.len);
    try testing.expect(coords[0].x < 0.0);
    try testing.expect(coords[0].y < 0.0);
}

// ─── Streaming Iterator ───────────────────────────────────────────────────────

test "pdb: stream iterator returns null on empty buffer" {
    var stream = pdb.PdbCoordinateStream{ .buffer = "" };
    try testing.expectEqual(@as(?@import("structural").geometry.Vec3, null), try stream.next());
}

test "pdb: stream iterator correctly advances past multiple records" {
    const data =
        "ATOM      1  N   ALA A   1       1.0     2.0     3.0   1.00  0.00           N  \n" ++
        "ATOM      2  CA  ALA A   1       4.0     5.0     6.0   1.00  0.00           C  \n";
    var stream = pdb.PdbCoordinateStream{ .buffer = data };
    const v1 = (try stream.next()).?;
    try testing.expectEqual(@as(f64, 1.0), v1.x);
    const v2 = (try stream.next()).?;
    try testing.expectEqual(@as(f64, 4.0), v2.x);
    try testing.expectEqual(@as(?@import("structural").geometry.Vec3, null), try stream.next());
}
