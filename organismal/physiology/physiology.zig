const std = @import("std");
const core = @import("core");

/// Key-value metadata pair for physiological system annotations.
pub const MetadataEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// Represents a physiological system (e.g. cardiovascular, central nervous system).
/// Supports hierarchical structures via optional parent references.
pub const PhysiologicalSystem = struct {
    /// System identifier (e.g. FMA/MA term, like "MA:0000012")
    id: []const u8,
    /// System name (e.g. "Cardiovascular System")
    name: []const u8,
    /// Parent system identifier (null if top-level)
    parent_id: ?[]const u8,
    /// System annotations/metadata
    metadata: []const MetadataEntry,

    /// Initializes a PhysiologicalSystem.
    pub fn init(
        id: []const u8,
        name: []const u8,
        parent_id: ?[]const u8,
        metadata: []const MetadataEntry,
    ) PhysiologicalSystem {
        return .{
            .id = id,
            .name = name,
            .parent_id = parent_id,
            .metadata = metadata,
        };
    }
};

/// Represents a numerical physiological measurement (e.g. blood pressure, body temperature).
pub const PhysiologicalMeasurement = struct {
    /// Type/kind of measurement (e.g. "heart_rate")
    measurement_type: []const u8,
    /// Numerical value
    value: f64,
    /// Unit of measurement (e.g. "bpm", "mmHg", "C")
    unit: []const u8,

    /// Initializes a PhysiologicalMeasurement.
    pub fn init(
        m_type: []const u8,
        value: f64,
        unit: []const u8,
    ) PhysiologicalMeasurement {
        return .{
            .measurement_type = m_type,
            .value = value,
            .unit = unit,
        };
    }

    /// Validates if the physiological measurement value is within physically possible biological limits
    /// based on the measurement type.
    pub fn validate(self: PhysiologicalMeasurement) bool {
        const val = self.value;
        if (std.math.isNan(val) or std.math.isInf(val)) return false;

        const m_type = self.measurement_type;
        if (eqlIgnoreCase(m_type, "heart_rate") or eqlIgnoreCase(m_type, "pulse")) {
            return val >= 0.0 and val <= 300.0;
        } else if (eqlIgnoreCase(m_type, "body_temperature") or eqlIgnoreCase(m_type, "temperature")) {
            if (eqlIgnoreCase(self.unit, "c") or eqlIgnoreCase(self.unit, "celsius")) {
                return val >= 15.0 and val <= 50.0;
            } else if (eqlIgnoreCase(self.unit, "f") or eqlIgnoreCase(self.unit, "fahrenheit")) {
                return val >= 59.0 and val <= 122.0;
            }
        } else if (eqlIgnoreCase(m_type, "systolic_blood_pressure") or eqlIgnoreCase(m_type, "systolic_bp")) {
            return val >= 20.0 and val <= 300.0;
        } else if (eqlIgnoreCase(m_type, "diastolic_blood_pressure") or eqlIgnoreCase(m_type, "diastolic_bp")) {
            return val >= 10.0 and val <= 200.0;
        } else if (eqlIgnoreCase(m_type, "respiratory_rate") or eqlIgnoreCase(m_type, "rr")) {
            return val >= 0.0 and val <= 150.0;
        } else if (eqlIgnoreCase(m_type, "blood_glucose") or eqlIgnoreCase(m_type, "glucose")) {
            return val >= 0.0 and val <= 1000.0;
        }

        return true; // Unknown types default to valid if non-NaN/Inf
    }

    /// Serializes the measurement to a binary format.
    pub fn serialize(self: PhysiologicalMeasurement, writer: anytype) !void {
        try core.serialization.serialize(writer, self);
    }

    /// Deserializes a measurement from a binary format, allocating memory for its slices.
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !PhysiologicalMeasurement {
        return try core.serialization.deserialize(reader, PhysiologicalMeasurement, allocator);
    }

    /// Frees any memory allocated for this measurement during deserialization.
    pub fn deinit(self: PhysiologicalMeasurement, allocator: std.mem.Allocator) void {
        core.serialization.free(allocator, self);
    }

    fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, 0..) |char_a, i| {
            if (std.ascii.toUpper(char_a) != std.ascii.toUpper(b[i])) return false;
        }
        return true;
    }
};

test "PhysiologicalSystem and PhysiologicalMeasurement operations" {
    const allocator = std.testing.allocator;

    const sys_parent = PhysiologicalSystem.init("MA:0000012", "Nervous System", null, &[_]MetadataEntry{});
    const sys_child = PhysiologicalSystem.init("MA:0000220", "Central Nervous System", "MA:0000012", &[_]MetadataEntry{});

    try std.testing.expectEqualStrings("MA:0000012", sys_parent.id);
    try std.testing.expectEqualStrings("MA:0000220", sys_child.id);
    try std.testing.expectEqualStrings("MA:0000012", sys_child.parent_id.?);

    // Measurement validation
    const m_ok = PhysiologicalMeasurement.init("heart_rate", 72.0, "bpm");
    const m_err = PhysiologicalMeasurement.init("heart_rate", 450.0, "bpm");
    const m_temp_c = PhysiologicalMeasurement.init("body_temperature", 37.0, "C");
    const m_temp_f = PhysiologicalMeasurement.init("body_temperature", 98.6, "F");
    const m_temp_err = PhysiologicalMeasurement.init("body_temperature", 37.0, "F"); // 37 F is too low/freezing

    try std.testing.expect(m_ok.validate());
    try std.testing.expect(!m_err.validate());
    try std.testing.expect(m_temp_c.validate());
    try std.testing.expect(m_temp_f.validate());
    try std.testing.expect(!m_temp_err.validate());

    // Serialization roundtrip
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try m_ok.serialize(&writer);

    const written = writer.buffered();
    var reader = std.Io.Reader.fixed(written);
    const deserialized = try PhysiologicalMeasurement.deserialize(&reader, allocator);
    defer deserialized.deinit(allocator);

    try std.testing.expectEqualStrings(m_ok.measurement_type, deserialized.measurement_type);
    try std.testing.expectEqual(m_ok.value, deserialized.value);
    try std.testing.expectEqualStrings(m_ok.unit, deserialized.unit);
}
