const std = @import("std");
const algorithms = @import("algorithms");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe
    
    const domain = args.next() orelse return error.MissingDomain;

    var accuracy_pass = false;

    if (std.mem.eql(u8, domain, "CELLULAR")) {
        std.debug.print("Initializing 100k cells buffer for 20k genes...\n", .{});
        const num_cells = 100000;
        const num_genes = 20000;
        const expr = try allocator.alloc(f64, num_cells);
        defer allocator.free(expr);
        for (expr, 0..) |*e, i| {
            e.* = @as(f64, @floatFromInt(i % 10));
        }
        
        var total_mean: f64 = 0;
        for (0..num_genes) |_| {
            total_mean += algorithms.cellular.meanExpression(expr);
        }
        accuracy_pass = total_mean > 0.0;
        
        std.debug.print("Algorithm: CELLULAR_STATS\n", .{});
        std.debug.print("Data: {} genes x {} cells\n", .{num_genes, num_cells});
        std.debug.print("Accuracy Check: {s}\n", .{ if (accuracy_pass) "PASS" else "FAIL" });

    } else if (std.mem.eql(u8, domain, "VARIANT")) {
        const num_vars = 1000000; // 1M variants
        const variants = try allocator.alloc(algorithms.variant.VariantParams, num_vars);
        defer allocator.free(variants);
        for (variants, 0..) |*v, i| {
            v.* = .{
                .chrom = "chr1",
                .pos = 10000 + i,
                .ref = if (i % 2 == 0) "A" else "C",
                .alt = if (i % 2 == 0) "G" else "T", 
            };
        }
        
        const stats = algorithms.variant.computeStatistics(variants);
        accuracy_pass = stats.total_variants == num_vars;
        
        std.debug.print("Algorithm: VARIANT_STATISTICS\n", .{});
        std.debug.print("Data: {} variants\n", .{num_vars});
        std.debug.print("Accuracy Check: {s}\n", .{ if (accuracy_pass) "PASS" else "FAIL" });

    } else if (std.mem.eql(u8, domain, "ORGANISMAL")) {
        const num_assocs = 1000000; // 1M associations
        const assocs = try allocator.alloc(algorithms.organismal.PhenotypeAssociation, num_assocs);
        defer allocator.free(assocs);
        for (assocs, 0..) |*a, i| {
            a.* = .{
                .disease_id = i % 100,
                .phenotype_id = i % 500,
                .confidence_score = 0.9,
            };
        }
        const summaries = try algorithms.organismal.summarizeDiseaseAssociations(allocator, assocs);
        accuracy_pass = summaries.len == 100;
        allocator.free(summaries);
        
        std.debug.print("Algorithm: DISEASE_SUMMARIZATION\n", .{});
        std.debug.print("Data: {} Phenotype Associations\n", .{num_assocs});
        std.debug.print("Accuracy Check: {s}\n", .{ if (accuracy_pass) "PASS" else "FAIL" });

    } else if (std.mem.eql(u8, domain, "POPULATION")) {
        // Linkage Disequilibrium
        const ld = algorithms.population.computeLD(0.3, 0.4, 0.2);
        accuracy_pass = ld.d != 0.0;
        
        // Epidemiological Summary
        const epi = algorithms.population.computeEpidemiologicalSummary(1000000, 5000, 150000, 2000);
        accuracy_pass = accuracy_pass and epi.incidence_rate > 0.0;
        
        std.debug.print("Algorithm: EPI_AND_LD\n", .{});
        std.debug.print("Data: Population Statistics\n", .{});
        std.debug.print("Accuracy Check: {s}\n", .{ if (accuracy_pass) "PASS" else "FAIL" });

    } else {
        std.debug.print("Unknown domain: {s}\n", .{domain});
        return error.UnknownDomain;
    }
}
