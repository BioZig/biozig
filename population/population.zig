pub const gwas = @import("gwas/gwas.zig");
pub const haplotype = @import("haplotype/haplotype.zig");
pub const ld = @import("ld/ld.zig");
pub const ancestry = @import("ancestry/ancestry.zig");
pub const selection = @import("selection/selection.zig");
pub const epidemiology = @import("epidemiology/epidemiology.zig");
pub const genotype = @import("genotype/genotype.zig");

test {
    _ = gwas;
    _ = haplotype;
    _ = ld;
    _ = ancestry;
    _ = selection;
    _ = epidemiology;
    _ = genotype;
}
