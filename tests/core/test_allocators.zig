const std = @import("std");
const core = @import("core");

test "allocators OOB and boundary" {
    const TrackingAllocator = core.allocators.TrackingAllocator;
    var tracker = TrackingAllocator.init(std.testing.allocator);
    const alloc = tracker.allocator();

    // 0 byte alloc
    const p0 = try alloc.alloc(u8, 0);
    try std.testing.expectEqual(p0.len, 0);
    alloc.free(p0);

    const p1 = try alloc.alloc(u8, 1);
    alloc.free(p1);
    
    try std.testing.expectEqual(tracker.getBytesAllocated(), tracker.getBytesFreed());
}
