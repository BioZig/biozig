pub const statistics = @import("statistics/statistics.zig");

pub const pathways = struct {
    pub const enrichment = @import("pathways/enrichment.zig");
    pub const spia = @import("pathways/spia.zig");
};

pub const matrix = struct {
    pub const factorization = @import("matrix/factorization.zig");
    pub const sparse = @import("matrix/sparse.zig");
    pub const svd = @import("matrix/svd.zig");
    pub const mds = factorization.mds;
    pub const nmf = factorization.nmf;
};

pub const sequence = struct {
    pub const metrics = @import("sequence/metrics.zig");
    pub const markov = @import("sequence/markov.zig");
    pub const kmer_stats = @import("sequence/kmer_stats.zig");
};

pub const dimensionality = struct {
    pub const pca = @import("dimensionality/pca.zig");
    pub const tsne = @import("dimensionality/tsne.zig");
    pub const umap = @import("dimensionality/umap.zig");
};

pub const clustering = struct {
    pub const kmeans = @import("clustering/kmeans.zig");
    pub const dbscan = @import("clustering/dbscan.zig");
    pub const hierarchical = @import("clustering/hierarchical.zig");
};

pub const graphml = struct {
    pub const node2vec = @import("graphml/node2vec.zig");
    pub const spectral = @import("graphml/spectral.zig");
};

test {
    _ = statistics;
    _ = pathways;
    _ = matrix;
    _ = sequence;
    _ = dimensionality;
    _ = clustering;
    _ = graphml;
}
