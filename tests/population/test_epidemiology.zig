const std = @import("std");
const pop = @import("population");
const epi = pop.epidemiology;

test "Exposure and Outcome - init and deinit" {
    const alloc = std.testing.allocator;
    var exp = try epi.Exposure.init(alloc, "E01", "Smoking");
    defer exp.deinit();
    try std.testing.expectEqualStrings("E01", exp.id);
    try std.testing.expectEqualStrings("Smoking", exp.name);
    
    var out = try epi.Outcome.init(alloc, "O01", "Lung Cancer");
    defer out.deinit();
    try std.testing.expectEqualStrings("O01", out.id);
    try std.testing.expectEqualStrings("Lung Cancer", out.name);
}

test "Cohort - init and metadata" {
    const alloc = std.testing.allocator;
    var cohort = try epi.Cohort.init(alloc, "C01", "Healthy", 1000);
    defer cohort.deinit();
    
    try std.testing.expectEqualStrings("C01", cohort.id);
    try std.testing.expectEqualStrings("Healthy", cohort.name);
    try std.testing.expectEqual(@as(usize, 1000), cohort.size);
}

test "CaseControlStudy - operations" {
    const alloc = std.testing.allocator;
    const cases = try epi.Cohort.init(alloc, "C1", "Cases", 100);
    const controls = try epi.Cohort.init(alloc, "C2", "Controls", 200);
    
    var study = try epi.CaseControlStudy.init(alloc, "Study1", cases, controls);
    defer study.deinit();
    
    try std.testing.expectEqualStrings("Study1", study.study_id);
    try std.testing.expectEqual(@as(usize, 100), study.cases.size);
    try std.testing.expectEqual(@as(usize, 200), study.controls.size);
    
    try study.addAssociation("Exp1", "Out1", "OR", 2.5, 1.5, 3.5, 0.001);
    try study.addAssociation("Exp2", "Out1", "RR", 1.2, 1.0, 1.4, 0.05);
    
    try std.testing.expectEqual(@as(usize, 2), study.associations.items.len);
    try std.testing.expectEqualStrings("Exp1", study.associations.items[0].exposure_id);
    try std.testing.expectEqualStrings("OR", study.associations.items[0].effect_measure);
    try std.testing.expectEqual(@as(f64, 2.5), study.associations.items[0].effect_value);
}

test "CaseControlStudy - edge cases" {
    const alloc = std.testing.allocator;
    const cases = try epi.Cohort.init(alloc, "C1", "Cases", 0);
    const controls = try epi.Cohort.init(alloc, "C2", "Controls", 0);
    
    var study = try epi.CaseControlStudy.init(alloc, "Empty", cases, controls);
    defer study.deinit();
    
    try study.addAssociation("", "", "", std.math.nan(f64), 0.0, 0.0, 1.0);
    try std.testing.expect(std.math.isNan(study.associations.items[0].effect_value));
}
