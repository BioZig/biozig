const std = @import("std");
const reporting = @import("../reporting.zig");
const pub_mod = @import("visualization").publication;

/// Represents a formal scientific manuscript structure.
pub const Manuscript = struct {
    title: []const u8,
    abstract: []const u8,
    introduction: []const u8,
    methods: []const u8,
    results: []const u8,
    discussion: []const u8,
    references: []const pub_mod.Reference,

    /// Initializes a Manuscript.
    pub fn init(
        title: []const u8,
        abstract: []const u8,
        introduction: []const u8,
        methods: []const u8,
        results: []const u8,
        discussion: []const u8,
        references: []const pub_mod.Reference,
    ) Manuscript {
        return .{
            .title = title,
            .abstract = abstract,
            .introduction = introduction,
            .methods = methods,
            .results = results,
            .discussion = discussion,
            .references = references,
        };
    }

    /// Converts the specialized manuscript structure into a generic Report representation.
    /// Allocates the sections array using the provided allocator.
    /// The caller is responsible for freeing the returned Report sections array.
    pub fn toReport(self: Manuscript, authors: []const u8, allocator: std.mem.Allocator) !reporting.Report {
        const sections = try allocator.alloc(reporting.Section, 4);
        errdefer allocator.free(sections);

        sections[0] = .{ .title = "Introduction", .content = self.introduction };
        sections[1] = .{ .title = "Materials & Methods", .content = self.methods };
        sections[2] = .{ .title = "Results", .content = self.results };
        sections[3] = .{ .title = "Discussion", .content = self.discussion };

        return reporting.Report.init(
            self.title,
            authors,
            self.abstract,
            sections,
            &[_]pub_mod.Figure{},
            &[_]pub_mod.Table{},
            self.references,
            &[_]pub_mod.Figure{},
            &[_]pub_mod.Table{},
            null,
        );
    }
};

test "Manuscript structure and report conversion" {
    const allocator = std.testing.allocator;

    const ms = Manuscript.init(
        "GVAE PPI Deconvolution",
        "This is a study abstract.",
        "We introduce PPI network deconvolution...",
        "We trained a Graph Attention GATv2 encoder...",
        "We achieved 0.99 link prediction AUC...",
        "Our methods recover modular protein biology...",
        &[_]pub_mod.Reference{},
    );

    const report = try ms.toReport("Arshad, M.", allocator);
    defer allocator.free(report.sections);

    try std.testing.expectEqualStrings("GVAE PPI Deconvolution", report.title);
    try std.testing.expectEqual(report.sections.len, 4);
    try std.testing.expectEqualStrings("Introduction", report.sections[0].title);
    try std.testing.expectEqualStrings("Materials & Methods", report.sections[1].title);
}
