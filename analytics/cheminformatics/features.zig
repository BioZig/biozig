const std = @import("std");

pub const ChemFeatures = struct {
    bytes_streamed: usize,
    smiles_found: usize,
};

pub fn streamingFeatureExtractor(iterator: anytype) !ChemFeatures {
    var features = ChemFeatures{ .bytes_streamed = 0, .smiles_found = 0 };
    
    while (try iterator.nextChunk()) |chunk| {
        features.bytes_streamed += chunk.len;
        var start_idx: usize = 0;
        while (std.mem.indexOfPos(u8, chunk, start_idx, "\"canonical_smiles\"")) |idx| {
            features.smiles_found += 1;
            start_idx = idx + 18;
        }
    }
    features.bytes_streamed = iterator.bytes_read; // Precise tracking
    return features;
}
