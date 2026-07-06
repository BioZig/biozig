const std = @import("std");
const core = @import("core");
const c_api = @import("c_api.zig");
const population = @import("population");
const algorithms = @import("algorithms");

// --- population/ld.zig ---
const ld = population.ld;

export fn biozig_ld_record_create(locus_a: [*c]const u8, locus_b: [*c]const u8, r2: f64, dp: f64) callconv(.c) ?*ld.LinkageDisequilibriumRecord {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(ld.LinkageDisequilibriumRecord) catch return null;
    ptr.* = ld.LinkageDisequilibriumRecord.init(alloc, std.mem.span(locus_a), std.mem.span(locus_b), r2, dp) catch return null;
    return ptr;
}

export fn biozig_ld_matrix_create(loci: [*c][*c]const u8, num_loci: usize) callconv(.c) ?*ld.LDMatrix {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();

    var loci_slice = alloc.alloc([]const u8, num_loci) catch return null;
    for (0..num_loci) |i| {
        loci_slice[i] = std.mem.span(loci[i]);
    }

    const ptr = alloc.create(ld.LDMatrix) catch return null;
    ptr.* = ld.LDMatrix.init(alloc, loci_slice) catch return null;
    return ptr;
}

export fn biozig_ld_matrix_set(matrix: ?*ld.LDMatrix, i: usize, j: usize, r2: f64, dp: f64) callconv(.c) void {
    if (matrix) |m| {
        m.set(i, j, r2, dp);
    }
}

pub const CBiozigLDStats = extern struct {
    r_squared: f64,
    d_prime: f64,
};

export fn biozig_ld_matrix_get(matrix: ?*ld.LDMatrix, i: usize, j: usize) callconv(.c) CBiozigLDStats {
    if (matrix) |m| {
        const res = m.get(i, j);
        return .{ .r_squared = res.r_squared, .d_prime = res.d_prime };
    }
    return .{ .r_squared = 0.0, .d_prime = 0.0 };
}

// --- population/gwas.zig ---
const gwas = population.gwas;

export fn biozig_gwas_record_create(variant_id: [*c]const u8, trait_id: [*c]const u8, p_value: f64, effect_size: f64, ci_lower: f64, ci_upper: f64) callconv(.c) ?*gwas.AssociationRecord {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(gwas.AssociationRecord) catch return null;
    ptr.* = gwas.AssociationRecord.init(alloc, std.mem.span(variant_id), std.mem.span(trait_id), p_value, effect_size, ci_lower, ci_upper) catch return null;
    return ptr;
}

export fn biozig_gwas_collection_create() callconv(.c) ?*gwas.AssociationCollection {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(gwas.AssociationCollection) catch return null;
    ptr.* = gwas.AssociationCollection.init(alloc);
    return ptr;
}

export fn biozig_gwas_collection_add(col: ?*gwas.AssociationCollection, rec: ?*gwas.AssociationRecord) callconv(.c) c_int {
    if (col == null or rec == null) return -1;
    col.?.addRecord(rec.?.*) catch return -1;
    return 0;
}

// --- population/epidemiology.zig ---
const epi = population.epidemiology;

export fn biozig_epi_cohort_create(id: [*c]const u8, name: [*c]const u8, size: usize) callconv(.c) ?*epi.Cohort {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(epi.Cohort) catch return null;
    ptr.* = epi.Cohort.init(alloc, std.mem.span(id), std.mem.span(name), size) catch return null;
    return ptr;
}

export fn biozig_epi_case_control_study_create(id: [*c]const u8, cases: ?*epi.Cohort, controls: ?*epi.Cohort) callconv(.c) ?*epi.CaseControlStudy {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    if (cases == null or controls == null) return null;
    const ptr = alloc.create(epi.CaseControlStudy) catch return null;
    ptr.* = epi.CaseControlStudy.init(alloc, std.mem.span(id), cases.?.*, controls.?.*) catch return null;
    return ptr;
}

export fn biozig_epi_case_control_study_add_assoc(study: ?*epi.CaseControlStudy, exp_id: [*c]const u8, out_id: [*c]const u8, measure: [*c]const u8, val: f64, lower: f64, upper: f64, p: f64) callconv(.c) c_int {
    if (study == null) return -1;
    study.?.addAssociation(std.mem.span(exp_id), std.mem.span(out_id), std.mem.span(measure), val, lower, upper, p) catch return -1;
    return 0;
}

// --- population/haplotype.zig ---
const hap = population.haplotype;

export fn biozig_haplotype_create(id: [*c]const u8, chrom: [*c]const u8, start_pos: usize, end_pos: usize) callconv(.c) ?*hap.Haplotype {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(hap.Haplotype) catch return null;
    ptr.* = hap.Haplotype.init(alloc, std.mem.span(id), std.mem.span(chrom), start_pos, end_pos) catch return null;
    return ptr;
}

export fn biozig_haplotype_add_variant(h: ?*hap.Haplotype, var_id: [*c]const u8, allele: [*c]const u8) callconv(.c) c_int {
    if (h == null) return -1;
    h.?.addVariant(std.mem.span(var_id), std.mem.span(allele)) catch return -1;
    return 0;
}

