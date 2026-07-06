const std = @import("std");
const chain_mod = @import("../chain/chain.zig");
const Chain = chain_mod.Chain;

pub const Model = struct {
    id: usize,
    chains: []const Chain,

    pub fn init(id: usize, chains: []const Chain) Model {
        return .{
            .id = id,
            .chains = chains,
        };
    }

    pub fn chainCount(self: Model) usize {
        return self.chains.len;
    }

    pub fn residueCount(self: Model) usize {
        var total: usize = 0;
        for (self.chains) |c| {
            total += c.len();
        }
        return total;
    }

    pub fn atomCount(self: Model) usize {
        var total: usize = 0;
        for (self.chains) |c| {
            for (c.residues) |res| {
                total += res.atoms.len;
            }
        }
        return total;
    }

    pub fn lookupChain(self: Model, id: []const u8) ?*const Chain {
        for (self.chains, 0..) |_, i| {
            if (std.mem.eql(u8, self.chains[i].getId(), id)) return &self.chains[i];
        }
        return null;
    }

    pub const Stats = struct {
        chains: usize,
        residues: usize,
        atoms: usize,
    };

    pub fn statistics(self: Model) Stats {
        return .{
            .chains = self.chainCount(),
            .residues = self.residueCount(),
            .atoms = self.atomCount(),
        };
    }
};
