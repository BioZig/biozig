const std = @import("std");

extern fn biozig_context_create() c_int;
extern fn biozig_context_destroy() c_int;

pub const CBiozigParseResult = extern struct {
    num_records: c_int,
    error_code: c_int,
};

extern fn biozig_parse_fasta(file_path: [*c]const u8) callconv(.c) CBiozigParseResult;

test "biozig_parse_fasta_not_found" {
    _ = @import("c_api");
    _ = biozig_context_create();
    defer _ = biozig_context_destroy();
    
    const bad_path = "nonexistent_file.fasta\x00";
    const res = biozig_parse_fasta(bad_path.ptr);
    try std.testing.expect(res.error_code != 0);
    try std.testing.expectEqual(@as(c_int, 0), res.num_records);
}
