const std = @import("std");

/// Represents a component in a metabolic reaction.
pub const ReactionComponent = struct {
    allocator: std.mem.Allocator,
    metabolite_id: []const u8,
    stoichiometry: f64,

    pub fn init(allocator: std.mem.Allocator, metabolite_id: []const u8, stoichiometry: f64) !ReactionComponent {
        return .{
            .allocator = allocator,
            .metabolite_id = try allocator.dupe(u8, metabolite_id),
            .stoichiometry = stoichiometry,
        };
    }

    pub fn deinit(self: *ReactionComponent) void {
        self.allocator.free(self.metabolite_id);
    }
};

/// Represents a metabolic reaction.
pub const Reaction = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    enzyme_id: ?[]const u8,
    substrates: std.ArrayList(ReactionComponent),
    products: std.ArrayList(ReactionComponent),
    reversible: bool,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, enzyme_id: ?[]const u8, reversible: bool) !Reaction {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .enzyme_id = if (enzyme_id) |e| try allocator.dupe(u8, e) else null,
            .substrates = .empty,
            .products = .empty,
            .reversible = reversible,
        };
    }

    pub fn deinit(self: *Reaction) void {
        self.allocator.free(self.id);
        if (self.enzyme_id) |e| self.allocator.free(e);
        for (self.substrates.items) |*sub| sub.deinit();
        for (self.products.items) |*prod| prod.deinit();
        self.substrates.deinit(self.allocator);
        self.products.deinit(self.allocator);
    }

    pub fn addSubstrate(self: *Reaction, metabolite_id: []const u8, stoichiometry: f64) !void {
        try self.substrates.append(self.allocator, try ReactionComponent.init(self.allocator, metabolite_id, stoichiometry));
    }

    pub fn addProduct(self: *Reaction, metabolite_id: []const u8, stoichiometry: f64) !void {
        try self.products.append(self.allocator, try ReactionComponent.init(self.allocator, metabolite_id, stoichiometry));
    }
};

/// Represents a metabolic network mapping metabolites and reactions.
pub const MetabolicNetwork = struct {
    allocator: std.mem.Allocator,
    reactions: std.ArrayList(Reaction),
    
    // Maps metabolite_id -> list of reaction indices where it is a substrate
    metabolite_as_substrate: std.StringHashMap(std.ArrayList(usize)),
    // Maps metabolite_id -> list of reaction indices where it is a product
    metabolite_as_product: std.StringHashMap(std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator) MetabolicNetwork {
        return .{
            .allocator = allocator,
            .reactions = .empty,
            .metabolite_as_substrate = std.StringHashMap(std.ArrayList(usize)).init(allocator),
            .metabolite_as_product = std.StringHashMap(std.ArrayList(usize)).init(allocator),
        };
    }

    pub fn deinit(self: *MetabolicNetwork) void {
        for (self.reactions.items) |*r| r.deinit();
        self.reactions.deinit(self.allocator);

        var sub_iter = self.metabolite_as_substrate.iterator();
        while (sub_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.metabolite_as_substrate.deinit();

        var prod_iter = self.metabolite_as_product.iterator();
        while (prod_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.metabolite_as_product.deinit();
    }

    pub fn addReaction(self: *MetabolicNetwork, reaction: Reaction) !void {
        const idx = self.reactions.items.len;
        try self.reactions.append(self.allocator, reaction);

        for (reaction.substrates.items) |sub| {
            const entry = try self.metabolite_as_substrate.getOrPut(sub.metabolite_id);
            if (!entry.found_existing) {
                entry.key_ptr.* = try self.allocator.dupe(u8, sub.metabolite_id);
                entry.value_ptr.* = .empty;
            }
            try entry.value_ptr.append(self.allocator, idx);
        }

        for (reaction.products.items) |prod| {
            const entry = try self.metabolite_as_product.getOrPut(prod.metabolite_id);
            if (!entry.found_existing) {
                entry.key_ptr.* = try self.allocator.dupe(u8, prod.metabolite_id);
                entry.value_ptr.* = .empty;
            }
            try entry.value_ptr.append(self.allocator, idx);
        }
    }

    pub fn getReactionsUsingSubstrate(self: MetabolicNetwork, metabolite_id: []const u8) ?[]const usize {
        if (self.metabolite_as_substrate.get(metabolite_id)) |list| {
            return list.items;
        }
        return null;
    }

    pub fn getReactionsProducing(self: MetabolicNetwork, metabolite_id: []const u8) ?[]const usize {
        if (self.metabolite_as_product.get(metabolite_id)) |list| {
            return list.items;
        }
        return null;
    }
};

test "MetabolicNetwork reaction building" {
    const alloc = std.testing.allocator;
    var net = MetabolicNetwork.init(alloc);
    defer net.deinit();

    // Glucose + ATP -> G6P + ADP (Hexokinase)
    var hk = try Reaction.init(alloc, "R_HK1", "HK1", false);
    try hk.addSubstrate("Glucose", 1.0);
    try hk.addSubstrate("ATP", 1.0);
    try hk.addProduct("G6P", 1.0);
    try hk.addProduct("ADP", 1.0);
    try net.addReaction(hk);

    const producers = net.getReactionsProducing("G6P");
    try std.testing.expect(producers != null);
    try std.testing.expectEqual(@as(usize, 1), producers.?.len);
    
    const consumers = net.getReactionsUsingSubstrate("ATP");
    try std.testing.expect(consumers != null);
    try std.testing.expectEqual(@as(usize, 1), consumers.?.len);
}
