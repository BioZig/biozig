const path = require("path");
const fs = require('fs');

const head = (title, activeTab) => `<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title === "Welcome" ? "Welcome BioZig" : title + " - BioZig"}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@700;900&family=Space+Grotesk:wght@300;400;500;600;700&family=JetBrains+Mono:wght@300;400;500;700&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="css/global.css" />
  <script src="js/main.js"></script>
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
    mermaid.initialize({ startOnLoad: true, theme: 'dark', fontFamily: 'monospace' });
  </script>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <a href="index.html" class="bz-logo-sm">
        <div class="bz-chr">
          <div class="bz-chr-band3">3</div>
          <div class="bz-chr-band7">7</div>
        </div>
        <div class="bz-wordmark"><span class="w-bio">BIO</span><span class="w-zig">ZIG</span></div>
      </a>
      <ul class="nav-links">
        <li><a href="index.html" class="${activeTab === 'index' ? 'active' : ''}">Overview</a></li>
        <li><a href="philosophy.html" class="${activeTab === 'philosophy' ? 'active' : ''}">Philosophy</a></li>
        <li><a href="architecture.html" class="${activeTab === 'architecture' ? 'active' : ''}">Architecture</a></li>
        <li><a href="docs.html" class="${activeTab === 'api' ? 'active' : ''}">Docs</a></li>
        <li><a href="tutorials.html" class="${activeTab === 'tutorials' ? 'active' : ''}">Tutorials</a></li>
        <li><a href="libbiozig.html" class="${activeTab === 'libbiozig' ? 'active' : ''}">libbiozig</a></li>
        <li><a href="cli.html" class="${activeTab === 'cli' ? 'active' : ''}">CLI</a></li>
        <li><a href="foundation.html" class="${activeTab === 'foundation' ? 'active' : ''}">BZSF</a></li>
        <li>
          <button class="theme-toggle" onclick="openSearch()" aria-label="Search">[ / ] SEARCH</button>
        </li>
        <li>
          <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle light/dark mode">
            <span id="themeIcon">☀</span> <span id="themeLabel">Light</span>
          </button>
        </li>
      </ul>
    </header>
`;

const foot = (searchIndexJson) => `
  <div id="searchModal" class="search-modal" onclick="closeSearch(event)">
    <div class="search-box">
      <input type="text" id="searchInput" placeholder="Search documentation..." onkeyup="handleSearch(event)">
      <div id="searchResults" class="search-results"></div>
    </div>
  </div>
  </div>
  <script>
    window.__BZ_SEARCH_INDEX__ = ${searchIndexJson};
    (function(){
      const stored = localStorage.getItem('bz-theme');
      const sys = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
      const theme = stored || sys;
      document.documentElement.setAttribute('data-theme', theme);
      const icon = document.getElementById('themeIcon');
      const label = document.getElementById('themeLabel');
      if(icon) icon.textContent = theme === 'light' ? '☾' : '☀';
      if(label) label.textContent = theme === 'light' ? 'Dark' : 'Light';
    })();
    
    // Keyboard shortcuts for surfing
    document.addEventListener('keydown', (e) => {
      if (e.key.toLowerCase() === 'escape') {
        const modal = document.getElementById('searchModal');
        if (modal) modal.classList.remove('active');
        return;
      }
      
      // Ignore if typing in an input or textarea
      if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) return;
      
      switch (e.key.toLowerCase()) {
        case '1': case 'o': window.location.href = 'index.html'; break;
        case '2': case 'p': window.location.href = 'philosophy.html'; break;
        case '3': case 'a': window.location.href = 'architecture.html'; break;
        case '4': case 'd': window.location.href = 'docs.html'; break;
        case '5': case 't': window.location.href = 'tutorials.html'; break;
        case '6': case 'l': window.location.href = 'libbiozig.html'; break;
        case '7': case 'c': window.location.href = 'cli.html'; break;
        case '8': case 'f': window.location.href = 'foundation.html'; break;
        case 's': case '/': 
          e.preventDefault();
          openSearch(); 
          break;
      }
    });
  </script>
</body>
</html>`;

