#!/bin/bash
echo "Running Cellular Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_cellular_algo >> benchmarks/benchmark_results.md 2>&1
