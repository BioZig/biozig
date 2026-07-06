const std = @import("std");
const atom_mod = @import("../atom/atom.zig");
const geom = @import("../geometry/geometry.zig");
const Atom = atom_mod.Atom;
const Element = atom_mod.Element;
const Vec3 = geom.Vec3;

/// Configuration options for the SASA calculation.
pub const SasaConfig = struct {
    /// Probe radius representing the solvent molecule (typically 1.4 A for water).
    probe_radius: f64 = 1.4,
    /// Number of points used to sample the sphere of each atom (typically 96 to 256 for a good balance of speed and precision).
    num_points: usize = 96,
};

/// Represents the calculated accessibility metrics for an individual atom.
pub const AtomAccessibility = struct {
    atom_id: usize,
    sasa: f64,
    ratio: f64, // Fraction of the surface area that is accessible [0.0, 1.0]
};

/// Retrieves the Bondi Van der Waals (VdW) radius for a given chemical element.
/// References: Bondi, A. (1964). "Van der Waals Volumes and Radii". J. Phys. Chem. 68 (3): 441-451.
pub fn getVdwRadius(el: Element) f64 {
    return switch (el) {
        .H => 1.20,
        .C => 1.70,
        .N => 1.55,
        .O => 1.52,
        .P => 1.80,
        .S => 1.80,
        .generic => |bytes| {
            const b0 = bytes[0];
            const b1 = bytes[1];
            if (b1 == 0) {
                switch (b0) {
                    'F', 'f' => return 1.47,
                    'I', 'i' => return 1.98,
                    'K', 'k' => return 2.75,
                    'B', 'b' => return 1.85,
                    else => return 1.70, // Default fallback
                }
            } else {
                const char0 = std.ascii.toUpper(b0);
                const char1 = std.ascii.toUpper(b1);
                if (char0 == 'F' and char1 == 'E') return 2.00;
                if (char0 == 'M' and char1 == 'G') return 1.73;
                if (char0 == 'N' and char1 == 'A') return 2.27;
                if (char0 == 'C' and char1 == 'L') return 1.75;
                if (char0 == 'C' and char1 == 'A') return 2.31;
                if (char0 == 'Z' and char1 == 'N') return 1.39;
                if (char0 == 'C' and char1 == 'U') return 1.40;
                if (char0 == 'B' and char1 == 'R') return 1.85;
            }
            return 1.70; // Fallback to Carbon-like radius
        },
    };
}

/// Generates a coordinate on a unit sphere using the Fibonacci lattice (golden spiral).
/// This provides a highly uniform and deterministic distribution of points on a sphere.
pub fn getFibonacciSpherePoint(i: usize, n: usize) Vec3 {
    if (n == 0) return Vec3.init(0, 0, 1);
    const n_f = @as(f64, @floatFromInt(n));
    const i_f = @as(f64, @floatFromInt(i));

    // Distribute y coordinates uniformly from 1 - offset to -1 + offset
    const y = 1.0 - (2.0 * i_f + 1.0) / n_f;
    const r = @sqrt(@max(0.0, 1.0 - y * y));

    // Angle theta in radians using the golden angle
    const golden_ratio = (1.0 + 2.23606797749979) / 2.0; // (1 + sqrt(5))/2
    const golden_angle = 2.0 * std.math.pi * (1.0 - 1.0 / golden_ratio);
    const theta = i_f * golden_angle;

    const x = @cos(theta) * r;
    const z = @sin(theta) * r;

    return Vec3.init(x, y, z);
}

/// Calculates the Solvent Accessible Surface Area (SASA) for each atom in a given slice.
/// Writes the results directly to the `sasa_out` slice, which must have the same length as `atoms`.
/// This implementation uses neighbor pre-filtering to optimize checks, achieving O(N * k) complexity.
pub fn calculateSasa(
    atoms: []const Atom,
    config: SasaConfig,
    sasa_out: []f64,
    allocator: std.mem.Allocator,
) !void {
    if (atoms.len != sasa_out.len) return error.SliceLengthMismatch;
    if (atoms.len == 0) return;
    if (config.num_points == 0) return error.InvalidNumPoints;

    // Precalculate the probe-inflated radius for each atom
    var radii = try allocator.alloc(f64, atoms.len);
    defer allocator.free(radii);
    for (atoms, 0..) |atom, i| {
        radii[i] = getVdwRadius(atom.element) + config.probe_radius;
    }

    // Allocate a reusable list for neighbors to minimize heap allocations per atom
    var neighbors = std.ArrayList(usize).empty;
    defer neighbors.deinit(allocator);

    for (atoms, 0..) |atom, i| {
        const r_i = radii[i];
        const pos_i = atom.pos;

        // 1. Identify all potentially overlapping neighbor atoms
        neighbors.clearRetainingCapacity();
        for (atoms, 0..) |other, j| {
            if (i == j) continue;
            const r_j = radii[j];
            const d2 = geom.distance2(pos_i, other.pos);
            const limit = r_i + r_j;
            if (d2 < limit * limit) {
                try neighbors.append(allocator, j);
            }
        }

        // 2. Sample points on the inflated sphere of atom i
        var accessible_count: usize = 0;
        var p: usize = 0;
        while (p < config.num_points) : (p += 1) {
            const direction = getFibonacciSpherePoint(p, config.num_points);
            const sphere_point = pos_i.add(direction.scale(r_i));

            // Check if this point is buried inside any of the neighbor atoms
            var is_buried = false;
            for (neighbors.items) |j| {
                const r_j = radii[j];
                const d2 = geom.distance2(sphere_point, atoms[j].pos);
                // Use a tiny epsilon to avoid floating-point boundary issues
                if (d2 < (r_j * r_j) - 1e-9) {
                    is_buried = true;
                    break;
                }
            }

            if (!is_buried) {
                accessible_count += 1;
            }
        }

        // 3. Compute surface area: 4 * pi * R^2 * (accessible / total)
        const ratio = @as(f64, @floatFromInt(accessible_count)) / @as(f64, @floatFromInt(config.num_points));
        sasa_out[i] = 4.0 * std.math.pi * r_i * r_i * ratio;
    }
}