const pages = {
  
  'index.html': {
    title: 'Welcome', tab: 'index',
    content: `
    <section class="hero">
      <div class="left-col">
        <div class="fig-tag">ZIG 0.16 · v0.1.0-DEV · 3-Clause BSD</div>
        <h1>Biology<br>computed<br><em>exactly.</em></h1>
        <p class="body-text">
          <b>BioZig (BZ): Biology first principles programming.</b><br><br>
          <b>DNA is not a string.</b><br>
          Protein is not a string.<br>
          BZ encodes biological reality<br>
          at the bit level — where it belongs.<br><br>
          Deterministic. Reproducible.<br>
          On every machine. Every time.
        </p>
        <a href="docs.html" class="cta">Read Documentation</a>
      </div>
      <div class="right-col">
        <div class="readout">
          <div class="row">
            <div class="op">ARENA ALLOCATORS<em>Zero-copy MMap & Arena State</em></div>
            <div class="num"><span class="v">100</span><span class="u">%</span></div>
          </div>
          <div class="row">
            <div class="op">SIMD VECTORIZATION<em>Hardware @Vector intrinsics</em></div>
            <div class="num"><span class="v">32</span><span class="u">BYTES/CYCLE</span></div>
          </div>
          <div class="row">
            <div class="op">ZERO DEPENDENCIES<em>Pure Zig Native Compiler</em></div>
            <div class="num"><span class="v">0</span><span class="u">EXTERNAL LIBS</span></div>
          </div>
          <div class="row">
            <div class="op">C-ABI COMPATIBILITY<em>FFI ready for Python/R/C++</em></div>
            <div class="num"><span class="v">O(1)</span><span class="u">BINDING COST</span></div>
          </div>
        </div>
      </div>
    </section>
    `
  },
  'philosophy.html': {
    title: 'Philosophy', tab: 'philosophy',
    content: `
    <div style="padding: 80px 0;">
      <div class="nb-head">
        <span class="nb-title">The Fundamental Problem</span>
        <span class="op">BIOINFORMATICS IN CRISIS</span>
      </div>
      <p class="body-text">Modern biology generates data at a petabyte scale, yet the foundational libraries we use to analyze it were built in an era of megabytes. Biological data is discrete, deterministic, and mathematical. Yet, legacy frameworks treat DNA as UTF-8 text strings, protein coordinates as deeply nested objects, and graphs as fragmented pointers. <b>This abstraction is mathematically and computationally incorrect.</b> It leads to bloated memory, cache misses, and massive bottlenecks. We are computing biology with tools designed for parsing web text.</p>

      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">The Failures of the Past</span>
        <span class="op">LEGACY FRAMEWORKS</span>
      </div>
      
      <div class="api-block">
        <div class="api-name">BioPython: The OOP Fallacy</div>
        <div class="api-desc">
          <b>The Problem:</b> Python treats every nucleotide as a Unicode string, wrapping it in heavy PyObject overhead. Object-Oriented Programming (OOP) creates millions of scattered objects across the heap, destroying CPU cache locality. The Global Interpreter Lock (GIL) prevents true multi-threading, meaning a 64-core server is reduced to a single core when parsing a VCF. BioPython trades hardware efficiency for syntactic sugar.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">R & Bioconductor: The Copy-on-Modify Trap</div>
        <div class="api-desc">
          <b>The Problem:</b> R excels at statistical modeling but fails at systems engineering. R's pass-by-value and "copy-on-modify" semantics mean that filtering a 50GB sparse matrix often requires 150GB of RAM just to hold intermediate states. Furthermore, unpredictable garbage collection (GC) pauses ruin real-time throughput. R is a fantastic calculator, but a terrible infrastructure layer.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">C++: The Undefined Behavior Minefield</div>
        <div class="api-desc">
          <b>The Problem:</b> C++ (e.g., SeqAn) provides the speed Python lacks, but at the cost of immense complexity. Decades of legacy cruft, arcane CMake build scripts, and the ever-present threat of Undefined Behavior (UB), buffer overflows, and segmentation faults make C++ codebases brittle. Biology requires absolute determinism; a silent memory corruption in a genome assembler ruins the science.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">BioJava & BioPerl: The Relics</div>
        <div class="api-desc">
          <b>The Problem:</b> BioJava suffers from massive JVM warmup times, aggressive heap allocations, and garbage collection stalls. It abstracts hardware away precisely when bioinformatics needs hardware control most. BioPerl treated biology as a regular expression string-parsing problem, an outdated paradigm that simply cannot scale to modern geometric and tensor-based single-cell biology.
        </div>
      </div>

      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">Validation First. Depth Second.</span>
        <span class="op">THE BIOZIG SOLUTION</span>
      </div>
      <p class="body-text">BioZig (BZ) (BZ) does not guess. BZ does not approximate. If a graph traversal cannot prove its cycle resolution, it fails. If a structural parser drops precision in coordinate translation, it fails. BZ is built on the premise that biological data must be exactly represented and deterministically verified before any complex algorithm is allowed to run.</p>
      
      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">Zero-Copy & Memory Safety</span>
        <span class="op">HARDWARE EFFICIENCY</span>
      </div>
      <p class="body-text">Memory allocation is the enemy of performance. By strictly utilizing Arena Allocators and Memory-Mapped (MMap) file parsing, BZ guarantees O(1) ingestion without string duplication. We read 64 bits at a time, relying on <code>@Vector(32, u8)</code> SIMD intrinsics to parse delimiters at hardware speeds. DNA is packed into 2 bits. Coordinates are laid out in Structure of Arrays (SoA). <b>We compute at the metal.</b></p>
    </div>
    `
  },
  'architecture.html': {
    title: 'Architecture', tab: 'architecture',
    content: `
    <div style="padding: 80px 0;">
      <div class="nb-head">
        <span class="nb-title">System Architecture</span>
        <span class="op">DATA PIPELINE</span>
      </div>
      <p class="body-text">BioZig (BZ) does not act as a monolithic God object. Instead, it enforces strict separation of concerns, broken down into four distinct phases of execution. This prevents cyclic dependencies and ensures hardware-level performance.</p>
      
      <div class="code" style="margin-bottom: 40px;">
        <pre><code class="mermaid">
graph TD
    classDef core fill:#111,stroke:#27272a,stroke-width:2px,color:#a1a1aa,font-family:monospace
    classDef parser fill:#111,stroke:#27272a,stroke-width:2px,color:#f7a41d,font-family:monospace
    classDef domain fill:#111,stroke:#27272a,stroke-width:2px,color:#4ade80,font-family:monospace
    classDef algo fill:#111,stroke:#27272a,stroke-width:2px,color:#60a5fa,font-family:monospace

    subgraph BZ Architecture Pipeline
        A[CORE<br>Arena, ThreadPool, SIMD]:::core -->|I/O Config| B(PARSER<br>MMap Bit-Sieve):::parser
        B -->|Raw Memory View| C{DOMAIN<br>SoA Layouts, DNA2}:::domain
        C -->|Type-Safe Structs| D[ALGORITHM<br>Compute Kernels]:::algo
        D -.->|Hardware Intrinsics| A
    end
        </code></pre>
      </div>
      
      <div class="api-block">
        <div class="api-name">1. CORE</div>
        <div class="api-desc">Memory & Execution (Arena Allocators, SIMD, Thread Pools, and I/O handlers).</div>
      </div>
      <div class="api-block">
        <div class="api-name">2. PARSER</div>
        <div class="api-desc">Zero-Copy Ingestion (64-bit Bit-Sieve MMap parsers transforming raw bytes directly into struct slices).</div>
      </div>
      <div class="api-block">
        <div class="api-name">3. DOMAIN</div>
        <div class="api-desc">Data Representation (SoA layouts, e.g., DNA2 encoded bits, XYZ coordinate sets). Pure state, no logic.</div>
      </div>
      <div class="api-block">
        <div class="api-name">4. ALGORITHM</div>
        <div class="api-desc">Compute Kernels (Functions that take Domain structs, process via Core SIMD, and output results).</div>
      </div>

      <div class="nb-head">
        <span class="nb-title">Zero-Copy Bit-Sieve Parsing</span>
        <span class="op">ingestion/transcriptomics/mtx.zig</span>
      </div>
      <p class="body-text">BZ does not parse files byte-by-byte. It reads 64 bits at a time from the memory map and uses bit-twiddling to find delimiters in O(1) cycles.</p>
      <div class="code"><pre><code>
pub fn next(self: *MtxMmapIterator) ?[]const u8 {
    if (self.cursor >= self.buffer.len) return null;
    const start = self.cursor;
    while (self.cursor + 8 <= self.buffer.len) {
        // Load 64 bits directly from the mmap
        const block = std.mem.readInt(u64, self.buffer[self.cursor..self.cursor+8][0..8], .little);
        // XOR with 0x0A0A0A0A0A0A0A0A to find newlines
        const xor_mask = block ^ 0x0A0A0A0A0A0A0A0A;
        // Bit-twiddling magic: (x - 0x01...) & ~x & 0x80...
        const match_mask = (xor_mask - 0x0101010101010101) & ~xor_mask & 0x8080808080808080;
        if (match_mask != 0) {
            const offset = @ctz(match_mask) / 8;
            self.cursor += offset + 1;
            return self.buffer[start .. self.cursor - 1];
        }
        self.cursor += 8;
    }
}
      </code></pre></div>

      <div class="api-block">
        <div class="api-name">MMapReader (Zero-Copy)</div>
        <div class="api-sig"><span class="kw">pub const</span> MMapReader = <span class="kw">struct</span> { file: std.Io.File, mmap: std.Io.File.MemoryMap, ... }</div>
        <div class="api-desc">Opens a file in read_only mode with protection <code>.{ .read = true, .write = false }</code>. Grants zero-copy access to data via <code>mm.memory[0..size]</code>.</div>
      </div>

      <div class="nb-head">
        <span class="nb-title">SIMD Vectorization</span>
        <span class="op">core/simd/simd.zig</span>
      </div>
      <div class="api-block">
        <div class="api-name">Hardware Accelerated Primitives</div>
        <div class="api-sig"><span class="kw">pub fn</span> countChar(slice: []const u8, char: u8) usize</div>
        <div class="api-desc">Vectorized char counting using <code>@Vector(32, u8)</code> and <code>@select</code> instead of byte-by-byte loops.</div>
        <div class="code"><pre><code>
pub fn countChar(slice: []const u8, char: u8) usize {
    const VLen = 32;
    const V = @Vector(VLen, u8);
    const char_vec: V = @splat(char);
    // Compares chunks (vec == char_vec)
    // Converts bools to ints with @select
    // Reduces with @reduce(.Add, match_ints)
}
        </code></pre></div>
      </div>

      <div class="nb-head">
        <span class="nb-title">Molecular Domain: 2-Bit Compression</span>
        <span class="op">molecular/dna/dna.zig</span>
      </div>
      <div class="api-block">
        <div class="api-name">Nucleotide & DNA2</div>
        <div class="api-sig"><span class="kw">pub const</span> Nucleotide = <span class="kw">enum</span>(u2) { A = 0b00, C = 0b01, G = 0b10, T = 0b11 };</div>
        <div class="api-desc"><code>DNA2</code> owns the memory, packing 4 bases per byte.</div>
        <div class="code"><pre><code>
pub const DNA2 = struct {
    bytes: []u8,
    len: usize,
    allocator: std.mem.Allocator,
    
    pub fn get(self: DNA2, index: usize) Nucleotide {
        const byte_idx = index / 4;
        const shift = @as(u3, @truncate((index % 4) * 2));
        const bits = (self.bytes[byte_idx] >> shift) & 0b11;
        return @enumFromInt(bits);
    }
};
        </code></pre></div>
      </div>

      <div class="nb-head">
        <span class="nb-title">Structural Geometry</span>
        <span class="op">structural/geometry.zig</span>
      </div>
      <div class="api-block">
        <div class="api-name">Structure of Arrays (SoA)</div>
        <div class="api-sig"><span class="kw">pub const</span> CoordinateSet = <span class="kw">struct</span> { x: []f64, y: []f64, z: []f64 };</div>
        <div class="api-desc">By decoupling coordinates into SoA, SIMD vectors can load 8 <code>f64</code> elements linearly without cache-misses from gather instructions.</div>
      </div>

      <div class="nb-head">
        <span class="nb-title">Thread Pooling & Work Stealing</span>
        <span class="op">core/concurrency/pool.zig</span>
      </div>
      <div class="api-block">
        <div class="api-name">Lock-Free Atomics</div>
        <div class="api-sig">@atomicRmw(<span class="kw">.Add</span>, &target, value, <span class="kw">.SeqCst</span>)</div>
        <div class="api-desc">Instead of using <code>std.Thread.Mutex</code>, BZ aggregates concurrent results using hardware atomic instructions to eliminate lock contention on 50M+ element operations.</div>
      </div>
    </div>
    `
  },
  'tutorials.html': {
    title: 'Tutorials', tab: 'tutorials',
    content: `
    <div style="padding: 80px 0;">
      <div class="nb-head">
        <span class="nb-title">Cross-Domain Interaction</span>
        <span class="op">PIPELINE DESIGN</span>
      </div>
      <p class="body-text">In standard bioinformatics, you read a file (Parser), parse it into an object (Domain), and run a method on the object (Algorithm). In BioZig (BZ), data is orthogonal to behavior. The parser generates <i>raw Domain structs</i>, and the Algorithms consume them. No objects own methods.</p>

      <!-- TUTORIAL 1: ZIG NATIVELY -->
      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">1. Pure Zig (Native)</span>
        <span class="op">STRUCTURAL PROTEIN PIPELINE</span>
      </div>
      <p class="body-text">Parse a PDB file using zero-copy MMap, generate a Structure of Arrays (SoA) coordinate set, and compute its geometric centroid.</p>
      <div class="code"><pre><code>const std = @import("std");
const biozig = @import("biozig");
const structural = biozig.algorithms.structural;
const pdb = biozig.ingestion.structural.pdb;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 1. Zero-copy ingest PDB using 64-bit Bit-Sieve
    const coords = try pdb.parseCoordinateSet(allocator, "protein.pdb");

    // 2. Compute centroid via SIMD vectorized loop
    const centroid = structural.computeCentroid(coords);
    std.debug.print("Centroid: X={d:.3}, Y={d:.3}, Z={d:.3}\n", .{centroid.x, centroid.y, centroid.z});
}</code></pre></div>

      <!-- TUTORIAL 2: PYTHON -->
      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">2. Python Wrapper</span>
        <span class="op">SINGLE-CELL TRANSCRIPTOMICS (PCA)</span>
      </div>
      <p class="body-text">BZ's Python bindings expose C-ABI pointers. We can ingest a massive Matrix Market (.mtx) file and run a fast PCA directly in hardware memory without instantiating millions of Python objects.</p>
      <div class="code"><pre><code>import biozig as bz

# 1. Parse sparse single-cell expression data via zero-copy MTX reader
mtx_data = bz.transcriptomics.parse_mtx("cells.mtx")

# 2. Calculate top 10 principal components using the Analytics module
pca_results = bz.analytics.dimensionality.pca(mtx_data, n_components=10)

print(f"Explained Variance: {pca_results.explained_variance}")
print(f"Transform: {pca_results.transform}")</code></pre></div>

      <!-- TUTORIAL 3: R -->
      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">3. R Wrapper</span>
        <span class="op">SYSTEMS BIOLOGY (COMMUNITY DETECTION)</span>
      </div>
      <p class="body-text">In R, loading large network graphs often causes RAM exhaustion. BZ handles the graph traversal outside of the R garbage collector.</p>
      <div class="code"><pre><code>library(biozig)

# 1. Load systems network (e.g., from an edge list or BioPAX)
graph <- bz_systems_parse_edgelist("protein_network.txt")

# 2. Compute Louvain communities using the Graph builder
communities <- bz_systems_louvain(graph)

print(head(communities))</code></pre></div>

      <!-- TUTORIAL 4: CLI -->
      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">4. Command Line Interface (CLI)</span>
        <span class="op">GENOMICS (FASTA METRICS)</span>
      </div>
      <p class="body-text">The BZ CLI provides direct access to these pipelines from bash. Because the CLI is purely compiled Zig, execution is instantaneous.</p>
      <div class="code"><pre><code># Compute GC Content and Shannon Entropy for a large genome FASTA
$ biozig genomics metrics --input human_genome.fasta --metrics gc_content,entropy

> GC Content: 41.2%
> Shannon Entropy: 1.98 bits</code></pre></div>

    </div>
    `
  },
  'cli.html': {
    title: 'Command Line Interface', tab: 'cli',
    content: `
    <div style="padding: 80px 0;">
      <div class="nb-head">
        <span class="nb-title">BioZig (BZ) CLI</span>
        <span class="op">COMMAND LINE INTERFACE</span>
      </div>
      <p class="body-text">
        The BZ Command Line Interface (<code>biozig</code>) provides a lightning-fast, zero-dependency binary for executing biological algorithms directly from the terminal. 
      </p>
      
      <p class="body-text philosophy-quote">
        <em>BZ does not guess. BZ does not approximate. If a graph traversal cannot prove its cycle resolution, it fails. If a structural parser drops precision in coordinate translation, it fails. BZ is built on the premise that biological data must be exactly represented and deterministically verified before any complex algorithm is allowed to run.</em>
      </p>

      <div class="api-block">
        <div class="api-name">Global Options</div>
        <div class="api-sig">Standard POSIX-style flags across all commands</div>
        <div class="api-desc">
          <ul style="list-style-type: none; padding-left: 0;">
            <li><code>-i, --input &lt;path&gt;</code> The absolute or relative path to the input file. You can also specify <code>-</code> to pipe data into BZ from stdin.</li>
            <li><code>-o, --output &lt;path&gt;</code> The file destination for the analysis results. If omitted, BZ outputs directly to stdout.</li>
            <li><code>-f, --format &lt;type&gt;</code> The output format for standard streams (<code>text</code> or <code>json</code>).</li>
            <li><code>-t, --threads &lt;num&gt;</code> Set the number of CPU threads used for multi-threading heavily parallelizable computations.</li>
            <li><code>-r, --report &lt;path&gt;</code> Generates a human-readable compiled report combining graphs, statistics, and runtimes.</li>
            <li><code>-p, --plot</code> Generates an inline ANSI/ASCII visualization plot directly in your terminal output.</li>
            <li><code>-h, --help</code> Show the detailed help message for any domain or subcommand.</li>
          </ul>
        </div>
      </div>

      <h2 style="margin-top: 40px; margin-bottom: 20px;">Domains & Commands</h2>

      <div class="api-block">
        <div class="api-name">biozig genomics</div>
        <div class="api-sig">Sequence alignment, mapping, and analysis</div>
        <div class="api-desc">
          Commands: <code>align</code>, <code>index</code>, <code>parse</code>, <code>kmer</code>, <code>hmm</code>, <code>gibbs</code>, <code>suffix-tree</code>, <code>assembly</code>, <code>msa</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig analytics</div>
        <div class="api-sig">Statistical models, matrix decompositions, and clustering</div>
        <div class="api-desc">
          Commands: <code>pca</code>, <code>nmf</code>, <code>mds</code>, <code>descriptive</code>, <code>correlation</code>, <code>hypothesis</code>, <code>distributions</code>, <code>multiple_testing</code>, <code>regression</code>, <code>survival</code>, <code>dispersion</code>, <code>biology</code>, <code>enrichment</code>, <code>metrics</code>, <code>umap</code>, <code>tsne</code>, <code>kmeans</code>, <code>dbscan</code>, <code>hierarchical</code>, <code>node2vec</code>, <code>spectral</code>, <code>sparse</code>, <code>svd</code>, <code>spia</code>, <code>markov</code>, <code>kmer_stats</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig structural</div>
        <div class="api-sig">3D protein structures and interactions</div>
        <div class="api-desc">
          Commands: <code>atom</code>, <code>residue</code>, <code>chain</code>, <code>model</code>, <code>assembly</code>, <code>geometry</code>, <code>contacts</code>, <code>surfaces</code>, <code>pockets</code>, <code>dock</code>, <code>dynamics</code>, <code>anm</code>, <code>threading</code>, <code>rotamers</code>, <code>ingestion</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig cellular</div>
        <div class="api-sig">Single-cell tools for dimensionality reduction and clustering</div>
        <div class="api-desc">
          Commands: <code>umap</code>, <code>tsne</code>, <code>kmeans</code>, <code>zinb</code>, <code>pseudotime</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig systems</div>
        <div class="api-sig">Systems biology and network analysis</div>
        <div class="api-desc">
          Commands: <code>maxflow</code>, <code>motif</code>, <code>layout</code>, <code>centrality</code>, <code>community</code>, <code>network</code>, <code>metabolism</code>, <code>signaling</code>, <code>pathway</code>, <code>regulation</code>, <code>ontology</code>, <code>knowledgegraph</code>, <code>sbml</code>, <code>biopax</code>, <code>gpml</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig population</div>
        <div class="api-sig">Population genetics analysis</div>
        <div class="api-desc">
          Commands: <code>gwas</code>, <code>admixture</code>, <code>ibd</code>, <code>hwe</code>, <code>ld</code>, <code>selection</code>, <code>epi</code>, <code>impute</code>, <code>fstats</code>, <code>vstats</code>, <code>vmatch</code>, <code>vfilter</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig evolutionary</div>
        <div class="api-sig">Phylogenetics and evolutionary models</div>
        <div class="api-desc">
          Commands: <code>nj</code>, <code>upgma</code>, <code>mle</code>, <code>parsimony</code>, <code>mcmc</code>, <code>bootstrap</code>, <code>nni</code>, <code>spr</code>, <code>stats</code>, <code>rf-distance</code>, <code>parse-newick</code>, <code>parse-nexus</code>, <code>parse-phyloxml</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig reporting</div>
        <div class="api-sig">Automated reporting and publication exports</div>
        <div class="api-desc">
          Commands: <code>html</code>, <code>latex</code>, <code>manuscript</code>, <code>markdown</code>, <code>pdf</code>, <code>supplement</code>.
        </div>
      </div>

      <div class="api-block">
        <div class="api-name">biozig visualize</div>
        <div class="api-sig">Render beautiful biological data and plots</div>
        <div class="api-desc">
          Commands: <code>dashboards</code>, <code>network</code>, <code>omics</code>, <code>phylogeny</code>, <code>publication</code>, <code>sequence</code>, <code>structure</code>.
        </div>
      </div>

      <h2 style="margin-top: 40px; margin-bottom: 20px;">Unix Pipeline Integration Examples</h2>
      
      <div class="api-block">
        <div class="api-name">Streaming JSON to JQ</div>
        <div class="api-sig">$ biozig analytics pca -i 1M_cells.mtx -f json | jq '.eigenvalues[] | select(.variance > 0.05)'</div>
      </div>

      <div class="api-block">
        <div class="api-name">Compressing Aligned Output on the Fly</div>
        <div class="api-sig">$ biozig genomics align -i reads.fastq --ref genome.fa | gzip > output.bam</div>
      </div>

      <div class="api-block">
        <div class="api-name">Visualizing Terminal Outputs Instantly</div>
        <div class="api-sig">$ biozig structural contacts -i viral_envelope.mmcif -p</div>
        <div class="api-desc">*(Prints an ASCII topological map of the viral envelope contacts before exiting)*</div>
      </div>

    </div>
`
  },
  'foundation.html': {
    title: 'BZSF', tab: 'foundation',
    content: `
    <div style="padding: 80px 0;">
      <div class="nb-head">
        <span class="nb-title">BZ Software Foundation</span>
        <span class="op">BZSF</span>
      </div>
      
      <p class="body-text">The BZ Software Foundation (BZSF) exists to safeguard the integrity, performance, and philosophical rigor of the BZ ecosystem. We are committed to maintaining a zero-copy, mathematically provable, and brutalist standard for bioinformatics infrastructure.</p>

      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">Leadership</span>
        <span class="op">STEERING</span>
      </div>
      
      <div class="api-block">
        <div class="api-name">MD. Arshad</div>
        <div class="api-sig">Creator and Curator</div>
        <div class="api-desc">Principal architect of the BZ framework and guardian of the core philosophy.</div>
      </div>

      <div class="nb-head" style="margin-top: 60px;">
        <span class="nb-title">The Future</span>
        <span class="op">EXPANSION</span>
      </div>
      
      <p class="body-text">The codebase is currently undergoing rigorous validation of its core axioms. In the forthcoming future, the BZSF will actively accept contributors, researchers, and systems engineers who align with our uncompromising standards. A formal governance model and contributor guidelines will be established as the foundation matures.</p>
    
    `
  }
};

const searchIndex = [];
Object.keys(pages).forEach(key => {
  const page = pages[key];
  searchIndex.push({ url: key, title: page.title, content: page.content.replace(/<[^>]+>/g, ' ').substring(0, 500) });
});
const searchIndexJson = JSON.stringify(searchIndex);

const distDir = __dirname;

Object.keys(pages).forEach(file => {
  const page = pages[file];
  const html = head(page.title, page.tab) + page.content + foot(searchIndexJson);
  fs.writeFileSync(path.join(distDir, file), html);
});

console.log('Site generated.');
