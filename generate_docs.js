const fs = require('fs');
const path = require('path');

const globalCss = fs.readFileSync('css/global.css', 'utf8');
if (!globalCss.includes('.docs-layout')) {
  const extraCss = `
/* DOCS SUB-LAYOUT */
.docs-layout { display: grid; grid-template-columns: 240px 1fr; gap: 56px; padding: 48px 0; }
.docs-sidebar { border-right: 1px solid var(--rule); padding-right: 32px; }
.docs-sidebar h4 { font-family: var(--mono); font-size: 10px; color: var(--dim); letter-spacing: 0.1em; text-transform: uppercase; margin-bottom: 16px; margin-top: 32px; }
.docs-sidebar h4:first-child { margin-top: 0; }
.docs-nav { list-style: none; display: flex; flex-direction: column; gap: 12px; }
.docs-nav a { font-size: 14px; color: var(--fg); text-decoration: none; font-weight: 500; transition: color 0.15s; }
.docs-nav a:hover, .docs-nav a.active { color: var(--acc); }
.docs-content h2 { margin-top: 56px; padding-bottom: 12px; border-bottom: 1px solid var(--rule); }
.docs-content h2:first-child { margin-top: 0; }
.docs-content h3 { margin-top: 32px; font-size: 18px; color: var(--fg); }
.docs-content p { font-size: 15px; line-height: 1.8; color: var(--dim); margin-bottom: 24px; }
.docs-content ul { padding-left: 24px; margin-bottom: 24px; color: var(--dim); line-height: 1.8; font-size: 15px; }
`;
  fs.appendFileSync('css/global.css', extraCss);
}

const makeHead = (title, activeTab, activeDoc) => `<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title} — BioZig Docs</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@700;900&family=Space+Grotesk:wght@300;400;500;600;700&family=JetBrains+Mono:wght@300;400;500;700&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="../css/global.css" />
  <script src="../js/main.js"></script>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <a href="../index.html" class="bz-logo-sm">
        <div class="bz-chr">
          <div class="bz-chr-band3">3</div>
          <div class="bz-chr-band7">7</div>
        </div>
        <div class="bz-wordmark"><span class="w-bio">BIO</span><span class="w-zig">ZIG</span></div>
      </a>
      <ul class="nav-links">
        <li><a href="../index.html" class="${activeTab === 'index' ? 'active' : ''}">Overview</a></li>
        <li><a href="../philosophy.html" class="${activeTab === 'philosophy' ? 'active' : ''}">Philosophy</a></li>
        <li><a href="index.html" class="${activeTab === 'docs' ? 'active' : ''}">Documentation</a></li>
        <li><a href="../benchmarks.html" class="${activeTab === 'benchmarks' ? 'active' : ''}">Benchmarks</a></li>
        <li>
          <button class="theme-btn" onclick="toggleTheme()" aria-label="Toggle light/dark mode">
            <span class="icon" id="themeIcon">☀</span>
            <span id="themeLabel">Light</span>
          </button>
        </li>
      </ul>
    </header>
    <div class="docs-layout">
      <aside class="docs-sidebar">
        <h4>Core Architecture</h4>
        <ul class="docs-nav">
          <li><a href="index.html" class="${activeDoc === 'index' ? 'active' : ''}">System Overview</a></li>
          <li><a href="interaction.html" class="${activeDoc === 'interaction' ? 'active' : ''}">Cross-Domain Interaction</a></li>
        </ul>
        <h4>Data Ingestion</h4>
        <ul class="docs-nav">
          <li><a href="parsers.html" class="${activeDoc === 'parsers' ? 'active' : ''}">Zero-Copy Parsers</a></li>
          <li><a href="net.html" class="${activeDoc === 'net' ? 'active' : ''}">Network Streaming</a></li>
        </ul>
        <h4>Execution Engine</h4>
        <ul class="docs-nav">
          <li><a href="algorithms.html" class="${activeDoc === 'algorithms' ? 'active' : ''}">Running Algorithms</a></li>
        </ul>
        <h4>Domain Libraries</h4>
        <ul class="docs-nav">
          <li><a href="domains.html" class="${activeDoc === 'domains' ? 'active' : ''}">L1-L6 Domains</a></li>
        </ul>
      </aside>
      <main class="docs-content">
`;