// --- population/ancestry.zig ---
const ancestry = population.ancestry;

export fn biozig_ancestry_population_create(id: [*c]const u8, name: [*c]const u8) callconv(.c) ?*ancestry.Population {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(ancestry.Population) catch return null;
    ptr.* = ancestry.Population.init(alloc, std.mem.span(id), std.mem.span(name)) catch return null;
    return ptr;
}

export fn biozig_ancestry_graph_create() callconv(.c) ?*ancestry.AncestryGraph {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(ancestry.AncestryGraph) catch return null;
    ptr.* = ancestry.AncestryGraph.init(alloc);
    return ptr;
}

export fn biozig_ancestry_graph_add_population(graph: ?*ancestry.AncestryGraph, pop: ?*ancestry.Population) callconv(.c) c_int {
    if (graph == null or pop == null) return -1;
    graph.?.addPopulation(pop.?.*) catch return -1;
    return 0;
}

// --- population/selection.zig ---
const selection = population.selection;

export fn biozig_selection_signal_create(locus: [*c]const u8, stat_name: [*c]const u8, stat_val: f64) callconv(.c) ?*selection.SelectionSignal {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(selection.SelectionSignal) catch return null;
    ptr.* = selection.SelectionSignal.init(alloc, std.mem.span(locus), std.mem.span(stat_name), stat_val) catch return null;
    return ptr;
}

export fn biozig_selection_collection_create() callconv(.c) ?*selection.SelectionCollection {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(selection.SelectionCollection) catch return null;
    ptr.* = selection.SelectionCollection.init(alloc);
    return ptr;
}

export fn biozig_selection_collection_add(col: ?*selection.SelectionCollection, sig: ?*selection.SelectionSignal) callconv(.c) c_int {
    if (col == null or sig == null) return -1;
    col.?.addSignal(sig.?.*) catch return -1;
    return 0;
}

// --- population/genotype.zig ---
const pop_geno = population.genotype;

export fn biozig_pop_genotypes_create(num_variants: usize, num_samples: usize) callconv(.c) ?*pop_geno.BitpackedGenotypes {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(pop_geno.BitpackedGenotypes) catch return null;
    ptr.* = pop_geno.BitpackedGenotypes.init(alloc, num_variants, num_samples) catch return null;
    return ptr;
}

export fn biozig_pop_genotypes_set(g: ?*pop_geno.BitpackedGenotypes, var_idx: usize, sample_idx: usize, state: u8) callconv(.c) void {
    if (g) |geno| {
        geno.set(var_idx, sample_idx, @as(pop_geno.GenotypeState, @enumFromInt(@as(u2, @intCast(state)))));
    }
}

export fn biozig_pop_genotypes_get(g: ?*pop_geno.BitpackedGenotypes, var_idx: usize, sample_idx: usize) callconv(.c) u8 {
    if (g) |geno| {
        return @as(u8, @intFromEnum(geno.get(var_idx, sample_idx)));
    }
    return 0;
}

// --- algorithms/population/population.zig ---
const pop_algo = algorithms.population;

pub const CBiozigAlgLDStats = extern struct {
    d: f64,
    d_prime: f64,
    r_squared: f64,
};

export fn biozig_alg_compute_ld(pA: f64, pB: f64, pAB: f64) callconv(.c) CBiozigAlgLDStats {
    const res = pop_algo.computeLD(pA, pB, pAB);
    return .{ .d = res.d, .d_prime = res.d_prime, .r_squared = res.r_squared };
}

pub const CBiozigEpiSummary = extern struct {
    incidence_rate: f64,
    prevalence: f64,
    case_fatality_ratio: f64,
};

export fn biozig_alg_compute_epi_summary(pop_size: usize, new_cases: usize, total_cases: usize, deaths: usize) callconv(.c) CBiozigEpiSummary {
    const res = pop_algo.computeEpidemiologicalSummary(pop_size, new_cases, total_cases, deaths);
    return .{ .incidence_rate = res.incidence_rate, .prevalence = res.prevalence, .case_fatality_ratio = res.case_fatality_ratio };
}

export fn biozig_alg_hwe_exact_test(obs_aa: usize, obs_ab: usize, obs_bb: usize) callconv(.c) f64 {
    return pop_algo.hweExactTest(obs_aa, obs_ab, obs_bb);
}

pub const CBiozigFStats = extern struct {
    fis: f64,
    fst: f64,
    fit: f64,
};

export fn biozig_alg_compute_f_stats(freqs: [*c]const f64, hets: [*c]const f64, sizes: [*c]const usize, count: usize) callconv(.c) CBiozigFStats {
    const f = freqs[0..count];
    const h = hets[0..count];
    const s = sizes[0..count];
    const res = pop_algo.computeFStatistics(f, h, s);
    return .{ .fis = res.fis, .fst = res.fst, .fit = res.fit };
}

