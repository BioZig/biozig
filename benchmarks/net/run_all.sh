#!/bin/bash
set -e

# Compile latest BioZig
echo "Compiling BioZig..."
zig build

# Define Output Log
LOG_FILE="benchmarks/net/results/multi_domain_benchmark.log"
echo "==========================================================" > $LOG_FILE
echo "       BIOZIG MULTI-DOMAIN ANALYTICS BENCHMARK SUITE      " >> $LOG_FILE
echo "==========================================================" >> $LOG_FILE
echo "Timestamp: $(date)" >> $LOG_FILE
echo "" >> $LOG_FILE

run_benchmark() {
    local domain=$1
    local query=$2
    local analyze=$3
    local title=$4
    
    echo "Running $title..."
    echo "--- $title ($domain) ---" >> $LOG_FILE
    echo "Command: biozig fetch --db $domain --query $query --analyze $analyze" >> $LOG_FILE
    
    # We use time -l on macOS to get peak memory footprints and append to log
    /usr/bin/time -l zig-out/bin/biozig fetch --db $domain --query "$query" --analyze "$analyze" 2>&1 | tee -a $LOG_FILE
    echo "" >> $LOG_FILE
}

# 1. NCBI Genomics
run_benchmark "ncbi" "NC_000001.11" "gc_content" "Genomics (NCBI) - GC Content & Skew"

# 2. Ensembl Genomics
run_benchmark "ensembl" "ENSG00000139618" "markov" "Genomics (Ensembl) - Markov Transition Matrix"

# 3. UniProt Proteomics
run_benchmark "uniprot" "P04637" "kmer" "Proteomics (UniProt) - Di-Peptide Frequencies"

# 4. PDB Structural Biology
run_benchmark "pdb" "1CRN" "pca" "Structural Biology (PDB) - CA Backbone Complexity"

# 5. ChEMBL Cheminformatics
run_benchmark "chembl" "CHEMBL25" "features" "Cheminformatics (ChEMBL) - SMILES Feature Extraction"

echo "All 5 API analytical validations completed successfully!"
echo "Check $LOG_FILE for full telemetry results."
