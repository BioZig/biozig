#!/bin/bash
set -e

mkdir -p benchmarks/data

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

echo -e "\n## Structural Algorithms Benchmarks\n" >> benchmarks/benchmark_results.md

echo "Downloading real biological data (PDB: 1UBQ, Ubiquitin)..."
curl -s "https://files.rcsb.org/download/1UBQ.pdb" > benchmarks/data/1ubq.pdb

echo "Running DISTANCE_MATRIX Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo DISTANCE_MATRIX $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running CONTACT_MAP Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo CONTACT_MAP $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running RMSD Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo RMSD $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running CENTROID Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo CENTROID $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running KABSCH_ROTATION Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo KABSCH_ROTATION $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running DISTANCE_MATRIX_BLOCK Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo DISTANCE_MATRIX_BLOCK $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running POCKET_STATISTICS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo POCKET_STATISTICS $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running POCKET_COMPARISON Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo POCKET_COMPARISON $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running SURFACE_METRICS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo SURFACE_METRICS $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running SHAPE_DESCRIPTORS Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo SHAPE_DESCRIPTORS $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running VERLET_MD Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo VERLET_MD $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running SIMULATED_ANNEALING Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo SIMULATED_ANNEALING $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running ANM_HESSIAN Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo ANM_HESSIAN $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running THREADING_DP Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo THREADING_DP $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

echo "Running ROTAMER_PACKING Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural_algo ROTAMER_PACKING $(pwd)/benchmarks/data/1ubq.pdb >> benchmarks/benchmark_results.md 2>&1

rm benchmarks/data/1ubq.pdb

echo "Structural Algorithms Benchmark Complete."
