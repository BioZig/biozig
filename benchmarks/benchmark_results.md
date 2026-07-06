
## High-Scale Genomics Algorithms Benchmarks

Initializing Genomics Data: 100000000 bases...
Algorithm: KMER_COUNT
Data Size: 100000000 bases
Accuracy Check: PASS
        4.73 real         4.01 user         0.03 sys
           127156224  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                7933  page reclaims
                  10  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                 118  involuntary context switches
         25977299608  instructions retired
         12710139154  cycles elapsed
           126649408  peak memory footprint
Initializing Genomics Data: 100000000 bases...
Algorithm: SHANNON_ENTROPY
Data Size: 100000000 bases
Accuracy Check: PASS
        0.92 real         0.90 user         0.01 sys
           126615552  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                7893  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                  45  involuntary context switches
          5353287045  instructions retired
          2932672785  cycles elapsed
           126108736  peak memory footprint
Initializing Genomics Data: 100000000 bases...
Algorithm: KMER_ROLLING_HASH
Data Size: 100000000 bases
Accuracy Check: PASS
        1.09 real         0.85 user         0.10 sys
           661831680  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
               57093  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                 553  involuntary context switches
          5941016936  instructions retired
          3023487561  cycles elapsed
           926534272  peak memory footprint
Initializing Genomics Data: 10000000 bases...
Algorithm: MINIMIZERS
Data Size: 10000000 bases
Accuracy Check: PASS
        1.15 real         1.13 user         0.01 sys
            64520192  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                7409  page reclaims
                  10  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                  77  involuntary context switches
         18205024929  instructions retired
          3628794198  cycles elapsed
            63996928  peak memory footprint
Initializing Genomics Data: 1000000 bases...
Algorithm: FM_INDEX
Data Size: 1000000 bases
Accuracy Check: PASS
        0.27 real         0.27 user         0.00 sys
            52019200  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                4318  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   4  involuntary context switches
          1938612891  instructions retired
           870933709  cycles elapsed
            51463104  peak memory footprint
Initializing Genomics Data: 10000000 bases...
Algorithm: SUFFIX_ARRAY
Data Size: 10000000 bases
Accuracy Check: PASS
        5.73 real         5.68 user         0.04 sys
           254148608  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
               15677  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                 150  involuntary context switches
         22531006734  instructions retired
         18063213679  cycles elapsed
           253691200  peak memory footprint

## Systems Algorithms Benchmarks

Algorithm: DEGREE
Data: 100000 nodes, 500000 edges
Accuracy Check: PASS
        0.52 real         0.00 user         0.01 sys
            23953408  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3735  page reclaims
                   1  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   1  voluntary context switches
                   7  involuntary context switches
            68323981  instructions retired
            33378278  cycles elapsed
            23495552  peak memory footprint
Algorithm: BFS
Data: 100000 nodes, 500000 edges
Accuracy Check: PASS
        0.01 real         0.00 user         0.00 sys
            23953408  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3696  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   4  involuntary context switches
            67069430  instructions retired
            28597014  cycles elapsed
            23495552  peak memory footprint
Algorithm: DFS
Data: 100000 nodes, 500000 edges
Accuracy Check: PASS
        0.01 real         0.00 user         0.00 sys
            23953408  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3696  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   4  involuntary context switches
            66083887  instructions retired
            25011561  cycles elapsed
            23479104  peak memory footprint
Algorithm: CONNECTED_COMPONENTS
Data: 100000 nodes, 500000 edges
Accuracy Check: PASS
        0.01 real         0.00 user         0.00 sys
            23953408  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3736  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   4  involuntary context switches
            73434177  instructions retired
            32639990  cycles elapsed
            23495552  peak memory footprint
Algorithm: CLOSENESS_CENTRALITY
Data: 100000 nodes, 500000 edges
Accuracy Check: PASS
        7.89 real         3.23 user         4.64 sys
            23969792  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
             5003735  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                1008  involuntary context switches
         43313461374  instructions retired
         24811298037  cycles elapsed
            23511936  peak memory footprint

## Structural Algorithms Benchmarks

Algorithm: DISTANCE_MATRIX
Data: 5000 atoms
Accuracy Check: PASS
        0.68 real         0.07 user         0.02 sys
           225640448  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
               13943  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   5  involuntary context switches
           539022043  instructions retired
           217235608  cycles elapsed
           225297664  peak memory footprint
Algorithm: CONTACT_MAP
Data: 5000 atoms
Accuracy Check: PASS
        0.04 real         0.02 user         0.00 sys
            50626560  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3261  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                  37  involuntary context switches
           459775697  instructions retired
           101768880  cycles elapsed
            50201536  peak memory footprint
Algorithm: RMSD
Data: 1000000 atoms
Accuracy Check: PASS
        0.01 real         0.00 user         0.00 sys
            49594368  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3192  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                  43  involuntary context switches
            86134524  instructions retired
            33726388  cycles elapsed
            49087424  peak memory footprint
Algorithm: CENTROID
Data: 1000000 atoms
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
            25591808  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                1727  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                  28  involuntary context switches
            52784920  instructions retired
            20629659  cycles elapsed
            25068416  peak memory footprint
Algorithm: CROSS_COVARIANCE
Data: 1000000 atoms
Accuracy Check: PASS
        0.01 real         0.00 user         0.00 sys
            49594368  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                3192  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   7  involuntary context switches
            77956162  instructions retired
            29403851  cycles elapsed
            49087424  peak memory footprint
