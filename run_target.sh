#!/bin/bash
set -e

FASTA="data/oxa23_500.fasta"
RIGIDITY="data/oxa23_500_rigidity.out"
MI="data/oxa23_500_mi.csv"
HUBS="data/oxa23_500_hubs.csv"
JSON="data/oxa23_500_eon.json"

echo "Running TiMSA..."
./zig-out/bin/biozig timsa rigidity -i $FASTA > $RIGIDITY 2>&1

cp $RIGIDITY rigidity_out.txt

echo "Running fuse..."
./eon/fuse_network_zig rigidity_out.txt $MI

echo "Running topology (hubs)..."
./eon/hubs_network_zig $MI $HUBS

echo "Running risk..."
./eon/risk_network_zig rigidity_out.txt $HUBS $JSON

echo "Done!"
