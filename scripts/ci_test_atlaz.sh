#!/bin/bash
set -e

echo "======================================"
echo " ATLAZ CI/CD Transparency Execution   "
echo "======================================"

echo "[1] Generating Synthetic Null-Model FASTA..."
cat << EOF > synthetic_null.fasta
>seq1
ATGCGTACGTAGCTAGCTAG
>seq2
ATGCGTACGTAGCTAGCTAG
>seq3
ATGCGTACGTAGCTAGCTAG
>seq4
ATGCGTACGTAGCTAGCTAG
>seq5
ATGCGTACGTAGCTAGCTAG
EOF

echo "[2] Executing Integrated BioZig ATLAZ Engine..."
./zig-out/bin/biozig atlaz run --input synthetic_null.fasta --mode clonal > biozig_output.log
cat biozig_output.log

echo "[3] Executing Standalone ATLAZ Engine..."
./zig-out/bin/atlaz run --input synthetic_null.fasta --mode clonal > atlaz_output.log
cat atlaz_output.log

echo "[4] Mathematical Parity Check..."
# Strip the paths out if they differ, but diff should match output directly
if diff biozig_output.log atlaz_output.log > /dev/null; then
    echo "SUCCESS: Standalone binary and Integrated binary yield identical topological reduction."
else
    echo "FATAL: Output divergence detected between binaries!"
    exit 1
fi

echo "All CI execution protocols passed successfully."
