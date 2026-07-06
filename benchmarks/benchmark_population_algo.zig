const std = @import("std");
const algorithms = @import("algorithms");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip exe

    const algo_name = args.next() orelse return error.MissingAlgoName;

    var accuracy_pass = false;

    if (std.mem.eql(u8, algo_name, "BITPACKED_HAPLOTYPES")) {
        // Benchmark 10M variants (loci) x 1000 individuals (haploid)
        const num_loci = 10_000_000;
        const num_inds = 1000;

        var hap = try algorithms.population.BitpackedHaplotypes.init(allocator, num_inds, num_loci);
        defer hap.deinit();

        // Populate first 10k loci with some data
        for (0..10_000) |locus| {
            hap.set(locus, 0, 1);
            hap.set(locus, 63, 1);
            hap.set(locus, 128, 1);
        }

        // Compute frequencies for all loci
        var sum_freq: f64 = 0.0;
        for (0..num_loci) |locus| {
            sum_freq += hap.alleleFrequency(locus);
        }

        accuracy_pass = sum_freq > 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} variants x {} individuals\n", .{ num_loci, num_inds });
    } else if (std.mem.eql(u8, algo_name, "BITPACKED_GENOTYPES")) {
        // Benchmark 10M variants (loci) x 1000 individuals (diploid)
        const num_loci = 10_000_000;
        const num_inds = 1000;

        var geno = try algorithms.population.BitpackedGenotypes.init(allocator, num_inds, num_loci);
        defer geno.deinit();

        // Populate first 10k loci with some data
        for (0..10_000) |locus| {
            geno.set(locus, 0, 1);
            geno.set(locus, 31, 2);
            geno.set(locus, 128, 2);
        }

        // Compute frequencies for all loci
        var sum_freq: f64 = 0.0;
        for (0..num_loci) |locus| {
            sum_freq += geno.alleleFrequencyAlt(locus);
        }

        accuracy_pass = sum_freq > 0.0;
        std.debug.print("Algorithm: {s}\n", .{algo_name});
        std.debug.print("Data: {} variants x {} individuals (diploid)\n", .{ num_loci, num_inds });
    } else {
        std.debug.print("Unknown algo: {s}\n", .{algo_name});
        return;
    }

    std.debug.print("Accuracy Check: {s}\n", .{if (accuracy_pass) "PASS" else "FAIL"});
}
