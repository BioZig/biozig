const std = @import("std");
const structural = @import("structural");
const chain = structural.chain;
const residue = structural.residue;
const atom = structural.atom;
const geometry = structural.geometry;
const testing = std.testing;

test "Chain reconstruct, type, and basics" {
    const alloc = testing.allocator;
    const a1 = try atom.Atom.init(1, "CA", .C, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    var atoms1 = try alloc.alloc(atom.Atom, 1);
    defer alloc.free(atoms1);
    atoms1[0] = a1;
    const r1 = try residue.Residue.init(1, "ALA", atoms1);

    const a2 = try atom.Atom.init(2, "CA", .C, geometry.Vec3.init(1.0, 0.0, 0.0), 1.0, 20.0, null);
    var atoms2 = try alloc.alloc(atom.Atom, 1);
    defer alloc.free(atoms2);
    atoms2[0] = a2;
    const r2 = try residue.Residue.init(2, "GLY", atoms2);

    var residues = try alloc.alloc(residue.Residue, 2);
    defer alloc.free(residues);
    residues[0] = r1;
    residues[1] = r2;

    const c = try chain.Chain.init("A", residues);

    try testing.expectEqualStrings("A", c.getId());
    try testing.expectEqual(chain.ChainType.protein, c.determineType());

    const seq = try c.reconstructSequence(alloc);
    defer alloc.free(seq);
    try testing.expectEqualStrings("AG", seq);
    
    try testing.expect(c.lookupResidue(1) != null);
    try testing.expect(c.lookupResidue(3) == null);
    try testing.expectEqual(@as(usize, 2), c.len());
    
    const cent = c.centroid();
    try testing.expectApproxEqAbs(@as(f64, 0.5), cent.x, 1e-9);
}

test "Chain extreme cases (Empty, NaN coords, Large chains)" {
    const alloc = testing.allocator;
    // Empty chain
    const empty_residues = try alloc.alloc(residue.Residue, 0);
    defer alloc.free(empty_residues);
    
    const empty_chain = try chain.Chain.init("EM", empty_residues);
    try testing.expectEqualStrings("EM", empty_chain.getId());
    try testing.expectEqual(@as(usize, 0), empty_chain.len());
    try testing.expect(empty_chain.lookupResidue(1) == null);
    
    const cent = empty_chain.centroid();
    try testing.expectEqual(@as(f64, 0.0), cent.x);
    try testing.expectEqual(@as(f64, 0.0), cent.y);
    try testing.expectEqual(@as(f64, 0.0), cent.z);
    
    const empty_seq = try empty_chain.reconstructSequence(alloc);
    defer alloc.free(empty_seq);
    try testing.expectEqualStrings("", empty_seq);
}

test "Chain large payload and bounds checks" {
    const alloc = testing.allocator;
    const size = 1000;
    var large_residues = try alloc.alloc(residue.Residue, size);
    defer alloc.free(large_residues);
    
    for (0..size) |i| {
        // dummy residues
        const dummy_atoms = try alloc.alloc(atom.Atom, 0); // we can use empty residues
        defer alloc.free(dummy_atoms);
        large_residues[i] = try residue.Residue.init(i, "UNK", dummy_atoms);
    }
    
    const huge_chain = try chain.Chain.init("HU", large_residues);
    try testing.expectEqualStrings("HU", huge_chain.getId());
    
    try testing.expectEqual(@as(usize, 1000), huge_chain.len());
    
    const s = huge_chain.lookupResidue(500);
    try testing.expect(s != null);
    
    const oob = huge_chain.lookupResidue(999999);
    try testing.expect(oob == null);
}
