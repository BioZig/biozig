const std = @import("std");
const testing = std.testing;
const systems = @import("systems");
const sig = systems.signaling;

test "SignalingNetwork - Empty initialization" {
    const alloc = testing.allocator;
    var net = sig.SignalingNetwork.init(alloc);
    defer net.deinit();

    try testing.expect(net.getDownstreamEvents("A") == null);
}

test "SignalingNetwork - Single Event Cascade" {
    const alloc = testing.allocator;
    var net = sig.SignalingNetwork.init(alloc);
    defer net.deinit();

    try net.addEvent("A", "B", .Phosphorylation);
    const down = net.getDownstreamEvents("A");
    try testing.expect(down != null);
    try testing.expectEqual(@as(usize, 1), down.?.len);
}

test "SignalingNetwork - Branched Cascade" {
    const alloc = testing.allocator;
    var net = sig.SignalingNetwork.init(alloc);
    defer net.deinit();

    try net.addEvent("A", "B", .Phosphorylation);
    try net.addEvent("A", "C", .Dephosphorylation);
    const down = net.getDownstreamEvents("A");
    try testing.expectEqual(@as(usize, 2), down.?.len);
}
