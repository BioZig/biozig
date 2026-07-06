# Testing BioZig

BioZig is deeply committed to extreme robustness, hardware-level stability, and completely native execution. As a result, the testing architecture is designed to be exhaustive and highly structured. 

There are currently **447 dedicated tests** validating edge cases, boundary limits, missing datasets, and memory leaks across the entire framework.

## 1. Testing Philosophy
BioZig adheres to a strict native-only testing approach. 
We do not rely on external test-runners or scripting wrappers that introduce fragile dependencies. 

Everything runs natively through the Zig compiler, ensuring that BioZig remains self-contained, reproducible, and verifiable on bare metal.

## 2. Directory Structure (`tests/`)
While Zig allows developers to write `test { ... }` blocks directly inside production source code (inline testing), BioZig intentionally separates its test suites into the `tests/` directory.

With 447 massive edge-case and sub-case tests, putting them directly into the source code would completely obscure the computational logic and mathematical algorithms.

The `tests/` directory mirrors the source architecture:
- `tests/core/`: Validates hardware SIMD, threading, and base numerics.
- `tests/ingestion/`: Validates MMap parsers, bit-sieves, and file readers.
- `tests/algorithms/`: Exhaustive testing for all computational engines (molecular, structural, systems, etc.).
- `tests/c_abi/`: Simulates external C/C++/Python/R calling patterns, enforcing strict memory bounds for the interoperability layer.
- *(And dedicated suites for all base domain representations).*

## 3. How to Run the Tests

Because BioZig is a highly modularized framework (using Zig 0.16 module semantics), running a single test file requires passing explicit module linkage flags (e.g., `--dep core -Mcore=core/core.zig`) so the compiler knows how to resolve imports.

We provide two seamless ways to test the entire framework natively:

### Option A: `run_tests.sh` (The Module Wrapper)
This bash script automates the complex module linkage. It loops through every subdirectory in `tests/`, discovers the `.zig` files, and feeds them to `zig test` with the precise `--dep` flags required for that specific domain.
```bash
# Run the exhaustive suite
./run_tests.sh
```
*Note: This script strictly acts as a compiler argument builder, not a test runner. The actual execution remains 100% native Zig.*

### Option B: `zig build test`
The standard Zig build system natively resolves dependencies as defined in `build.zig`.
```bash
# Run tests through the Zig build system
zig build test
```

## 4. Memory Safety & The C-ABI
BioZig utilizes `std.testing.allocator` across all tests. If a single byte of memory is leaked during an algorithm execution, the test will fail.

For the **C-ABI** tests (`tests/c_abi/`), we simulate cross-language interactions. Every test enforces a strict `biozig_context_create()` and `biozig_context_destroy()` wrap to verify that global arenas do not leak when passing pointers across the language boundary.