const foot = `
      </main>
    </div>
  </div>
</body>
</html>`;

const pages = {
  'index.html': {
    title: 'System Overview', tab: 'docs', doc: 'index',
    content: `
      <div class="nb-head">
        <span class="nb-title">System Overview</span>
        <span class="op">ARCHITECTURE · DATA PIPELINE</span>
      </div>
      <h2>The BioZig Data Pipeline</h2>
      <p>BioZig does not act as a monolithic God object. Instead, it enforces strict separation of concerns, broken down into four distinct phases of execution. This prevents cyclic dependencies and ensures hardware-level performance.</p>
      
      <div class="arch-grid">
        <div class="arch-cell"><span class="arch-num">1. CORE</span><div class="arch-title">Memory & Execution</div><div class="arch-desc">Arena Allocators, SIMD, Thread Pools, and I/O handlers.</div></div>
        <div class="arch-cell"><span class="arch-num">2. PARSER</span><div class="arch-title">Zero-Copy Ingestion</div><div class="arch-desc">64-bit Bit-Sieve MMap parsers transforming raw bytes directly into struct slices.</div></div>
        <div class="arch-cell"><span class="arch-num">3. DOMAIN</span><div class="arch-title">Data Representation</div><div class="arch-desc">SoA layouts (e.g., DNA2 encoded bits, XYZ coordinate sets). Pure state, no logic.</div></div>
        <div class="arch-cell"><span class="arch-num">4. ALGORITHM</span><div class="arch-title">Compute Kernels</div><div class="arch-desc">Functions that take Domain structs, process via Core SIMD, and output results.</div></div>
      </div>
    `
  },
  'interaction.html': {
    title: 'Cross-Domain Interaction', tab: 'docs', doc: 'interaction',
    content: `
      <div class="nb-head">
        <span class="nb-title">Cross-Domain Interaction</span>
        <span class="op">PIPELINE DESIGN</span>
      </div>
      <h2>How Components Talk</h2>
      <p>In standard bioinformatics, you read a file (Parser), parse it into an object (Domain), and run a method on the object (Algorithm). In BioZig, data is orthogonal to behavior. The parser generates <i>raw Domain structs</i>, and the Algorithms consume them. No objects own methods.</p>

      <h3>1. The Data Flow</h3>
      <ul>
        <li><b>Disk ➔ Parser:</b> Memory mapped directly. No reading bytes into strings.</li>
        <li><b>Parser ➔ Domain:</b> The parser populates Structure of Arrays (SoA) representations using the Core <code>ArenaAllocator</code>.</li>
        <li><b>Domain ➔ Algorithm:</b> The algorithm receives slices <code>[]f64</code> or <code>[]u64</code> from the Domain structs.</li>
        <li><b>Algorithm ➔ Hardware:</b> The algorithm loads those slices into SIMD vectors <code>@Vector(N, f64)</code> and computes.</li>
      </ul>

      <h3>Example: The Pipeline in Action</h3>
      <div class="code">
<span class="cm">// 1. Core provides memory and file handles</span>
<span class="kw">var</span> arena = std.heap.ArenaAllocator.init(allocator);
<span class="kw">const</span> file = try std.fs.cwd().openFile("data.vcf", .{});

<span class="cm">// 2. Parser ingests data into Domain structures</span>
<span class="kw">var</span> iter = try VcfIterator.init(file);
<span class="kw">const</span> population_data = try iter.parseAll(arena.allocator());

<span class="cm">// 3. Algorithm executes on Domain data</span>
<span class="kw">const</span> ld_scores = try algorithms.population.computeLinkageDisequilibrium(
    arena.allocator(), 
    population_data.genotypes, 
    population_data.frequencies
);
      </div>
    `
  },
  'net.html': {
    title: 'Network Streaming', tab: 'docs', doc: 'net',
    content: `
      <div class="nb-head">
        <span class="nb-title">Network Streaming</span>
        <span class="op">O(1) MEMORY INGESTION</span>
      </div>
      <h2>The BitSieve Engine</h2>
      <p>BioZig's <code>net/</code> module features a strictly bounded O(1) memory double-buffered ring architecture (BitSieve). It isolates network latency and CPU mathematics into independent threads, guaranteeing zero thread-starvation or out-of-memory errors on massive biological datasets.</p>

      <h3>Supported APIs & Protocol Routing</h3>
      <p>BioZig seamlessly routes requests via <code>curl</code> (for HTTP REST) and native <code>ftp.zig</code> (for raw TCP FTP modes). Supported APIs include: NCBI Entrez, UniProt, RCSB PDB, ChEMBL, and Ensembl.</p>

      <h3>CLI Usage</h3>
      <div class="code">
<span class="cm"># Dynamically compute GC Skew and Markov transitions for SARS-CoV-2</span>
biozig fetch --db ncbi --query NC_045512.2 --analyze comprehensive
      </div>

      <h3>Python Interoperability (GIL-Bypass)</h3>
      <p>Using the C-ABI, high-level languages can trigger the BitSieve state machine. The Zig background thread handles all network I/O, entirely releasing the Python GIL.</p>
      <div class="code">
<span class="kw">from</span> biozig <span class="kw">import</span> BioZigContext, stream_genome

<span class="kw">with</span> BioZigContext():
    <span class="cm"># Native streaming, chunked at 8KB O(1) memory bounds</span>
    <span class="kw">for</span> chunk <span class="kw">in</span> stream_genome("pdb", "1CRN"):
        <span class="kw">print</span>(chunk)
      </div>
    `
  },
  'parsers.html': {
    title: 'Zero-Copy Parsers', tab: 'docs', doc: 'parsers',
    content: `
      <div class="nb-head">
        <span class="nb-title">Zero-Copy Parsers</span>
        <span class="op">INGESTION MODULES</span>
      </div>
      <h2>Parsing at the Speed of NVMe</h2>
      <p>BioZig parsers are fundamentally different from Python's <code>Bio.SeqIO</code>. We utilize a <b>64-bit Sliding Bit-Sieve</b> via <code>mmap</code>. We read 8 bytes at a time directly from the OS page cache and use bitwise XOR masks and <code>@ctz</code> (count trailing zeros) to find delimiters without branching.</p>

      <h3>FASTA Ingestion</h3>
      <div class="code">
<span class="cm">// Initialize memory-mapped file parser</span>
<span class="kw">var</span> parser = <span class="kw">try</span> FastaIterator.<span class="fn">init</span>(<span class="str">"human_genome.fa"</span>);
<span class="kw">defer</span> parser.<span class="fn">deinit</span>();

<span class="kw">while</span> (<span class="kw">try</span> parser.<span class="fn">next</span>()) |record| {
    <span class="cm">// record.id and record.seq are direct []const u8 slices of the mmap buffer</span>
    <span class="cm">// We do not copy the genome into RAM. We just point to it.</span>
    std.debug.print(<span class="str">"Found chr: {s}, len: {d}\n"</span>, .{ record.id, record.seq.len });
}
      </div>

      <h3>VCF (Variant Call Format)</h3>
      <div class="code">
<span class="kw">var</span> vcf = <span class="kw">try</span> VcfIterator.<span class="fn">init</span>(<span class="str">"cohort.vcf"</span>);
<span class="kw">while</span> (<span class="kw">try</span> vcf.<span class="fn">next</span>()) |variant| {
    <span class="cm">// variant.pos is parsed via highly optimized SIMD integer parsing</span>
    <span class="kw">if</span> (variant.pos > 1000000) <span class="kw">break</span>;
}
      </div>
      
      <h3>PDB / mmCIF (Structural)</h3>
      <p>Coordinate files are parsed directly into Structure of Arrays (SoA). The X, Y, and Z coordinates are instantly grouped into contiguous memory blocks.</p>
    `
  },
  'algorithms.html': {
    title: 'Running Algorithms', tab: 'docs', doc: 'algorithms',
    content: `
      <div class="nb-head">
        <span class="nb-title">Running Algorithms</span>
        <span class="op">HARDWARE VECTORIZATION</span>
      </div>
      <h2>Compute Kernels</h2>
      <p>BioZig provides specific kernels in the <code>algorithms/</code> module. These are highly tuned to utilize Zig's <code>@Vector</code> types and <code>std.Thread.Pool</code>.</p>

      <h3>K-mer Counting (Genomics)</h3>
      <div class="code">
<span class="kw">const</span> seq = <span class="str">"ATCGATCGATCGATCG"</span>;
<span class="cm">// Packs sequence into 2-bit representation</span>
<span class="kw">const</span> packed_seq = <span class="kw">try</span> core.numerics.<span class="fn">pack2Bit</span>(allocator, seq);

<span class="cm">// Runs multi-threaded hash accumulation</span>
<span class="kw">var</span> kmer_map = <span class="kw">try</span> algorithms.genomics.<span class="fn">countKmers</span>(allocator, packed_seq, 7);
      </div>

      <h3>RMSD / Kabsch (Structural)</h3>
      <div class="code">
<span class="cm">// SoA Coordinate Set</span>
<span class="kw">const</span> set_a = CoordinateSet{ .x = x_arr_a, .y = y_arr_a, .z = z_arr_a };
<span class="kw">const</span> set_b = CoordinateSet{ .x = x_arr_b, .y = y_arr_b, .z = z_arr_b };

<span class="cm">// Explicit SIMD Kabsch alignment</span>
<span class="kw">const</span> transform = <span class="kw">try</span> algorithms.structural.<span class="fn">kabschAlignment</span>(set_a, set_b);
<span class="kw">const</span> rmsd = <span class="kw">try</span> algorithms.structural.<span class="fn">computeRMSD</span>(set_a, set_b, transform);
      </div>

      <h3>FM-Index Search</h3>
      <div class="code">
<span class="cm">// The index is pre-computed</span>
<span class="kw">const</span> index = <span class="kw">try</span> algorithms.genomics.<span class="fn">buildFmIndex</span>(allocator, genome_seq);

<span class="cm">// Querying takes O(m) time where m is query length, regardless of genome size</span>
<span class="kw">const</span> hits = <span class="kw">try</span> algorithms.genomics.<span class="fn">fmSearch</span>(allocator, index, <span class="str">"ATGCCT"</span>);
      </div>
    `
  },
  'domains.html': {
    title: 'Domain Libraries', tab: 'docs', doc: 'domains',
    content: `
      <div class="nb-head">
        <span class="nb-title">Domain Libraries</span>
        <span class="op">BIOLOGICAL REPRESENTATIONS</span>
      </div>
      <h2>L1-L6 Overview</h2>
      <p>Data structures in BioZig are grouped by biological domain. They dictate <i>how</i> memory is laid out.</p>

      <ul>
        <li><b>L1 - Molecular:</b> Handles sequence logic. Enums for <code>Base2</code>, <code>Base4</code>, <code>AminoAcid</code>. Slices of bits for DNA.</li>
        <li><b>L2 - Structural:</b> 3D grids, KD-Trees for fast spatial neighbor queries, SoA coordinates.</li>
        <li><b>L3 - Cellular:</b> Lineage DAGs (Directed Acyclic Graphs), spatial transcriptomics matrices (Sparse Matrix representations).</li>
        <li><b>L4 - Systems:</b> Graph adjacency lists for pathways and metabolism flux models.</li>
        <li><b>L5 - Population:</b> Haplotype arrays (bit matrices), GWAS summary statistics (contiguous memory).</li>
        <li><b>L6 - Evolutionary:</b> Phylogenetic trees (flattened arrays representing tree nodes) to maintain cache locality, avoiding pointer-chasing linked lists.</li>
      </ul>
    `
  }
};

fs.mkdirSync('docs', { recursive: true });
for (const [file, data] of Object.entries(pages)) {
  fs.writeFileSync(path.join('docs', file), makeHead(data.title, data.tab, data.doc) + data.content + foot);
}
console.log("Built detailed documentation site in docs/ successfully.");