export fn biozig_alg_haplotypes_create(num_indiv: usize, num_loci: usize) callconv(.c) ?*pop_algo.BitpackedHaplotypes {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(pop_algo.BitpackedHaplotypes) catch return null;
    ptr.* = pop_algo.BitpackedHaplotypes.init(alloc, num_indiv, num_loci) catch return null;
    return ptr;
}

export fn biozig_alg_haplotypes_set(h: ?*pop_algo.BitpackedHaplotypes, locus: usize, ind: usize, val: u8) callconv(.c) void {
    if (h) |h_ptr| h_ptr.set(locus, ind, @as(u1, @intCast(val & 1)));
}

export fn biozig_alg_haplotypes_get(h: ?*pop_algo.BitpackedHaplotypes, locus: usize, ind: usize) callconv(.c) u8 {
    if (h) |h_ptr| return @as(u8, h_ptr.get(locus, ind));
    return 0;
}

export fn biozig_alg_haplotypes_freq(h: ?*pop_algo.BitpackedHaplotypes, locus: usize) callconv(.c) f64 {
    if (h) |h_ptr| return h_ptr.alleleFrequency(locus);
    return 0.0;
}

export fn biozig_alg_genotypes_create(num_indiv: usize, num_loci: usize) callconv(.c) ?*pop_algo.BitpackedGenotypes {
    const arena = c_api.c_arena orelse return null;
    const alloc = arena.allocator();
    const ptr = alloc.create(pop_algo.BitpackedGenotypes) catch return null;
    ptr.* = pop_algo.BitpackedGenotypes.init(alloc, num_indiv, num_loci) catch return null;
    return ptr;
}

export fn biozig_alg_genotypes_set(g: ?*pop_algo.BitpackedGenotypes, locus: usize, ind: usize, val: u8) callconv(.c) void {
    if (g) |geno| geno.set(locus, ind, @as(u2, @intCast(val & 3)));
}

export fn biozig_alg_genotypes_get(g: ?*pop_algo.BitpackedGenotypes, locus: usize, ind: usize) callconv(.c) u8 {
    if (g) |geno| return @as(u8, geno.get(locus, ind));
    return 0;
}

export fn biozig_alg_genotypes_freq_alt(g: ?*pop_algo.BitpackedGenotypes, locus: usize) callconv(.c) f64 {
    if (g) |geno| return geno.alleleFrequencyAlt(locus);
    return 0.0;
}

// --- algorithms/variant/variant.zig ---
const variant = algorithms.variant;

pub const CBiozigVariantParams = extern struct {
    chrom: [*c]const u8,
    pos: usize,
    ref: [*c]const u8,
    alt: [*c]const u8,
};

export fn biozig_alg_variant_is_match(a: CBiozigVariantParams, b: CBiozigVariantParams) callconv(.c) c_int {
    const va = variant.VariantParams{ .chrom = std.mem.span(a.chrom), .pos = a.pos, .ref = std.mem.span(a.ref), .alt = std.mem.span(a.alt) };
    const vb = variant.VariantParams{ .chrom = std.mem.span(b.chrom), .pos = b.pos, .ref = std.mem.span(b.ref), .alt = std.mem.span(b.alt) };
    return if (variant.isMatch(va, vb)) 1 else 0;
}

export fn biozig_alg_variant_is_overlap(a: CBiozigVariantParams, b: CBiozigVariantParams) callconv(.c) c_int {
    const va = variant.VariantParams{ .chrom = std.mem.span(a.chrom), .pos = a.pos, .ref = std.mem.span(a.ref), .alt = std.mem.span(a.alt) };
    const vb = variant.VariantParams{ .chrom = std.mem.span(b.chrom), .pos = b.pos, .ref = std.mem.span(b.ref), .alt = std.mem.span(b.alt) };
    return if (variant.isOverlap(va, vb)) 1 else 0;
}

pub const CBiozigVariantStats = extern struct {
    total_variants: usize,
    transitions: usize,
    transversions: usize,
    ts_tv_ratio: f64,
    insertions: usize,
    deletions: usize,
};

export fn biozig_alg_variant_compute_stats(vars: [*c]const CBiozigVariantParams, count: usize) callconv(.c) CBiozigVariantStats {
    const arena = c_api.c_arena orelse return std.mem.zeroes(CBiozigVariantStats);
    const alloc = arena.allocator();

    var v_slice = alloc.alloc(variant.VariantParams, count) catch return std.mem.zeroes(CBiozigVariantStats);
    for (0..count) |i| {
        v_slice[i] = variant.VariantParams{
            .chrom = std.mem.span(vars[i].chrom),
            .pos = vars[i].pos,
            .ref = std.mem.span(vars[i].ref),
            .alt = std.mem.span(vars[i].alt),
        };
    }

    const stats = variant.computeStatistics(v_slice);
    return .{
        .total_variants = stats.total_variants,
        .transitions = stats.transitions,
        .transversions = stats.transversions,
        .ts_tv_ratio = stats.ts_tv_ratio,
        .insertions = stats.insertions,
        .deletions = stats.deletions,
    };
}
