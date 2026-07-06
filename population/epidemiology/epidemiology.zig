const std = @import("std");

/// Represents an exposure variable.
pub const Exposure = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8) !Exposure {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
        };
    }

    pub fn deinit(self: *Exposure) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
    }
};

/// Represents a clinical or biological outcome.
pub const Outcome = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8) !Outcome {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
        };
    }

    pub fn deinit(self: *Outcome) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
    }
};

/// Represents an epidemiological association (e.g., Odds Ratio, Relative Risk).
pub const EpidemiologicalAssociation = struct {
    exposure_id: []const u8,
    outcome_id: []const u8,
    effect_measure: []const u8, // e.g., "OddsRatio", "HazardRatio"
    effect_value: f64,
    ci_lower: f64,
    ci_upper: f64,
    p_value: f64,
};

/// Represents a general study cohort.
pub const Cohort = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    size: usize,
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, size: usize) !Cohort {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .size = size,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Cohort) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }
};

/// Represents a Case-Control study design.
pub const CaseControlStudy = struct {
    allocator: std.mem.Allocator,
    study_id: []const u8,
    cases: Cohort,
    controls: Cohort,
    associations: std.ArrayList(EpidemiologicalAssociation),

    pub fn init(allocator: std.mem.Allocator, study_id: []const u8, cases: Cohort, controls: Cohort) !CaseControlStudy {
        return .{
            .allocator = allocator,
            .study_id = try allocator.dupe(u8, study_id),
            .cases = cases,
            .controls = controls,
            .associations = .empty,
        };
    }

    pub fn deinit(self: *CaseControlStudy) void {
        self.allocator.free(self.study_id);
        self.cases.deinit();
        self.controls.deinit();
        
        for (self.associations.items) |a| {
            self.allocator.free(a.exposure_id);
            self.allocator.free(a.outcome_id);
            self.allocator.free(a.effect_measure);
        }
        self.associations.deinit(self.allocator);
    }

    pub fn addAssociation(self: *CaseControlStudy, exp_id: []const u8, out_id: []const u8, measure: []const u8, value: f64, lower: f64, upper: f64, p: f64) !void {
        const assoc = EpidemiologicalAssociation{
            .exposure_id = try self.allocator.dupe(u8, exp_id),
            .outcome_id = try self.allocator.dupe(u8, out_id),
            .effect_measure = try self.allocator.dupe(u8, measure),
            .effect_value = value,
            .ci_lower = lower,
            .ci_upper = upper,
            .p_value = p,
        };
        try self.associations.append(self.allocator, assoc);
    }
};

test "Epidemiology study and associations" {
    const alloc = std.testing.allocator;
    const cases = try Cohort.init(alloc, "C_01", "T2D_Cases", 5000);
    const controls = try Cohort.init(alloc, "C_02", "Healthy_Controls", 10000);
    
    var study = try CaseControlStudy.init(alloc, "S_01", cases, controls);
    defer study.deinit();

    try study.addAssociation("BMI", "T2D", "OddsRatio", 1.8, 1.6, 2.0, 1e-12);
    
    try std.testing.expectEqual(@as(usize, 1), study.associations.items.len);
    try std.testing.expectEqualStrings("OddsRatio", study.associations.items[0].effect_measure);
}
