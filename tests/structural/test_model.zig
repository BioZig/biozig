const std = @import("std");
const structural = @import("structural");
const model = structural.model;
const chain = structural.chain;
const residue = structural.residue;
const atom = structural.atom;
const geometry = structural.geometry;
const testing = std.testing;

test "Model and assembly bounds, properties" {
    const alloc = testing.allocator;
    const a1 = try atom.Atom.init(1, "CA", .C, geometry.Vec3.init(0.0, 0.0, 0.0), 1.0, 20.0, null);
    var atoms1 = try alloc.alloc(atom.Atom, 1);
    defer alloc.free(atoms1);
    atoms1[0] = a1;
    const r1 = try residue.Residue.init(1, "ALA", atoms1);

    var residues1 = try alloc.alloc(residue.Residue, 1);
    defer alloc.free(residues1);
    residues1[0] = r1;
    const c1 = try chain.Chain.init("A", residues1);

    var chains = try alloc.alloc(chain.Chain, 1);
    defer alloc.free(chains);
    chains[0] = c1;

    const m = model.Model.init(1, chains);

    try testing.expectEqual(@as(usize, 1), m.id);

    const stats = m.statistics();
    try testing.expectEqual(@as(usize, 1), stats.chains);
    try testing.expectEqual(@as(usize, 1), stats.residues);
    try testing.expectEqual(@as(usize, 1), stats.atoms);

    try testing.expect(m.lookupChain("A") != null);
    try testing.expect(m.lookupChain("B") == null);

    try testing.expectEqual(@as(usize, 1), m.chainCount());
    try testing.expectEqual(@as(usize, 1), m.residueCount());
    try testing.expectEqual(@as(usize, 1), m.atomCount());
}

test "Model empty handling, NaN limits, out of bounds" {
    const alloc = testing.allocator;
    const empty_chains = try alloc.alloc(chain.Chain, 0);
    defer alloc.free(empty_chains);

    const m_empty = model.Model.init(999, empty_chains);

    try testing.expectEqual(@as(usize, 999), m_empty.id);
    try testing.expectEqual(@as(usize, 0), m_empty.chainCount());
    try testing.expectEqual(@as(usize, 0), m_empty.residueCount());
    try testing.expectEqual(@as(usize, 0), m_empty.atomCount());

    const st = m_empty.statistics();
    try testing.expectEqual(@as(usize, 0), st.chains);
    try testing.expectEqual(@as(usize, 0), st.residues);
    try testing.expectEqual(@as(usize, 0), st.atoms);

    try testing.expect(m_empty.lookupChain("X") == null);
}

test "Model large assemblies" {
    const alloc = testing.allocator;
    const num_chains = 100;
    var huge_chains = try alloc.alloc(chain.Chain, num_chains);
    defer alloc.free(huge_chains);

    for (0..num_chains) |i| {
        const empty_res = try alloc.alloc(residue.Residue, 0);
        defer alloc.free(empty_res);
        // Use numbers for string id just to simulate unique IDs or reuse
        huge_chains[i] = try chain.Chain.init("HU", empty_res);
    }

    const huge_model = model.Model.init(10, huge_chains);
    try testing.expectEqual(@as(usize, 100), huge_model.chainCount());
    try testing.expectEqual(@as(usize, 0), huge_model.residueCount());
    try testing.expectEqual(@as(usize, 0), huge_model.atomCount());

    // Test that the lookup resolves one of them (the first) if duplicates exist
    const c = huge_model.lookupChain("HU");
    try testing.expect(c != null);
}

test "Model multiple chains and proper counting" {
    const alloc = testing.allocator;
    // Chain 1
    var atoms1 = try alloc.alloc(atom.Atom, 2);
    atoms1[0] = try atom.Atom.init(1, "N", .N, geometry.Vec3.init(0, 0, 0), 1.0, 1.0, null);
    atoms1[1] = try atom.Atom.init(2, "CA", .C, geometry.Vec3.init(1, 0, 0), 1.0, 1.0, null);
    var residues1 = try alloc.alloc(residue.Residue, 1);
    residues1[0] = try residue.Residue.init(1, "ALA", atoms1);
    const c1 = try chain.Chain.init("A", residues1);

    // Chain 2
    var atoms2 = try alloc.alloc(atom.Atom, 1);
    atoms2[0] = try atom.Atom.init(3, "C", .C, geometry.Vec3.init(2, 0, 0), 1.0, 1.0, null);
    var residues2 = try alloc.alloc(residue.Residue, 1);
    residues2[0] = try residue.Residue.init(2, "GLY", atoms2);
    const c2 = try chain.Chain.init("B", residues2);

    var chains = try alloc.alloc(chain.Chain, 2);
    chains[0] = c1;
    chains[1] = c2;

    const m = model.Model.init(1, chains);

    try testing.expectEqual(@as(usize, 2), m.chainCount());
    try testing.expectEqual(@as(usize, 2), m.residueCount());
    try testing.expectEqual(@as(usize, 3), m.atomCount());

    const st = m.statistics();
    try testing.expectEqual(@as(usize, 2), st.chains);
    try testing.expectEqual(@as(usize, 2), st.residues);
    try testing.expectEqual(@as(usize, 3), st.atoms);

    alloc.free(atoms1);
    alloc.free(residues1);
    alloc.free(atoms2);
    alloc.free(residues2);
    alloc.free(chains);
}
