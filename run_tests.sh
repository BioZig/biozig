#!/bin/bash
set -e

# Define common modules for ingestion tests
MODULES=(
    "--dep" "core" "--dep" "molecular" "--dep" "cellular" "--dep" "structural" "--dep" "systems" "--dep" "visualization" "--dep" "ingestion"
    "-Mroot=$file"
    "-Mcore=core/core.zig"
    "--dep" "core" "-Mmolecular=molecular/molecular.zig"
    "--dep" "core" "--dep" "molecular" "-Mcellular=cellular/cellular.zig"
    "--dep" "core" "--dep" "molecular" "-Mstructural=structural/structural.zig"
    "--dep" "core" "-Msystems=systems/systems.zig"
    "--dep" "core" "--dep" "structural" "-Mvisualization=visualization/visualization.zig"
    "--dep" "core" "--dep" "molecular" "--dep" "cellular" "--dep" "structural" "--dep" "systems" "--dep" "visualization" "-Mingestion=ingestion/ingestion.zig"
)

echo "=== Testing CORE ==="
for file in tests/core/*.zig; do
    echo "Running $file"
    zig test --dep core -Mroot="$file" -Mcore=core/core.zig
done

echo "=== Testing INGESTION ==="
for file in tests/ingestion/*.zig; do
    echo "Running $file"
    zig test \
        "--dep" "core" "--dep" "molecular" "--dep" "cellular" "--dep" "structural" "--dep" "systems" "--dep" "visualization" "--dep" "ingestion" \
        "-Mroot=$file" \
        "-Mcore=core/core.zig" \
        "--dep" "core" "-Mmolecular=molecular/molecular.zig" \
        "--dep" "core" "--dep" "molecular" "-Mcellular=cellular/cellular.zig" \
        "--dep" "core" "--dep" "molecular" "-Mstructural=structural/structural.zig" \
        "--dep" "core" "-Msystems=systems/systems.zig" \
        "--dep" "core" "--dep" "structural" "-Mvisualization=visualization/visualization.zig" \
        "--dep" "core" "--dep" "molecular" "--dep" "cellular" "--dep" "structural" "--dep" "systems" "--dep" "visualization" "-Mingestion=ingestion/ingestion.zig"
done

echo "=== Testing MOLECULAR ==="
for file in tests/molecular/*.zig; do
    echo "Running $file"
    zig test \
        "--dep" "core" "--dep" "molecular" \
        "-Mroot=$file" \
        "-Mcore=core/core.zig" \
        "--dep" "core" "-Mmolecular=molecular/molecular.zig"
done

echo "=== Testing STRUCTURAL ==="
for file in tests/structural/*.zig; do
    echo "Running $file"
    zig test \
        "--dep" "core" "--dep" "structural" \
        "-Mroot=$file" \
        "-Mcore=core/core.zig" \
        "--dep" "core" "-Mstructural=structural/structural.zig"
done

echo "=== Testing CELLULAR ==="
for file in tests/cellular/*.zig; do
    echo "Running $file"
    zig test \
        "--dep" "cellular" \
        "-Mroot=$file" \
        "-Mcellular=cellular/cellular.zig"
done

echo "=== Testing SYSTEMS ==="
for file in tests/systems/*.zig; do
    echo "Running $file"
    zig test \
        "--dep" "systems" \
        "-Mroot=$file" \
        "-Msystems=systems/systems.zig"
done

echo "=== Testing POPULATION ==="
for file in tests/population/*.zig; do
    echo "Running $file"
    zig test \
        "--dep" "core" "--dep" "population" \
        "-Mroot=$file" \
        "-Mcore=core/core.zig" \
        "--dep" "core" "-Mpopulation=population/population.zig"
done

echo "=== Testing ALGORITHMS POPULATION ==="
for file in tests/algorithms/test_population.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "population" "--dep" "algorithms" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Mpopulation=population/population.zig" \
            "--dep" "core" "--dep" "population" "-Malgorithms=algorithms/algorithms.zig"
    fi
done

echo "=== Testing EVOLUTIONARY ==="
for file in tests/evolutionary/*.zig; do
    echo "Running $file"
    zig test \
        --dep visualization --dep core --dep evolutionary \
        -Mroot="$file" \
        -Mcore=core/core.zig \
        --dep core -Mvisualization=visualization/visualization.zig \
        --dep visualization -Mevolutionary=algorithms/evolutionary/evolutionary.zig
done

echo "=== Testing ALGORITHMS STRUCTURAL ==="
for file in tests/algorithms/structural/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "structural_alg" \
            "-Mroot=$file" \
            "-Mstructural_alg=algorithms/structural/structural.zig"
    fi
done

echo "=== Testing ALGORITHMS VARIANT ==="
for file in tests/algorithms/variant/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "variant_alg" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Mvariant_alg=algorithms/variant/variant.zig"
    fi
done

echo "=== Testing ALGORITHMS ORGANISMAL ==="
for file in tests/algorithms/organismal/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "organismal_alg" \
            "-Mroot=$file" \
            "-Morganismal_alg=algorithms/organismal/organismal.zig"
    fi
done
echo "=== Testing ALGORITHMS MOLECULAR ==="
for file in tests/algorithms/molecular/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "molecular" "--dep" "analytics" "--dep" "algorithms" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Mmolecular=molecular/molecular.zig" \
            "--dep" "core" "-Manalytics=analytics/analytics.zig" \
            "--dep" "core" "--dep" "molecular" "--dep" "analytics" "-Malgorithms=algorithms/algorithms.zig"
    fi
done

echo "=== Testing ALGORITHMS SYSTEMS ==="
for file in tests/algorithms/systems/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "systems" "--dep" "algorithms" "--dep" "algorithms_systems" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Msystems=systems/systems.zig" \
            "--dep" "core" "--dep" "systems" "-Malgorithms=algorithms/algorithms.zig" \
            "-Malgorithms_systems=algorithms/systems/systems.zig"
    fi
done

echo "=== Testing ALGORITHMS CELLULAR ==="
for file in tests/algorithms/cellular/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "cellular" "--dep" "algorithms" "--dep" "algorithms_cellular" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Mcellular=cellular/cellular.zig" \
            "--dep" "core" "--dep" "cellular" "-Malgorithms=algorithms/algorithms.zig" \
            "--dep" "cellular" "--dep" "algorithms" "-Malgorithms_cellular=algorithms/cellular/cellular.zig"
    fi
done

echo "=== Testing ANALYTICS ==="
for file in tests/analytics/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "analytics" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Manalytics=analytics/analytics.zig"
    fi
done

echo "=== Testing C-ABI ==="
for file in tests/c_abi/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "molecular" "--dep" "algorithms" "--dep" "ingestion" "--dep" "analytics" \
            "--dep" "structural" "--dep" "cellular" "--dep" "systems" "--dep" "visualization" "--dep" "population" "--dep" "net" \
            "--dep" "c_api" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Mmolecular=molecular/molecular.zig" \
            "--dep" "core" "--dep" "molecular" "-Mcellular=cellular/cellular.zig" \
            "--dep" "core" "--dep" "molecular" "-Mstructural=structural/structural.zig" \
            "--dep" "core" "--dep" "molecular" "--dep" "cellular" "-Msystems=systems/systems.zig" \
            "--dep" "core" "--dep" "structural" "-Mvisualization=visualization/visualization.zig" \
            "--dep" "core" "--dep" "molecular" "--dep" "cellular" "--dep" "structural" "--dep" "systems" "--dep" "visualization" "-Mingestion=ingestion/ingestion.zig" \
            "--dep" "core" "-Mpopulation=population/population.zig" \
            "--dep" "core" "--dep" "molecular" "--dep" "cellular" "--dep" "visualization" "--dep" "analytics" "-Malgorithms=algorithms/algorithms.zig" \
            "--dep" "core" "-Manalytics=analytics/analytics.zig" \
            "--dep" "core" "-Mnet=net/net.zig" \
            "--dep" "core" "--dep" "molecular" "--dep" "algorithms" "--dep" "ingestion" "--dep" "analytics" "--dep" "structural" "--dep" "cellular" "--dep" "systems" "--dep" "visualization" "--dep" "population" "--dep" "net" "-Mc_api=interoperability/c_api.zig"
    fi
done

echo "=== Testing NET ==="
for file in tests/net/*.zig; do
    if [ -f "$file" ]; then
        echo "Running $file"
        zig test \
            "--dep" "core" "--dep" "net" \
            "-Mroot=$file" \
            "-Mcore=core/core.zig" \
            "--dep" "core" "-Mnet=net/net.zig"
    fi
done
