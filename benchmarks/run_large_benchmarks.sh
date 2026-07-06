#!/bin/bash
set -e

mkdir -p data

echo "Generating large VCF (approx 1GB)..."
# 10M lines of VCF
awk 'BEGIN { print "##fileformat=VCFv4.2"; print "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"; for(i=1;i<=30000000;i++) { print "chr1\t" i "\t.\tA\tT\t100\tPASS\t." } }' > data/large.vcf

echo "Running VCF Benchmark..."
/usr/bin/time -l ../zig-out/bin/benchmark_large VCF $(pwd)/data/large.vcf || true
rm data/large.vcf

echo "Running MMCIF Benchmark... (Using previously generated large.mmcif)"
# Wait, large.mmcif is 551MB. If the parser loads it ALL into memory, it might take 10GB of RAM. We will see.
/usr/bin/time -l ../zig-out/bin/benchmark_large MMCIF $(pwd)/data/large.mmcif || true
rm data/large.mmcif

echo "Downloading BAM test file..."
curl -sL "https://github.com/samtools/samtools/raw/develop/test/dat/test_input_1_a.bam" -o data/test.bam
echo "Generating larger BAM by duplicating blocks (this might be partially invalid but good enough for streaming parser test)..."
cat data/test.bam data/test.bam data/test.bam data/test.bam data/test.bam > data/large.bam
echo "Running BAM Benchmark..."
/usr/bin/time -l ../zig-out/bin/benchmark_large BAM $(pwd)/data/large.bam || true
rm data/large.bam data/test.bam

echo "Downloading CRAM test file..."
curl -sL "https://github.com/samtools/samtools/raw/develop/test/dat/ce.cram" -o data/test.cram
echo "Running CRAM Benchmark..."
/usr/bin/time -l ../zig-out/bin/benchmark_large CRAM $(pwd)/data/test.cram || true
rm data/test.cram

echo "Benchmarks complete."
