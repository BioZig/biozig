const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const metabolism = systems.metabolism;

test "Reaction - Substrate addition" {
    const alloc = testing.allocator;
    var r = try metabolism.Reaction.init(alloc, "R1", "ENZ", false);
    defer r.deinit();
    try r.addSubstrate("S1", 2.0);
    try testing.expectEqual(@as(usize, 1), r.substrates.items.len);
}

test "Reaction - Product addition" {
    const alloc = testing.allocator;
    var r = try metabolism.Reaction.init(alloc, "R1", "ENZ", false);
    defer r.deinit();
    try r.addProduct("P1", 3.0);
    try testing.expectEqual(@as(usize, 1), r.products.items.len);
}

test "MetabolicNetwork - Graph interactions" {
    const alloc = testing.allocator;
    var net = metabolism.MetabolicNetwork.init(alloc);
    defer net.deinit();

    var r = try metabolism.Reaction.init(alloc, "R1", "E1", false);
    try r.addProduct("MET1", 1.0);
    try net.addReaction(r);

    const prod = net.getReactionsProducing("MET1");
    try testing.expect(prod != null);
    try testing.expectEqual(@as(usize, 1), prod.?.len);
}
