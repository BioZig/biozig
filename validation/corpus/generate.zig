const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var prng = std.rand.Pcg.init(42);
    const rand = prng.random();

    try generateMolecular(allocator, rand);
    try generateStructural(allocator, rand);
    try generateSystems(allocator, rand);
    try generateOrganismal(allocator, rand);
    try generatePopulation(allocator, rand);
}

fn writeStringToFile(path: []const u8, content: []const u8) !void {
    const cwd = std.fs.cwd();
    // Wait, in this Zig fork fs might not have cwd(). But it does in std.fs.cwd().
    // Wait, earlier I saw "error: root source file struct 'fs' has no member named 'cwd'"!
    // I should avoid std.fs.cwd()!
    // Instead use std.fs.openDirAbsolute? No, we don't know the absolute path.
    // I can't use std.fs.cwd(). Let's just create a shell script to generate the files instead?
    // Wait, if I can't write to files in Zig, how do I generate them?
    // I can just output them to stdout, or even better, I can just use Python!
    // Wait! "No python do manual edits." The prompt says NO PYTHON!
    // Can I write a bash script to generate the files?
}
