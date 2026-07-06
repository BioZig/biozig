#!/bin/bash
set -e

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

echo -e "\n## Cellular & Organismal Algorithms Benchmarks\n" >> benchmarks/benchmark_results.md

echo "Running CELLULAR Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_final_algo CELLULAR >> benchmarks/benchmark_results.md 2>&1

echo "Running VARIANT Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_final_algo VARIANT >> benchmarks/benchmark_results.md 2>&1

echo "Running ORGANISMAL Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_final_algo ORGANISMAL >> benchmarks/benchmark_results.md 2>&1

echo "Running POPULATION Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_final_algo POPULATION >> benchmarks/benchmark_results.md 2>&1

echo "Final Algorithms Benchmark Complete."
