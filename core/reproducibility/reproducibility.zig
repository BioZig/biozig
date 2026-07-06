const std = @import("std");
const Sha256 = @import("../hashing/hashing.zig").Sha256;

/// A record tracking a file's path and SHA256 hash.
pub const FileTrack = struct {
    path: []const u8,
    hash: [32]u8,
};

/// A key-value metadata pair.
pub const MetadataPair = struct {
    key: []const u8,
    value: []const u8,
};

/// Structured execution record for publication-ready scientific reproducibility.
pub const ReproducibilityRecord = struct {
    allocator: std.mem.Allocator,
    compiler_version: []const u8,
    target_cpu: []const u8,
    target_os: []const u8,
    timestamp: i64,
    random_seed: u64,
    inputs: std.ArrayList(FileTrack),
    outputs: std.ArrayList(FileTrack),
    metadata: std.ArrayList(MetadataPair),

    pub fn init(allocator: std.mem.Allocator, random_seed: u64) !*ReproducibilityRecord {
        const self = try allocator.create(ReproducibilityRecord);
        errdefer allocator.destroy(self);

        const compiler_ver = builtinCompilerVersion();
        const cpu_name = builtinCpuName();
        const os_name = builtinOsName();

        self.* = .{
            .allocator = allocator,
            .compiler_version = try allocator.dupe(u8, compiler_ver),
            .target_cpu = try allocator.dupe(u8, cpu_name),
            .target_os = try allocator.dupe(u8, os_name),
            .timestamp = 0,
            .random_seed = random_seed,
            .inputs = .empty,
            .outputs = .empty,
            .metadata = .empty,
        };

        return self;
    }

    pub fn deinit(self: *ReproducibilityRecord) void {
        self.allocator.free(self.compiler_version);
        self.allocator.free(self.target_cpu);
        self.allocator.free(self.target_os);

        for (self.inputs.items) |item| {
            self.allocator.free(item.path);
        }
        self.inputs.deinit(self.allocator);

        for (self.outputs.items) |item| {
            self.allocator.free(item.path);
        }
        self.outputs.deinit(self.allocator);

        for (self.metadata.items) |item| {
            self.allocator.free(item.key);
            self.allocator.free(item.value);
        }
        self.metadata.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    pub fn trackInputData(self: *ReproducibilityRecord, path: []const u8, data: []const u8) !void {
        const hash_val = Sha256.hash(data);
        try self.inputs.append(self.allocator, .{
            .path = try self.allocator.dupe(u8, path),
            .hash = hash_val,
        });
    }

    pub fn trackOutputData(self: *ReproducibilityRecord, path: []const u8, data: []const u8) !void {
        const hash_val = Sha256.hash(data);
        try self.outputs.append(self.allocator, .{
            .path = try self.allocator.dupe(u8, path),
            .hash = hash_val,
        });
    }

    pub fn addMetadata(self: *ReproducibilityRecord, key: []const u8, value: []const u8) !void {
        try self.metadata.append(self.allocator, .{
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, value),
        });
    }

    pub fn serializeRecord(self: *ReproducibilityRecord, writer: anytype) !void {
        const serializeBinary = @import("../serialization/serialization.zig").serialize;
        try serializeBinary(writer, self.compiler_version);
        try serializeBinary(writer, self.target_cpu);
        try serializeBinary(writer, self.target_os);
        try serializeBinary(writer, self.timestamp);
        try serializeBinary(writer, self.random_seed);

        try serializeBinary(writer, @as(u64, self.inputs.items.len));
        for (self.inputs.items) |item| {
            try serializeBinary(writer, item.path);
            try serializeBinary(writer, item.hash);
        }

        try serializeBinary(writer, @as(u64, self.outputs.items.len));
        for (self.outputs.items) |item| {
            try serializeBinary(writer, item.path);
            try serializeBinary(writer, item.hash);
        }

        try serializeBinary(writer, @as(u64, self.metadata.items.len));
        for (self.metadata.items) |item| {
            try serializeBinary(writer, item.key);
            try serializeBinary(writer, item.value);
        }
    }

    fn builtinCompilerVersion() []const u8 {
        return @import("builtin").zig_version_string;
    }

    fn builtinCpuName() []const u8 {
        return @import("builtin").cpu.model.name;
    }

    fn builtinOsName() []const u8 {
        return @tagName(@import("builtin").os.tag);
    }
};

test "reproducibility record tracking and serialization" {
    var record = try ReproducibilityRecord.init(std.testing.allocator, 0xABCDEF1234567890);
    defer record.deinit();

    try record.trackInputData("data/input.fa", ">seq1\nACGTACGT");
    try record.trackOutputData("results/counts.bin", "\x01\x02\x03\x04");
    try record.addMetadata("experiment_name", "sequencing_run_1");

    try std.testing.expectEqual(record.inputs.items.len, 1);
    try std.testing.expectEqual(record.outputs.items.len, 1);
    try std.testing.expectEqual(record.metadata.items.len, 1);

    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try record.serializeRecord(&writer);

    const serialized_len = writer.buffered().len;
    try std.testing.expect(serialized_len > 0);
}
