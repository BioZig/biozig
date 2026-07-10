# Analytics Layer

## Purpose
The Analytics layer provides mathematically rigorous, highly stable statistical routines required by modern bioinformatics. It avoids naive numerical formulations in favor of robust methods, operating independently of the biological context.

## Directory Layout
- `statistics/`: Core module containing all implementations.
  - `descriptive.zig`: Central tendency, dispersion, and quartiles.
  - `correlation.zig`: Covariance, Pearson, Spearman, and Kendall Tau.
  - `hypothesis.zig`: Parameter tests (T-tests, Fisher Exact, Mann-Whitney U).
  - `multiple_testing.zig`: FDR corrections (Bonferroni, Holm, Benjamini-Hochberg).
  - `distributions.zig`: Normal, Poisson, Binomial, Negative Binomial, Hypergeometric, Uniform.
  - `regression.zig`: Simple and multiple linear regression.
  - `matrix.zig`: Covariance/Correlation matrices and Normalization (Z-score, MinMax).
  - `biology.zig`: Standard biology metrics (CPM, TPM, RPKM, log2p1).
  - `math_utils.zig`: Complex functions (erf, lgamma, continued fractions).

## Public Types
- `statistics.CorrelationResult`
- `statistics.TestResult`
- `statistics.LinearRegressionResult`
- `statistics.distributions.Sampler`

## Public APIs
- `statistics.descriptive.weightedMean()`
- `statistics.correlation.pearson()`
- `statistics.hypothesis.fisherExactTest()`
- `statistics.multiple_testing.benjaminiHochberg()`
- `statistics.regression.multipleLinearRegression()`
- `statistics.biology.tpm()`

## Serialization Format
The analytics layer deals primarily with raw mathematical transformations rather than persistent data structures; therefore, it does not define native serialization formats beyond the primitive `f64` values it returns.

## Memory Model
Routines process `[]const f64` slices. When ranking or sorting is required (e.g., Spearman, Benjamini-Hochberg), an explicit `allocator: std.mem.Allocator` is required to instantiate intermediate arrays. All allocations are tightly scoped.

## Determinism Guarantees
- All random sampling (e.g., `Poisson.sample`) requires a `Sampler` instantiated with an explicit seed. 
- Statistical ties (e.g., in rank correlation) assign exact averaged ranks rather than arbitrary sorts.

## Example Usage
```zig
const std = @import("std");
const stats = @import("biozig").analytics.statistics;

const x = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
const y = [_]f64{ 2.0, 4.0, 5.0, 4.0, 5.0 };

const res = try stats.regression.simpleLinearRegression(&x, &y, std.testing.allocator);
defer std.testing.allocator.free(res.residuals);

std.debug.print("Slope: {d}\n", .{res.slope});
```

## Limitations
- Multiple linear regression currently utilizes basic Gauss-Jordan elimination, which is suitable for small-to-medium matrices but not enterprise-scale OLS.
- Missing values (`NaN`) are not implicitly masked or filtered; inputs must be pre-sanitized.
