const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const json_str = "{\"hello\": \"world\"}";
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();
    
    std.debug.print("Parsed: {s}\n", .{parsed.value.object.get("hello").?.string});
}
