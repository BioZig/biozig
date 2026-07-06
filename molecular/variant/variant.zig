const std = @import("std");

pub const VariantType = enum {
    snp,
    insertion,
    deletion,
    substitution,
};

pub const Variant = struct {
    position: usize, // 0-indexed genomic coordinate
    reference: []const u8, // Reference allele string (e.g. "A", "C", "CAG")
    alternate: []const u8, // Alternate allele string (e.g. "G", "T", "CG")
    allocator: std.mem.Allocator,

    pub fn init(position: usize, reference: []const u8, alternate: []const u8, allocator: std.mem.Allocator) !Variant {
        const ref_dupe = try allocator.dupe(u8, reference);
        errdefer allocator.free(ref_dupe);
        const alt_dupe = try allocator.dupe(u8, alternate);
        errdefer allocator.free(alt_dupe);

        var v = Variant{
            .position = position,
            .reference = ref_dupe,
            .alternate = alt_dupe,
            .allocator = allocator,
        };
        if (!v.validate()) {
            return error.InvalidVariant;
        }
        return v;
    }

    pub fn deinit(self: *Variant) void {
        self.allocator.free(self.reference);
        self.allocator.free(self.alternate);
    }

    pub fn clone(self: Variant) !Variant {
        return Variant.init(self.position, self.reference, self.alternate, self.allocator);
    }

    pub fn getType(self: Variant) VariantType {
        const ref_len = self.reference.len;
        const alt_len = self.alternate.len;
        if (ref_len == 1 and alt_len == 1) {
            return .snp;
        } else if (ref_len < alt_len) {
            return .insertion;
        } else if (ref_len > alt_len) {
            return .deletion;
        } else {
            return .substitution;
        }
    }

    pub fn validate(self: Variant) bool {
        // Position validation (no special constraints other than standard bounds)
        // Alleles must not be empty at the same time
        if (self.reference.len == 0 and self.alternate.len == 0) return false;

        // Reference and Alternate must not be identical
        if (std.mem.eql(u8, self.reference, self.alternate)) return false;

        // Characters must be valid IUPAC bases
        for (self.reference) |c| {
            if (!isValidBase(c)) return false;
        }
        for (self.alternate) |c| {
            if (!isValidBase(c)) return false;
        }

        return true;
    }

    fn isValidBase(c: u8) bool {
        return switch (c) {
            'A', 'a', 'C', 'c', 'G', 'g', 'T', 't', 'U', 'u', 'R', 'r', 'Y', 'y', 'S', 's', 'W', 'w', 'K', 'k', 'M', 'm', 'B', 'b', 'D', 'd', 'H', 'h', 'V', 'v', 'N', 'n', '-' => true,
            else => false,
        };
    }

    /// Trims common suffixes and prefixes, adjusting position.
    /// E.g. ref="CAG", alt="CG", pos=100 -> ref="A", alt="", pos=101 (Deletion).
    pub fn normalize(self: *Variant) !void {
        var ref = self.reference;
        var alt = self.alternate;
        var pos = self.position;

        // Trim common suffix from right to left
        while (ref.len > 0 and alt.len > 0 and ref[ref.len - 1] == alt[alt.len - 1]) {
            ref = ref[0 .. ref.len - 1];
            alt = alt[0 .. alt.len - 1];
        }

        // Trim common prefix from left to right
        var prefix_len: usize = 0;
        while (prefix_len < ref.len and prefix_len < alt.len and ref[prefix_len] == alt[prefix_len]) {
            prefix_len += 1;
        }
        if (prefix_len > 0) {
            ref = ref[prefix_len..];
            alt = alt[prefix_len..];
            pos += prefix_len;
        }

        // Assign newly normalized sequences
        const new_ref = try self.allocator.dupe(u8, ref);
        errdefer self.allocator.free(new_ref);
        const new_alt = try self.allocator.dupe(u8, alt);
        errdefer self.allocator.free(new_alt);

        self.allocator.free(self.reference);
        self.allocator.free(self.alternate);

        self.reference = new_ref;
        self.alternate = new_alt;
        self.position = pos;
    }

    pub fn equals(self: Variant, other: Variant) bool {
        return self.position == other.position and
            std.mem.eql(u8, self.reference, other.reference) and
            std.mem.eql(u8, self.alternate, other.alternate);
    }

    pub fn hash(self: Variant) u64 {
        const XxHash64 = @import("core").hashing.XxHash64;
        var hash_val: u64 = 5381;

        var pos_bytes: [@sizeOf(usize)]u8 = undefined;
        std.mem.writeInt(usize, &pos_bytes, self.position, .little);
        hash_val = XxHash64.hash(&pos_bytes, hash_val);
        hash_val = XxHash64.hash(self.reference, hash_val);
        hash_val = XxHash64.hash(self.alternate, hash_val);

        return hash_val;
    }
};
