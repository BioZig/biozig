#!/bin/bash
echo "=========================================="
echo "    BioZig Population Algorithms Benchmark"
echo "=========================================="

echo "Benchmarks already built."

echo "Running Benchmarks:"
echo "-------------------"

echo -e "\n## Population Algorithms Benchmarks\n" >> benchmarks/benchmark_results.md

echo "Running BITPACKED_HAPLOTYPES Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_population_algo BITPACKED_HAPLOTYPES >> benchmarks/benchmark_results.md 2>&1

echo "Running BITPACKED_GENOTYPES Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_population_algo BITPACKED_GENOTYPES >> benchmarks/benchmark_results.md 2>&1

echo "Population Algorithms Benchmark Complete."