/// Computes granular atom accessibility metrics, including both absolute SASA values and relative exposure ratios.
pub fn calculateAccessibility(
    atoms: []const Atom,
    config: SasaConfig,
    accessibility_out: []AtomAccessibility,
    allocator: std.mem.Allocator,
) !void {
    if (atoms.len != accessibility_out.len) return error.SliceLengthMismatch;
    if (atoms.len == 0) return;
    if (config.num_points == 0) return error.InvalidNumPoints;

    const sasa_buf = try allocator.alloc(f64, atoms.len);
    defer allocator.free(sasa_buf);

    try calculateSasa(atoms, config, sasa_buf, allocator);

    for (atoms, 0..) |atom, i| {
        const r = getVdwRadius(atom.element) + config.probe_radius;
        const max_area = 4.0 * std.math.pi * r * r;
        accessibility_out[i] = .{
            .atom_id = atom.id,
            .sasa = sasa_buf[i],
            .ratio = sasa_buf[i] / max_area,
        };
    }
}

test "SASA calculation for single atom" {
    const allocator = std.testing.allocator;
    const atom = try Atom.init(
        1,
        "C",
        .C,
        Vec3.init(0, 0, 0),
        1.0,
        20.0,
        null,
    );
    const atoms = [_]Atom{atom};
    var sasa_out = [_]f64{0.0};
    
    try calculateSasa(&atoms, .{}, &sasa_out, allocator);
    
    // Carbon VdW = 1.7, probe = 1.4 => radius = 3.1
    // Area = 4 * pi * 3.1 * 3.1 = 120.76282
    const expected = 4.0 * std.math.pi * 3.1 * 3.1;
    try std.testing.expectApproxEqAbs(sasa_out[0], expected, 1e-5);

    var access = [_]AtomAccessibility{undefined};
    try calculateAccessibility(&atoms, .{}, &access, allocator);
    try std.testing.expectEqual(access[0].atom_id, 1);
    try std.testing.expectApproxEqAbs(access[0].sasa, expected, 1e-5);
    try std.testing.expectApproxEqAbs(access[0].ratio, 1.0, 1e-5);
}

test "SASA calculation for two distant atoms" {
    const allocator = std.testing.allocator;
    const atom1 = try Atom.init(1, "C1", .C, Vec3.init(0, 0, 0), 1.0, 20.0, null);
    const atom2 = try Atom.init(2, "C2", .C, Vec3.init(100.0, 0, 0), 1.0, 20.0, null);
    const atoms = [_]Atom{ atom1, atom2 };
    var sasa_out = [_]f64{ 0.0, 0.0 };
    
    try calculateSasa(&atoms, .{}, &sasa_out, allocator);
    const expected = 4.0 * std.math.pi * 3.1 * 3.1;
    try std.testing.expectApproxEqAbs(sasa_out[0], expected, 1e-5);
    try std.testing.expectApproxEqAbs(sasa_out[1], expected, 1e-5);
}

test "SASA calculation for two overlapping atoms" {
    const allocator = std.testing.allocator;
    const atom1 = try Atom.init(1, "C1", .C, Vec3.init(0, 0, 0), 1.0, 20.0, null);
    // Distance between centers is 3.0 A (less than 2 * 3.1 = 6.2 A, so they overlap)
    const atom2 = try Atom.init(2, "C2", .C, Vec3.init(3.0, 0, 0), 1.0, 20.0, null);
    const atoms = [_]Atom{ atom1, atom2 };
    var sasa_out = [_]f64{ 0.0, 0.0 };
    
    try calculateSasa(&atoms, .{}, &sasa_out, allocator);
    const expected_isolated = 4.0 * std.math.pi * 3.1 * 3.1;
    // Overlapping should reduce SASA
    try std.testing.expect(sasa_out[0] < expected_isolated);
    try std.testing.expect(sasa_out[1] < expected_isolated);
    try std.testing.expect(sasa_out[0] > 0.0);
}

