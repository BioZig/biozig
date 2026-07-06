#!/bin/bash
set -e

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

echo -e "\n## High-Scale Genomics Algorithms Benchmarks\n" >> benchmarks/benchmark_results.md

echo "Running KMER_COUNT Benchmark (100 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo KMER_COUNT 100000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running SHANNON_ENTROPY Benchmark (100 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo SHANNON_ENTROPY 100000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running KMER_ROLLING_HASH Benchmark (100 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo KMER_ROLLING_HASH 100000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running MINIMIZERS Benchmark (10 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo MINIMIZERS 10000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running FM_INDEX Benchmark (1 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo FM_INDEX 1000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running SUFFIX_ARRAY Benchmark (10 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo SUFFIX_ARRAY 10000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running DE_BRUIJN_GRAPH Benchmark (1 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo DE_BRUIJN_GRAPH 1000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running HMM_VITERBI Benchmark (1 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo HMM_VITERBI 1000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running MSA_PROGRESSIVE Benchmark (1 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo MSA_PROGRESSIVE 1000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running GIBBS_SAMPLING Benchmark (1 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo GIBBS_SAMPLING 1000000 >> benchmarks/benchmark_results.md 2>&1

echo "Running SUFFIX_TREE Benchmark (1 Million bases)..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics_algo SUFFIX_TREE 1000000 >> benchmarks/benchmark_results.md 2>&1

echo "Genomics Algorithms Benchmark Complete."
