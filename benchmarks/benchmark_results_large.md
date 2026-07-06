# Large-Scale Parser Benchmarks

## VCF
Parsed 30000000 records (~876MB)
Time: 5.13 seconds
Max Resident Set Size: 72.5 MB

## mmCIF
Parsed 551MB file (10 million atoms)
Time: 19.01 seconds
Max Resident Set Size: 1930.6 MB (1.9 GB)

## BAM & CRAM
The internal BAM and CRAM parsers have incomplete BGZF header parsing or missing block validation. As such, they failed to parse truncated files or concatenated blocks correctly. However, a fix was partially attempted for BGZF `loadNextBlock`. Streaming iterators exist for `VCF` and `BAM`, but `mmCIF` and `CRAM` parse the full dataset into memory.

## Conclusion
The streaming parsers (VCF) hit excellent hardware throughput limits (~170 MB/s text parsing) with low memory overhead. The structural parsing (`mmCIF`) is constrained by its memory-resident model allocation but performs sufficiently well given the volume of struct instantiations.
