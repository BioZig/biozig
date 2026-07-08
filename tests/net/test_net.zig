const std = @import("std");
const posix = std.posix;

test "probe posix sockets" {
    const fd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
    defer posix.close(fd);
    
    var addr: posix.sockaddr.in = undefined;
    addr.family = posix.AF.INET;
    addr.port = std.mem.nativeToBig(u16, 8080);
    addr.addr = std.mem.nativeToBig(u32, 0x7F000001);
}
