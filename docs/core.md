# Core Layer

## Purpose
The Core layer provides the foundational system interactions for BioZig. It isolates all hardware, memory, parsing, and execution primitives from the biological domains, ensuring biological implementations remain focused on logic rather than system orchestration.

## Directory Layout
- `allocators/`: Custom tracking allocators (`TrackingAllocator`, `ArenaAllocator`).
- `bitpacking/`: Compact binary representations (`PackedIntArray`, `BitReader`, `BitWriter`).
- `compression/`: Standard compression algorithms (`raw`, `zlib`, `gzip`).
- `containers/`: Generic unmanaged data structures (`FixedArray`, `RingBuffer`, `Queue`, `DynamicArray`).
- `hashing/`: Cryptographic (`Sha256`) and deterministic non-cryptographic (`XxHash64`) hashing.
- `io/`: High-performance buffered I/O (`BufferedReader`, `BufferedWriter`).
- `memory/`: Memory alignment and explicit endianness views (`MemoryView`).
- `numerics/`: Low-level float stabilization (`kahanSum`, `variance`, `quantile`).
- `reproducibility/`: Provenance tracking (`ReproducibilityRecord`).
- `scheduling/`: Deterministic DAG task execution and Structural Recomputation Framework (`Scheduler`, `SRFScheduler`).
- `serialization/`: Recursive binary deterministic serialization (`serialize`, `deserialize`).
- `simd/`: Vectorized counting and summation (`sumFloat`, `countChar`, `countMismatches`).
- `threading/`: Concurrency primitives (`SpinMutex`, `ThreadPool`).

## Public Types
- `TrackingAllocator`
- `ArenaAllocator`
- `PackedIntArray(bits)`
- `ReproducibilityRecord`
- `Scheduler`
- `SRFScheduler`
- `ThreadPool`
- `MemoryView`

## Public APIs
- `bitpacking.BitWriter.writeBits()`
- `compression.compress()`
- `numerics.kahanSum()`
- `serialization.serialize()`
- `simd.countMismatches()`
- `threading.SpinMutex.lock()`

## Serialization Format
Core serialization is strictly binary. Booleans are `1` byte (`1` or `0`). Integers are written in little-endian order. Slices prepend a 64-bit length. Optionals prepend a `1` byte flag.

## Memory Model
Core promotes the use of unmanaged structures alongside domain-specific arenas. Methods rarely allocate internally unless an `allocator: std.mem.Allocator` is explicitly passed.

## Determinism Guarantees
- Thread pools execute tasks in non-deterministic completion order unless governed by the `Scheduler`, which enforces a strict topological DAG execution order.
- **Memory Boundaries:** The `SRFScheduler` enforces strict $O(L)$ limits via `budget.zig`. Rather than permitting OS-level Out-of-Memory (OOM) crashes, it triggers a deterministic panic (`SRF Memory Budget Exceeded`) when operations breach the defined arena budget.
- Floating-point sums use Kahan summation to prevent associative precision loss.
- Serialization is 100% deterministic (no padding bytes or memory pointers are serialized).

## Example Usage
```zig
const std = @import("std");
const core = @import("biozig").core;

var buffer: [1024]u8 = undefined;
var fbs = std.io.fixedBufferStream(&buffer);
const writer = fbs.writer();

// Deterministic binary serialization
try core.serialization.serialize(writer, @as(u32, 42));
```

## Limitations
- Thread pool currently relies on OS-level thread spawning; it does not implement user-space green threads or coroutines.
- SIMD routines are hardcoded to specific vector lengths (e.g., 16 for floats, 32 for bytes); auto-vectorization is preferred for variable lengths.
