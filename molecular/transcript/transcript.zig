const std = @import("std");
const dna_mod = @import("../dna/dna.zig");

pub const Strand = enum {
    forward,
    reverse,
};

pub const Exon = struct {
    start: usize, // 0-indexed genomic start coordinate
    end: usize,   // 0-indexed genomic end coordinate (exclusive)

    pub fn len(self: Exon) usize {
        std.debug.assert(self.end >= self.start);
        return self.end - self.start;
    }
};

/// Validates that exons are non-overlapping and sorted in ascending genomic order.
pub fn validateExons(exons: []const Exon) bool {
    if (exons.len == 0) return true;
    for (exons) |ex| {
        if (ex.start >= ex.end) return false;
    }
    for (0..exons.len - 1) |i| {
        if (exons[i].end > exons[i + 1].start) return false;
    }
    return true;
}

pub const Transcript = struct {
    id: []const u8,
    strand: Strand,
    exons: []const Exon,
    allocator: std.mem.Allocator,

    pub fn init(id: []const u8, strand: Strand, exons: []const Exon, allocator: std.mem.Allocator) !Transcript {
        if (!validateExons(exons)) return error.InvalidExons;
        return Transcript{
            .id = try allocator.dupe(u8, id),
            .strand = strand,
            .exons = try allocator.dupe(Exon, exons),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Transcript) void {
        self.allocator.free(self.id);
        self.allocator.free(self.exons);
    }

    pub fn length(self: Transcript) usize {
        var total: usize = 0;
        for (self.exons) |ex| {
            total += ex.len();
        }
        return total;
    }

    /// Reconstructs the spliced transcript sequence from genomic DNA2.
    pub fn reconstructDNA2(self: Transcript, genomic_dna: dna_mod.DNA2View, allocator: std.mem.Allocator) !dna_mod.DNA2 {
        const tx_len = self.length();
        const num_bytes = (tx_len * 2 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = dna_mod.DNA2{ .bytes = bytes, .len = tx_len, .allocator = allocator };
        const packer = res.packer();

        if (self.strand == .forward) {
            var idx: usize = 0;
            for (self.exons) |exon| {
                const sub = genomic_dna.slice(exon.start, exon.end);
                for (0..sub.len) |i| {
                    packer.set(idx, @intFromEnum(sub.get(i)));
                    idx += 1;
                }
            }
        } else {
            // Reverse strand transcript: transcribe exons in reverse order, reverse complement elements
            var idx: usize = 0;
            var j = self.exons.len;
            while (j > 0) {
                j -= 1;
                const exon = self.exons[j];
                const sub = genomic_dna.slice(exon.start, exon.end);
                var k = sub.len;
                while (k > 0) {
                    k -= 1;
                    const val = @intFromEnum(sub.get(k));
                    packer.set(idx, ~val); // complement
                    idx += 1;
                }
            }
        }

        return res;
    }

    /// Reconstructs the spliced transcript sequence from genomic DNA4.
    pub fn reconstructDNA4(self: Transcript, genomic_dna: dna_mod.DNA4View, allocator: std.mem.Allocator) !dna_mod.DNA4 {
        const tx_len = self.length();
        const num_bytes = (tx_len * 4 + 7) / 8;
        const bytes = try allocator.alloc(u8, num_bytes);
        errdefer allocator.free(bytes);

        var res = dna_mod.DNA4{ .bytes = bytes, .len = tx_len, .allocator = allocator };
        const packer = res.packer();

        if (self.strand == .forward) {
            var idx: usize = 0;
            for (self.exons) |exon| {
                const sub = genomic_dna.slice(exon.start, exon.end);
                for (0..sub.len) |i| {
                    packer.set(idx, @intFromEnum(sub.get(i)));
                    idx += 1;
                }
            }
        } else {
            var idx: usize = 0;
            var j = self.exons.len;
            while (j > 0) {
                j -= 1;
                const exon = self.exons[j];
                const sub = genomic_dna.slice(exon.start, exon.end);
                var k = sub.len;
                while (k > 0) {
                    k -= 1;
                    const val = dna_mod.DNA4View.complementIUPAC(sub.get(k));
                    packer.set(idx, @intFromEnum(val));
                    idx += 1;
                }
            }
        }

        return res;
    }

    /// Maps a 0-indexed spliced transcript coordinate to the genomic coordinate.
    pub fn transcriptToGenomic(self: Transcript, tx_coord: usize) !usize {
        if (tx_coord >= self.length()) return error.OutOfRange;

        if (self.strand == .forward) {
            var accum: usize = 0;
            for (self.exons) |exon| {
                const exon_len = exon.len();
                if (tx_coord < accum + exon_len) {
                    return exon.start + (tx_coord - accum);
                }
                accum += exon_len;
            }
        } else {
            var accum: usize = 0;
            var j = self.exons.len;
            while (j > 0) {
                j -= 1;
                const exon = self.exons[j];
                const exon_len = exon.len();
                if (tx_coord < accum + exon_len) {
                    return exon.end - 1 - (tx_coord - accum);
                }
                accum += exon_len;
            }
        }

        return error.OutOfRange;
    }

    /// Maps a 0-indexed genomic coordinate to the spliced transcript coordinate.
    pub fn genomicToTranscript(self: Transcript, genomic_coord: usize) !usize {
        if (self.strand == .forward) {
            var accum: usize = 0;
            for (self.exons) |exon| {
                if (genomic_coord >= exon.start and genomic_coord < exon.end) {
                    return accum + (genomic_coord - exon.start);
                }
                accum += exon.len();
            }
        } else {
            var accum: usize = 0;
            var j = self.exons.len;
            while (j > 0) {
                j -= 1;
                const exon = self.exons[j];
                if (genomic_coord >= exon.start and genomic_coord < exon.end) {
                    return accum + (exon.end - 1 - genomic_coord);
                }
                accum += exon.len();
            }
        }

        return error.GenomicCoordinateNotExonic;
    }
};
