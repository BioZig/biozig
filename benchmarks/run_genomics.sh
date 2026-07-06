#!/bin/bash
set -e

mkdir -p benchmarks/data

echo "Compiling benchmark harness..."
zig build -Doptimize=ReleaseFast

FASTA_URL="https://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.MT.fa.gz"
GFF3_URL="https://ftp.ensembl.org/pub/release-110/gff3/homo_sapiens/Homo_sapiens.GRCh38.110.chromosome.MT.gff3.gz"

echo "Downloading FASTA..."
curl -sL $FASTA_URL -o benchmarks/data/test.fa.gz
gunzip -f benchmarks/data/test.fa.gz
echo "Running FASTA Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics FASTA $(pwd)/benchmarks/data/test.fa
rm benchmarks/data/test.fa

echo "Downloading GFF3..."
curl -sL $GFF3_URL -o benchmarks/data/test.gff3.gz
gunzip -f benchmarks/data/test.gff3.gz
echo "Running GFF3 Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics GFF3 $(pwd)/benchmarks/data/test.gff3
rm benchmarks/data/test.gff3

# Generate Dummy FASTQ (approx 5MB)
echo "Generating dummy FASTQ..."
awk 'BEGIN { for(i=1;i<=10000;i++) { print "@SEQ_ID_"i; print "GATTTGGGGTTCAAAGCAGTATCGATCAAATAGTAAATCCATTTGTTCAACTCACAGTTT"; print "+"; print "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII" } }' > benchmarks/data/test.fastq
echo "Running FASTQ Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics FASTQ $(pwd)/benchmarks/data/test.fastq
rm benchmarks/data/test.fastq

# Generate Dummy BED
echo "Generating dummy BED..."
awk 'BEGIN { for(i=1;i<=10000;i++) { print "chr1\t" (i*100) "\t" ((i*100)+50) "\tfeature_" i "\t" (i%1000) "\t+" } }' > benchmarks/data/test.bed
echo "Running BED Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics BED $(pwd)/benchmarks/data/test.bed
rm benchmarks/data/test.bed

# Generate Dummy VCF
echo "Generating dummy VCF..."
echo "##fileformat=VCFv4.2" > benchmarks/data/test.vcf
echo "#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO" >> benchmarks/data/test.vcf
awk 'BEGIN { for(i=1;i<=10000;i++) { print "chr1\t" i "\t.\tA\tT\t100\tPASS\t." } }' >> benchmarks/data/test.vcf
echo "Running VCF Benchmark..."
/usr/bin/time -l ./zig-out/bin/benchmark_genomics VCF $(pwd)/benchmarks/data/test.vcf
rm benchmarks/data/test.vcf

echo "Genomics Layer Benchmark Complete."
