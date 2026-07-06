const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

pub const CBiozigNetwork = extern struct {
    ptr: ?*anyopaque,
};

extern fn biozig_systems_network_create() callconv(.c) CBiozigNetwork;
extern fn biozig_systems_network_add_node(net_c: CBiozigNetwork, id_c: [*c]const u8) callconv(.c) usize;

test "biozig_systems_network_create" {
    _ = @import("c_api");
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();
    
    const net = biozig_systems_network_create();
    try std.testing.expect(net.ptr != null);
    
    const node_id = "node_1\x00";
    const n = biozig_systems_network_add_node(net, node_id.ptr);
    try std.testing.expect(n == 0); // first node is index 0
}
