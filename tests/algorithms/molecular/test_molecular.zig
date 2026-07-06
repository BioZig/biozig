const std = @import("std");
const testing = std.testing;
const alg = @import("algorithms");
const mol = alg.molecular;

test "Molecular - Module Declarations" {
    testing.refAllDecls(mol);
    testing.refAllDecls(mol.msa);
    testing.refAllDecls(mol.search);
    testing.refAllDecls(mol.suffix_tree);
}
