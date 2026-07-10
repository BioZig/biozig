const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Create and export Core module
    const core_module = b.createModule(.{
        .root_source_file = b.path("core/core.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.modules.put(b.graph.arena, "core", core_module) catch @panic("OOM");

    // Define the Core static library
    const core_lib = b.addLibrary(.{
        .name = "biozig-core",
        .root_module = core_module,
        .linkage = .static,
    });
    b.installArtifact(core_lib);

    // 2. Create and export Molecular module (depends on core)
    const molecular_module = b.createModule(.{
        .root_source_file = b.path("molecular/molecular.zig"),
        .target = target,
        .optimize = optimize,
    });
    molecular_module.addImport("core", core_module);
    b.modules.put(b.graph.arena, "molecular", molecular_module) catch @panic("OOM");

    // Define the Molecular static library
    const molecular_lib = b.addLibrary(.{
        .name = "biozig-molecular",
        .root_module = molecular_module,
        .linkage = .static,
    });
    b.installArtifact(molecular_lib);

    // 3. Create and export Structural module (depends on core and molecular)
    const structural_module = b.createModule(.{
        .root_source_file = b.path("structural/structural.zig"),
        .target = target,
        .optimize = optimize,
    });
    structural_module.addImport("core", core_module);
    structural_module.addImport("molecular", molecular_module);
    b.modules.put(b.graph.arena, "structural", structural_module) catch @panic("OOM");

    // Define the Structural static library
    const structural_lib = b.addLibrary(.{
        .name = "biozig-structural",
        .root_module = structural_module,
        .linkage = .static,
    });
    b.installArtifact(structural_lib);

    // 4. Create and export Cellular module (depends on core and molecular)
    const cellular_module = b.createModule(.{
        .root_source_file = b.path("cellular/cellular.zig"),
        .target = target,
        .optimize = optimize,
    });
    cellular_module.addImport("core", core_module);
    cellular_module.addImport("molecular", molecular_module);
    b.modules.put(b.graph.arena, "cellular", cellular_module) catch @panic("OOM");

    const cellular_lib = b.addLibrary(.{
        .name = "biozig-cellular",
        .root_module = cellular_module,
        .linkage = .static,
    });
    b.installArtifact(cellular_lib);

    // 5. Create and export Systems module (depends on core, molecular, cellular)
    const systems_module = b.createModule(.{
        .root_source_file = b.path("systems/systems.zig"),
        .target = target,
        .optimize = optimize,
    });
    systems_module.addImport("core", core_module);
    systems_module.addImport("molecular", molecular_module);
    systems_module.addImport("cellular", cellular_module);
    b.modules.put(b.graph.arena, "systems", systems_module) catch @panic("OOM");

    const systems_lib = b.addLibrary(.{
        .name = "biozig-systems",
        .root_module = systems_module,
        .linkage = .static,
    });
    b.installArtifact(systems_lib);

    // 6. Create and export Organismal module (depends on core, molecular, structural)
    const organismal_module = b.createModule(.{
        .root_source_file = b.path("organismal/organismal.zig"),
        .target = target,
        .optimize = optimize,
    });
    organismal_module.addImport("core", core_module);
    organismal_module.addImport("molecular", molecular_module);
    organismal_module.addImport("structural", structural_module);
    b.modules.put(b.graph.arena, "organismal", organismal_module) catch @panic("OOM");

    // Define the Organismal static library
    const organismal_lib = b.addLibrary(.{
        .name = "biozig-organismal",
        .root_module = organismal_module,
        .linkage = .static,
    });
    b.installArtifact(organismal_lib);

    // 5. Create and export Visualization module (depends on core and structural)
    const visualization_module = b.createModule(.{
        .root_source_file = b.path("visualization/visualization.zig"),
        .target = target,
        .optimize = optimize,
    });
    visualization_module.addImport("core", core_module);
    visualization_module.addImport("structural", structural_module);
    b.modules.put(b.graph.arena, "visualization", visualization_module) catch @panic("OOM");

    // Define the Visualization static library
    const visualization_lib = b.addLibrary(.{
        .name = "biozig-visualization",
        .root_module = visualization_module,
        .linkage = .static,
    });
    b.installArtifact(visualization_lib);

    // 6. Create and export Reporting module (depends on core and visualization)
    const reporting_module = b.createModule(.{
        .root_source_file = b.path("reporting/reporting.zig"),
        .target = target,
        .optimize = optimize,
    });
    reporting_module.addImport("core", core_module);
    reporting_module.addImport("visualization", visualization_module);
    b.modules.put(b.graph.arena, "reporting", reporting_module) catch @panic("OOM");

    // Define the Reporting static library
    const reporting_lib = b.addLibrary(.{
        .name = "biozig-reporting",
        .root_module = reporting_module,
        .linkage = .static,
    });
    b.installArtifact(reporting_lib);

    // 7. Create and export Ingestion module
    const ingestion_module = b.createModule(.{
        .root_source_file = b.path("ingestion/ingestion.zig"),
        .target = target,
        .optimize = optimize,
    });
    ingestion_module.addImport("core", core_module);
    ingestion_module.addImport("molecular", molecular_module);
    ingestion_module.addImport("cellular", cellular_module);
    ingestion_module.addImport("structural", structural_module);
    ingestion_module.addImport("systems", systems_module);
    ingestion_module.addImport("visualization", visualization_module);
    b.modules.put(b.graph.arena, "ingestion", ingestion_module) catch @panic("OOM");

    // Define the Ingestion static library
    const ingestion_lib = b.addLibrary(.{
        .name = "biozig-ingestion",
        .root_module = ingestion_module,
        .linkage = .static,
    });
    b.installArtifact(ingestion_lib);

    const analytics_module = b.createModule(.{
        .root_source_file = b.path("analytics/analytics.zig"),
        .target = target,
        .optimize = optimize,
    });
    analytics_module.addImport("core", core_module);
    b.modules.put(b.graph.arena, "analytics", analytics_module) catch @panic("OOM");

    const analytics_lib = b.addLibrary(.{
        .name = "biozig-analytics",
        .root_module = analytics_module,
        .linkage = .static,
    });
    b.installArtifact(analytics_lib);

    // 8. Create and export Algorithms module
    const algorithms_module = b.createModule(.{
        .root_source_file = b.path("algorithms/algorithms.zig"),
        .target = target,
        .optimize = optimize,
    });
    algorithms_module.addImport("core", core_module);
    algorithms_module.addImport("molecular", molecular_module);
    algorithms_module.addImport("cellular", cellular_module);
    algorithms_module.addImport("visualization", visualization_module);
    algorithms_module.addImport("analytics", analytics_module);
    b.modules.put(b.graph.arena, "algorithms", algorithms_module) catch @panic("OOM");

    const algorithms_lib = b.addLibrary(.{
        .name = "biozig-algorithms",
        .root_module = algorithms_module,
        .linkage = .static,
    });
    b.installArtifact(algorithms_lib);

    // Interoperability C-ABI Layer
    const interoperability_module = b.createModule(.{
        .root_source_file = b.path("interoperability/c_api.zig"),
        .target = target,
        .optimize = optimize,
    });
    interoperability_module.addImport("core", core_module);
    interoperability_module.addImport("molecular", molecular_module);
    interoperability_module.addImport("algorithms", algorithms_module);
    interoperability_module.addImport("ingestion", ingestion_module);
    interoperability_module.addImport("analytics", analytics_module);
    interoperability_module.addImport("structural", structural_module);
    interoperability_module.addImport("cellular", cellular_module);
    interoperability_module.addImport("systems", systems_module);
    interoperability_module.addImport("visualization", visualization_module);
    const net_module = b.createModule(.{
        .root_source_file = b.path("net/net.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.modules.put(b.graph.arena, "net", net_module) catch @panic("OOM");

    const net_lib = b.addLibrary(.{
        .name = "biozig-net",
        .root_module = net_module,
        .linkage = .static,
    });
    b.installArtifact(net_lib);

    interoperability_module.addImport("net", net_module);


    // 9. Register unit tests
    const core_tests = b.addTest(.{
        .root_module = core_module,
    });
    const run_core_tests = b.addRunArtifact(core_tests);

    const molecular_tests = b.addTest(.{
        .root_module = molecular_module,
    });
    const run_molecular_tests = b.addRunArtifact(molecular_tests);

    const structural_tests = b.addTest(.{
        .root_module = structural_module,
    });
    const run_structural_tests = b.addRunArtifact(structural_tests);

    const organismal_tests = b.addTest(.{
        .root_module = organismal_module,
    });
    const run_organismal_tests = b.addRunArtifact(organismal_tests);

    const visualization_tests = b.addTest(.{
        .root_module = visualization_module,
    });
    const run_visualization_tests = b.addRunArtifact(visualization_tests);

    const reporting_tests = b.addTest(.{
        .root_module = reporting_module,
    });
    const run_reporting_tests = b.addRunArtifact(reporting_tests);

    const ingestion_tests = b.addTest(.{
        .root_module = ingestion_module,
    });
    const run_ingestion_tests = b.addRunArtifact(ingestion_tests);

    const algorithms_tests = b.addTest(.{
        .root_module = algorithms_module,
    });
    const run_algorithms_tests = b.addRunArtifact(algorithms_tests);

    const interoperability_tests = b.addTest(.{
        .root_module = interoperability_module,
    });
    const run_interoperability_tests = b.addRunArtifact(interoperability_tests);

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_molecular_tests.step);
    test_step.dependOn(&run_structural_tests.step);
    test_step.dependOn(&run_organismal_tests.step);
    test_step.dependOn(&run_visualization_tests.step);
    test_step.dependOn(&run_reporting_tests.step);
    test_step.dependOn(&run_ingestion_tests.step);
    test_step.dependOn(&run_algorithms_tests.step);
    test_step.dependOn(&run_interoperability_tests.step);

    // 8. Register documentation generation
    const docs_step = b.step("docs", "Generate HTML documentation for all modules");

    const install_core_docs = b.addInstallDirectory(.{
        .source_dir = core_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/core",
    });
    docs_step.dependOn(&install_core_docs.step);

    const install_molecular_docs = b.addInstallDirectory(.{
        .source_dir = molecular_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/molecular",
    });
    docs_step.dependOn(&install_molecular_docs.step);

    const install_structural_docs = b.addInstallDirectory(.{
        .source_dir = structural_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/structural",
    });
    docs_step.dependOn(&install_structural_docs.step);

    const install_organismal_docs = b.addInstallDirectory(.{
        .source_dir = organismal_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/organismal",
    });
    docs_step.dependOn(&install_organismal_docs.step);

    const install_visualization_docs = b.addInstallDirectory(.{
        .source_dir = visualization_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/visualization",
    });
    docs_step.dependOn(&install_visualization_docs.step);

    const install_reporting_docs = b.addInstallDirectory(.{
        .source_dir = reporting_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/reporting",
    });
    docs_step.dependOn(&install_reporting_docs.step);

    const install_ingestion_docs = b.addInstallDirectory(.{
        .source_dir = ingestion_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/ingestion",
    });
    docs_step.dependOn(&install_ingestion_docs.step);

    const install_algorithms_docs = b.addInstallDirectory(.{
        .source_dir = algorithms_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/algorithms",
    });
    docs_step.dependOn(&install_algorithms_docs.step);

    const cli_module = b.createModule(.{
        .root_source_file = b.path("cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_module.addImport("core", core_module);
    cli_module.addImport("molecular", molecular_module);
    cli_module.addImport("algorithms", algorithms_module);
    cli_module.addImport("analytics", analytics_module);
    cli_module.addImport("ingestion", ingestion_module);
    cli_module.addImport("structural", structural_module);
    cli_module.addImport("visualization", visualization_module);
    cli_module.addImport("cellular", cellular_module);

    const population_module = b.createModule(.{
        .root_source_file = b.path("population/population.zig"),
        .target = target,
        .optimize = optimize,
    });
    population_module.addImport("core", core_module);
    b.modules.put(b.graph.arena, "population", population_module) catch @panic("OOM");
    interoperability_module.addImport("population", population_module);

    const libbiozig_shared = b.addLibrary(.{
        .name = "biozig",
        .root_module = interoperability_module,
        .linkage = .dynamic,
    });
    b.installArtifact(libbiozig_shared);

    const libbiozig_static = b.addLibrary(.{
        .name = "biozig",
        .root_module = interoperability_module,
        .linkage = .static,
    });
    b.installArtifact(libbiozig_static);

    const population_lib = b.addLibrary(.{
        .name = "biozig-population",
        .root_module = population_module,
        .linkage = .static,
    });
    b.installArtifact(population_lib);


    cli_module.addImport("population", population_module);
    cli_module.addImport("reporting", reporting_module);
    cli_module.addImport("net", net_module);

    const cli_exe = b.addExecutable(.{
        .name = "biozig",
        .root_module = cli_module,
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });
    b.installArtifact(cli_exe);

    const cli_args_module = b.createModule(.{
        .root_source_file = b.path("cli/args.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cli_tests = b.addTest(.{
        .root_module = cli_args_module,
    });
    const run_cli_tests = b.addRunArtifact(cli_tests);
    test_step.dependOn(&run_cli_tests.step);

    const cli_main_tests = b.addTest(.{
        .root_module = cli_module,
    });
    const run_cli_main_tests = b.addRunArtifact(cli_main_tests);
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "biozig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("interoperability/c_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    // lib.linkLibC();
    lib.root_module.addImport("core", core_module);
    lib.root_module.addImport("molecular", molecular_module);
    lib.root_module.addImport("algorithms", algorithms_module);
    lib.root_module.addImport("analytics", analytics_module);
    lib.root_module.addImport("ingestion", ingestion_module);
    lib.root_module.addImport("structural", structural_module);
    lib.root_module.addImport("cellular", cellular_module);
    lib.root_module.addImport("systems", systems_module);
    lib.root_module.addImport("visualization", visualization_module);
    lib.root_module.addImport("population", population_module);
    lib.root_module.addImport("net", net_module);
    b.installArtifact(lib);

    test_step.dependOn(&run_cli_main_tests.step);
}
