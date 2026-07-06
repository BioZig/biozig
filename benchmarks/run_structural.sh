#!/bin/bash
set -e

mkdir -p benchmarks/data

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

PDB_URL="https://files.rcsb.org/download/1CRN.pdb"
MMCIF_URL="https://files.rcsb.org/download/1CRN.cif"

echo "Downloading PDB..."
curl -sL $PDB_URL -o benchmarks/data/test.pdb
echo "Running PDB Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural PDB $(pwd)/benchmarks/data/test.pdb
rm benchmarks/data/test.pdb

echo "Downloading MMCIF..."
curl -sL $MMCIF_URL -o benchmarks/data/test.cif
echo "Running MMCIF Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural MMCIF $(pwd)/benchmarks/data/test.cif
rm benchmarks/data/test.cif

# Generate Dummy SDF
echo "Generating dummy SDF..."
echo "Dummy" > benchmarks/data/test.sdf
echo "  -OEChem-06232600002D" >> benchmarks/data/test.sdf
echo "" >> benchmarks/data/test.sdf
echo "  3  2  0     0  0  0  0  0  0999 V2000" >> benchmarks/data/test.sdf
echo "    0.0000    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0" >> benchmarks/data/test.sdf
echo "    0.0000    1.0000    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0" >> benchmarks/data/test.sdf
echo "    1.0000    0.0000    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0" >> benchmarks/data/test.sdf
echo "  1  2  1  0  0  0  0" >> benchmarks/data/test.sdf
echo "  1  3  1  0  0  0  0" >> benchmarks/data/test.sdf
echo "M  END" >> benchmarks/data/test.sdf
echo "$$$$" >> benchmarks/data/test.sdf
echo "Running SDF Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural SDF $(pwd)/benchmarks/data/test.sdf
rm benchmarks/data/test.sdf

# Generate Dummy PQR
echo "Generating dummy PQR..."
echo "REMARK   1 PQR dummy" > benchmarks/data/test.pqr
echo "ATOM      1  N   ALA     1       0.000   0.000   0.000  0.1000 1.5000" >> benchmarks/data/test.pqr
echo "ATOM      2  CA  ALA     1       1.000   0.000   0.000  0.1000 1.5000" >> benchmarks/data/test.pqr
echo "ATOM      3  C   ALA     1       2.000   0.000   0.000  0.1000 1.5000" >> benchmarks/data/test.pqr
echo "TER" >> benchmarks/data/test.pqr
echo "Running PQR Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural PQR $(pwd)/benchmarks/data/test.pqr
rm benchmarks/data/test.pqr

# Generate Dummy MOL2
echo "Generating dummy MOL2..."
echo "@<TRIPOS>MOLECULE" > benchmarks/data/test.mol2
echo "Dummy" >> benchmarks/data/test.mol2
echo "    3     2     0     0     0" >> benchmarks/data/test.mol2
echo "SMALL" >> benchmarks/data/test.mol2
echo "NO_CHARGES" >> benchmarks/data/test.mol2
echo "@<TRIPOS>ATOM" >> benchmarks/data/test.mol2
echo "      1 O           0.0000    0.0000    0.0000 O.3     1  HOH1        0.0000" >> benchmarks/data/test.mol2
echo "      2 H           0.0000    1.0000    0.0000 H       1  HOH1        0.0000" >> benchmarks/data/test.mol2
echo "      3 H           1.0000    0.0000    0.0000 H       1  HOH1        0.0000" >> benchmarks/data/test.mol2
echo "@<TRIPOS>BOND" >> benchmarks/data/test.mol2
echo "     1     1     2    1" >> benchmarks/data/test.mol2
echo "     2     1     3    1" >> benchmarks/data/test.mol2
echo "Running MOL2 Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_structural MOL2 $(pwd)/benchmarks/data/test.mol2
rm benchmarks/data/test.mol2

echo "Structural Layer Benchmark Complete."
