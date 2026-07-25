const std = @import("std");
const algorithms = @import("algorithms");
const alignment = algorithms.molecular.alignment;
const srf = @import("core").scheduling.srf;
const matrices = algorithms.molecular.matrices;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const seq1 = "AAAAAMQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGGZZZZZZZ";
    const seq2 = "YYYYYYYYYYMQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGGWWWW";
    // The shared domain is Ubiquitin: MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG

    var max_score: i16 = 0;
    var max_row: usize = 0;
    var max_col: usize = 0;

    const sub = matrices.SubstitutionMatrix.init(.BLOSUM62);
    const sw_rec = alignment.SWRecurrence{
        .match_score = 5,
        .mismatch_score = -4,
        .gap_open = -10,
        .gap_extend = -2,
        .sub_matrix = &sub,
        .max_score_ptr = &max_score,
        .max_row_ptr = &max_row,
        .max_col_ptr = &max_col,
    };

    var scheduler = srf.SRFScheduler(alignment.SWRecurrence).init(
        alloc,
        sw_rec,
        100 * 1024 * 1024 // 100MB
    );

    const res = try scheduler.execute([]const u8, seq1, seq2);

    std.debug.print("SW Domain Isolation Result:\n", .{});
    std.debug.print("Max Score: {d}\n", .{max_score});
    std.debug.print("Seq1: {s}\n", .{res.align_a});
    std.debug.print("Seq2: {s}\n", .{res.align_b});
}
