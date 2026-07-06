#!/bin/bash
set -e

mkdir -p benchmarks/data

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

echo -e "\n## Systems Algorithms Benchmarks\n" >> benchmarks/benchmark_results.md

echo "Downloading real biological data (STRING DB PPI Network)..."
curl -s "https://string-db.org/api/tsv/network?identifiers=TP53%0dEGFR%0dMYC%0dBRCA1%0dPTEN&species=9606" > benchmarks/data/network.tsv

echo "Running DEGREE Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo DEGREE $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running BFS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo BFS $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running DFS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo DFS $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running CONNECTED_COMPONENTS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo CONNECTED_COMPONENTS $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running CLOSENESS_CENTRALITY Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo CLOSENESS_CENTRALITY $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running EDMONDS_KARP Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo EDMONDS_KARP $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running TRIANGLE_COUNT Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo TRIANGLE_COUNT $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

echo "Running FRUCHTERMAN_REINGOLD Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_systems_algo FRUCHTERMAN_REINGOLD $(pwd)/benchmarks/data/network.tsv >> benchmarks/benchmark_results.md 2>&1

rm benchmarks/data/network.tsv

echo "Systems Algorithms Benchmark Complete."
