#!/bin/bash

# EON Pipeline Script (Phase 1-4)
set -e

if [ "$1" == "" ]; then
    echo "Usage: ./eon.sh <rigidity_out.txt>"
    exit 1
fi

RIGIDITY_FILE=$1
FUSE_OUT="output.csv"
HUBS_OUT="hubs.csv"
RISK_OUT="eon_report.json"

echo "[EON] Starting EON Pipeline..."
cp $RIGIDITY_FILE rigidity_out.txt

# Phase 1: Topological Fusion
echo "[EON] Phase 1: Running Topological Fusion (fuse_network)..."
./eon/fuse_network_zig

# Phase 2: Hub Identification
echo "[EON] Phase 2: Identifying BAIL Hubs..."
./eon/hubs_network_zig

# Phase 3: Risk Scoring
echo "[EON] Phase 3: Generating Risk Taxonomies..."
./eon/risk_network_zig

# Phase 4: Reporting
echo "[EON] Pipeline Complete. Final report written to ${RISK_OUT}."
