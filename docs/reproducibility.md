# Reproducibility

BioZig enforces strict, bit-exact reproducibility.

## The ReproducibilityRecord

The `core.reproducibility.ReproducibilityRecord` struct is the foundational component for auditing computational execution. It tracks:

- **Compiler Version:** The exact Zig compiler version used (`@import("builtin").zig_version_string`).
- **Target Architecture:** CPU and OS targets.
- **Timestamp:** Execution time.
- **Random Seed:** A deterministic 64-bit integer seed for all PRNG instances.
- **Inputs & Outputs:** File paths and corresponding SHA-256 hashes for all input datasets and generated results.
- **Metadata:** Key-value pairs detailing algorithmic parameters and pipeline names.

## Hashing

Input validation uses `core.hashing.Sha256`. 
Internal data structure partitioning uses deterministic `core.hashing.XxHash64` with fixed seeds to prevent iteration order variance across runs.

## Serialization

BioZig eschews arbitrary text formats for intermediate states. It uses `core.serialization` for recursive, deterministic binary serialization.

- Memory layouts (e.g., endianness) are strictly defined.
- Slices serialize their length followed by continuous element blocks.
- Maps serialize key-value pairs in a strictly deterministic order.

## Usage Example

```zig
var record = try ReproducibilityRecord.init(alloc, 0x12345678);
defer record.deinit();

try record.trackInputData("input.fasta", input_bytes);
try record.addMetadata("normalization", "CPM");

// Pass `record` to the reporting layer to append it to publication outputs
```
