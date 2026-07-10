# Getting Started

BioZig provides a primary interface via a compiled command-line executable.

## Requirements
- Zig `0.16.0` or later

## Installation

Clone the repository and build the project using the native build system:

```bash
git clone https://github.com/biozig/biozig.git
cd biozig
zig build
```

The executable is compiled to `zig-out/bin/biozig`.

## CLI Usage

The executable is organized into functional domains. To execute a command, provide the domain and the subcommand.

```bash
./zig-out/bin/biozig <domain> <subcommand> [options]
```

### Basic Flags
- `-i, --input <path>`: Specifies the input file.
- `-o, --output <path>`: Specifies the output destination (default is `stdout`).
- `-h, --help`: Displays help for a specific domain or subcommand.

### Examples

**Genomic Transition/Transversion Ratio:**
```bash
./zig-out/bin/biozig fetch --db ncbi --query NC_000001.11 --analyze titv
```

**Structural Contact Map Generation:**
```bash
./zig-out/bin/biozig fetch --db pdb --query 6vxx --analyze contact_map
```

**Systems Biology (PPI Network Traversal):**
```bash
./zig-out/bin/biozig systems dijkstra -i string_db_9606.txt
```
## Library Integration

BioZig can also be used as a static library in Zig projects by importing it in your `build.zig` and allocating domain objects directly. All modules require an explicit `std.mem.Allocator`.

```zig
const std = @import("std");
const biozig = @import("biozig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var network = biozig.systems.network.Network.init(alloc);
    // ...
}
```

## Testing

Run the full unit test suite to ensure the system is correctly compiled:

```bash
zig build test
```