Algorithm: DISTANCE_MATRIX_BLOCK
Data: 1000x1000 atoms
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
            33505280  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                2216  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   6  involuntary context switches
            67873299  instructions retired
            19526185  cycles elapsed
            33063808  peak memory footprint
Algorithm: POCKET_STATISTICS
Data: 1000000 atoms
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
            25591808  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                1727  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   4  involuntary context switches
            61597255  instructions retired
            20590406  cycles elapsed
            25068416  peak memory footprint
Algorithm: POCKET_COMPARISON
Data: 1000000 atoms
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
            25591808  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                1727  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   3  involuntary context switches
            74671939  instructions retired
            24719526  cycles elapsed
            25068416  peak memory footprint
Algorithm: SURFACE_METRICS
Data: 1000000 atoms
Accuracy Check: PASS
        0.02 real         0.00 user         0.00 sys
            25591808  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                1727  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   4  involuntary context switches
            60778236  instructions retired
            28494042  cycles elapsed
            25068416  peak memory footprint
Algorithm: SHAPE_DESCRIPTORS
Data: 1000000 atoms
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
            25591808  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                1727  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   3  involuntary context switches
            66602181  instructions retired
            22530354  cycles elapsed
            25068416  peak memory footprint
=== Cellular Algorithms Benchmark ===
Benchmarking Sparse CSR Matrix creation for 1000000 cells, 1000 genes, 10000000 nnz...
SparseMatrix initialization and filling done.
SparseMatrixOps colSums done.
SparseMatrixOps rowSums done.
SparseMatrixOps multiplyVector done.
PCA topComponent (5 iters) done.
IncrementalPCA onlineTopComponent done.
DifferentialExpression simpleDiffExp done.
Benchmarking Spatial Indexing...
SpatialIndex init for 100000 points done.
SpatialIndex findNeighbors query done (Found 98 neighbors).
        0.75 real         0.12 user         0.02 sys
           149651456  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                9299  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   7  involuntary context switches
          1621393979  instructions retired
           336763387  cycles elapsed
           149177472  peak memory footprint

## Population Algorithms Benchmarks

Algorithm: BITPACKED_HAPLOTYPES
Data: 10000000 variants x 1000 individuals
Accuracy Check: PASS
        1.14 real         0.07 user         0.25 sys
          1280933888  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
              155995  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                2458  involuntary context switches
          1673209874  instructions retired
           885477583  cycles elapsed
          1281658048  peak memory footprint
Algorithm: BITPACKED_GENOTYPES
Data: 10000000 variants x 1000 individuals (diploid)
Accuracy Check: PASS
        1.02 real         0.36 user         0.35 sys
          1593671680  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
              259611  page reclaims
                  10  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                2700  involuntary context switches
          7511286788  instructions retired
          2086676402  cycles elapsed
          2562283072  peak memory footprint

## Evolutionary Layer Benchmarks


--- Algorithm Benchmarks ---
TreeStats | Leaves: 3, Internal: 2
RF Distance (Self) | Dist: 0
Fitch Parsimony | Score: 2

Format: NEWICK
File Size: 27 bytes
Accuracy Check: PASS
        0.54 real         0.00 user         0.00 sys
             1703936  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                 269  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   6  involuntary context switches
            16563876  instructions retired
            10572758  cycles elapsed
             1049344  peak memory footprint

--- Algorithm Benchmarks ---
TreeStats | Leaves: 3, Internal: 2
RF Distance (Self) | Dist: 0
Fitch Parsimony | Score: 2

Format: NEXUS
File Size: 124 bytes
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
             1703936  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                 269  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   5  involuntary context switches
            15516132  instructions retired
             6751603  cycles elapsed
             1049344  peak memory footprint

--- Algorithm Benchmarks ---
TreeStats | Leaves: 3, Internal: 2
RF Distance (Self) | Dist: 0
Fitch Parsimony | Score: 2

Format: PHYLOXML
File Size: 676 bytes
Accuracy Check: PASS
        0.00 real         0.00 user         0.00 sys
             1703936  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                 269  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   3  involuntary context switches
            15394118  instructions retired
             6406215  cycles elapsed
             1049344  peak memory footprint

## Evolutionary Layer Benchmarks

Running evolutionary benchmarks...
UPGMA (1000x): done
NJ (1000x): done
JC69 (10000x): done
Done.
        0.65 real         0.00 user         0.00 sys
             3014656  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                 349  page reclaims
                   1  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   2  voluntary context switches
                   3  involuntary context switches
            20685640  instructions retired
             8673771  cycles elapsed
             2458368  peak memory footprint
Running evolutionary benchmarks...
UPGMA (1000x): done
NJ (1000x): done
JC69 (10000x): done
Done.
        0.00 real         0.00 user         0.00 sys
             3014656  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                 349  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   3  involuntary context switches
            18792442  instructions retired
             6721986  cycles elapsed
             2474816  peak memory footprint
Running evolutionary benchmarks...
UPGMA (1000x): done
NJ (1000x): done
JC69 (10000x): done
Done.
        0.00 real         0.00 user         0.00 sys
             3014656  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
                 349  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
                   0  voluntary context switches
                   6  involuntary context switches
            18879330  instructions retired
             6797044  cycles elapsed
             2474816  peak memory footprint
