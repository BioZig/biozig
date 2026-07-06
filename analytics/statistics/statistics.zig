pub const descriptive = @import("descriptive.zig");
pub const correlation = @import("correlation.zig");
pub const hypothesis = @import("hypothesis.zig");
pub const distributions = @import("distributions.zig");
pub const multiple_testing = @import("multiple_testing.zig");
pub const regression = @import("regression.zig");
pub const matrix = @import("matrix.zig");
pub const biology = @import("biology.zig");
pub const math_utils = @import("math_utils.zig");
pub const survival = @import("survival.zig");
pub const dispersion = @import("dispersion.zig");

test {
    _ = descriptive;
    _ = correlation;
    _ = hypothesis;
    _ = distributions;
    _ = multiple_testing;
    _ = regression;
    _ = matrix;
    _ = biology;
    _ = math_utils;
    _ = survival;
    _ = dispersion;
}
