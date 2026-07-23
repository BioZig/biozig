const std = @import("std");
const dp = @import("core").simd.dp;
const profile = @import("profile.zig");

const matrices = @import("matrices.zig");
pub const SubstitutionMatrix = matrices.SubstitutionMatrix;
pub const BuiltinMatrix = matrices.BuiltinMatrix;

pub const NWRecurrence = struct {
    match_score: i32,
    mismatch_score: i32,
    gap_open: i32,
    gap_extend: i32,
    sub_matrix: ?*const SubstitutionMatrix = null,

    const Self = @This();

    pub fn cellSizeBytes() usize {
        return @sizeOf(i32);
    }

    pub fn initRowZero(self: Self, curr_row: []i32, b_seq: anytype) void {
        _ = b_seq;
        curr_row[0] = 0;
        if (curr_row.len > 1) {
            curr_row[1] = self.gap_open;
            for (2..curr_row.len) |j| {
                curr_row[j] = curr_row[j - 1] + self.gap_extend;
            }
        }
    }

    inline fn getScore(self: Self, a: u8, b: u8) i32 {
        if (self.sub_matrix) |sm| {
            return sm.get(a, b);
        }
        return if (a == b) self.match_score else self.mismatch_score;
    }

    pub fn fillForwardRow(self: Self, a_char: anytype, b_seq: anytype, prev_row: []i32, curr_row: []i32) void {
        curr_row[0] = prev_row[0] + if (prev_row[0] == 0) self.gap_open else self.gap_extend;

        for (1..b_seq.len + 1) |j| {
            const b_char = b_seq[j - 1];
            const score = self.getScore(a_char, b_char);
            
            const match = prev_row[j - 1] + score;
            const delete = prev_row[j] + self.gap_extend;
            const insert = curr_row[j - 1] + self.gap_extend;
            
            var max_score = match;
            if (delete > max_score) max_score = delete;
            if (insert > max_score) max_score = insert;
            
            curr_row[j] = max_score;
        }
    }

    pub fn fillBlock(self: Self, a_seq: anytype, b_seq: anytype, start_row: []i32, block_matrix: []i32) void {
        const cols = b_seq.len + 1;
        @memcpy(block_matrix[0..cols], start_row);
        
        for (1..a_seq.len + 1) |i| {
            const prev_row = block_matrix[(i - 1) * cols .. i * cols];
            const curr_row = block_matrix[i * cols .. (i + 1) * cols];
            self.fillForwardRow(a_seq[i - 1], b_seq, prev_row, curr_row);
        }
    }

    pub fn tracebackBlock(
        self: Self, 
        a_seq: anytype, 
        b_seq: anytype, 
        block_matrix: []i32, 
        start_row_idx: usize, 
        start_col_idx: usize, 
        align_a: *std.ArrayListUnmanaged(u8), 
        align_b: *std.ArrayListUnmanaged(u8),
        allocator: std.mem.Allocator
    ) struct { row: usize, col: usize } {
        const cols = b_seq.len + 1;
        var i = start_row_idx;
        var j = start_col_idx;

        while (i > 0) {
            if (j > 0) {
                const curr_idx = i * cols + j;
                const diag_idx = (i - 1) * cols + (j - 1);
                const up_idx = (i - 1) * cols + j;
                const left_idx = i * cols + (j - 1);

                const curr_score = block_matrix[curr_idx];
                const match_score = block_matrix[diag_idx] + self.getScore(a_seq[i - 1], b_seq[j - 1]);

                if (curr_score == match_score) {
                    align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                    align_b.append(allocator, b_seq[j - 1]) catch unreachable;
                    i -= 1;
                    j -= 1;
                } else if (curr_score == block_matrix[up_idx] + self.gap_extend or curr_score == block_matrix[up_idx] + self.gap_open) {
                    align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                    align_b.append(allocator, '-') catch unreachable;
                    i -= 1;
                } else if (curr_score == block_matrix[left_idx] + self.gap_extend or curr_score == block_matrix[left_idx] + self.gap_open) {
                    align_a.append(allocator, '-') catch unreachable;
                    align_b.append(allocator, b_seq[j - 1]) catch unreachable;
                    j -= 1;
                } else {
                    align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                    align_b.append(allocator, b_seq[j - 1]) catch unreachable;
                    i -= 1;
                    j -= 1;
                }
            } else {
                align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                align_b.append(allocator, '-') catch unreachable;
                i -= 1;
            }
        }
        return .{ .row = i, .col = j };
    }
};

pub const ProfileRecurrence = struct {
    profile_a: *const profile.Profile,
    profile_b: *const profile.Profile,
    gap_open: i32,
    gap_extend: i32,
    sub_matrix: ?*const SubstitutionMatrix,
    match_score: i32 = 5,
    mismatch_score: i32 = -4,
    divergence_scale: f32 = 1.0,
    
    pub const isLocal = false;

    const Self = @This();

    pub fn cellSizeBytes() usize {
        return @sizeOf(i32);
    }

    pub fn initRowZero(self: Self, curr_row: []i32, b_seq: anytype) void {
        _ = b_seq;
        curr_row[0] = 0;
        if (curr_row.len > 1) {
            curr_row[1] = self.gap_open;
            for (2..curr_row.len) |j| {
                curr_row[j] = curr_row[j - 1] + self.gap_extend;
            }
        }
    }

    inline fn getScore(self: Self, col_a: usize, col_b: usize) i32 {
        var expected_score: f32 = 0.0;
        for (0..23) |a| {
            const fa = self.profile_a.frequencies[col_a * 24 + a];
            if (fa == 0.0) continue;
            for (0..23) |b| {
                const fb = self.profile_b.frequencies[col_b * 24 + b];
                if (fb == 0.0) continue;
                
                var pair_score: f32 = 0.0;
                if (self.sub_matrix) |sm| {
                    const char_a = @as(u8, @intCast(a)) + 'A';
                    const char_b = @as(u8, @intCast(b)) + 'A';
                    pair_score = @as(f32, @floatFromInt(sm.get(char_a, char_b)));
                } else {
                    pair_score = if (a == b) @as(f32, @floatFromInt(self.match_score)) else @as(f32, @floatFromInt(self.mismatch_score));
                }
                expected_score += fa * fb * pair_score;
            }
        }
        expected_score *= self.divergence_scale;
        return @as(i32, @intFromFloat(@round(expected_score)));
    }

    pub fn fillForwardRow(self: Self, a_char: anytype, b_seq: anytype, prev_row: []i32, curr_row: []i32) void {
        const col_a = @as(usize, @intCast(a_char));
        curr_row[0] = prev_row[0] + if (prev_row[0] == 0) self.gap_open else self.gap_extend;

        for (1..b_seq.len + 1) |j| {
            const col_b = @as(usize, @intCast(b_seq[j - 1]));
            const score = self.getScore(col_a, col_b);
            
            const match = prev_row[j - 1] + score;
            const delete = prev_row[j] + self.gap_extend;
            const insert = curr_row[j - 1] + self.gap_extend;
            
            var max_score = match;
            if (delete > max_score) max_score = delete;
            if (insert > max_score) max_score = insert;
            
            curr_row[j] = max_score;
        }
    }

    pub fn fillBlock(self: Self, a_seq: anytype, b_seq: anytype, start_row: []i32, block_matrix: []i32) void {
        const cols = b_seq.len + 1;
        @memcpy(block_matrix[0..cols], start_row);
        
        for (1..a_seq.len + 1) |i| {
            const prev_row = block_matrix[(i - 1) * cols .. i * cols];
            const curr_row = block_matrix[i * cols .. (i + 1) * cols];
            self.fillForwardRow(a_seq[i - 1], b_seq, prev_row, curr_row);
        }
    }

    pub fn tracebackBlock(
        self: Self, 
        a_seq: anytype, 
        b_seq: anytype, 
        block_matrix: []i32, 
        start_row_idx: usize, 
        start_col_idx: usize, 
        align_a: *std.ArrayListUnmanaged(u8), 
        align_b: *std.ArrayListUnmanaged(u8),
        allocator: std.mem.Allocator
    ) struct { row: usize, col: usize } {
        const cols = b_seq.len + 1;
        var i = start_row_idx;
        var j = start_col_idx;

        while (i > 0) {
            if (j > 0) {
                const curr_idx = i * cols + j;
                const diag_idx = (i - 1) * cols + (j - 1);
                const up_idx = (i - 1) * cols + j;
                const left_idx = i * cols + (j - 1);

                const curr_score = block_matrix[curr_idx];
                const col_a = @as(usize, @intCast(a_seq[i - 1]));
                const col_b = @as(usize, @intCast(b_seq[j - 1]));
                const match_score = block_matrix[diag_idx] + self.getScore(col_a, col_b);

                if (curr_score == match_score) {
                    align_a.append(allocator, 'M') catch unreachable;
                    align_b.append(allocator, 'M') catch unreachable;
                    i -= 1;
                    j -= 1;
                } else if (curr_score == block_matrix[up_idx] + self.gap_extend or curr_score == block_matrix[up_idx] + self.gap_open) {
                    align_a.append(allocator, 'D') catch unreachable;
                    align_b.append(allocator, '-') catch unreachable;
                    i -= 1;
                } else if (curr_score == block_matrix[left_idx] + self.gap_extend or curr_score == block_matrix[left_idx] + self.gap_open) {
                    align_a.append(allocator, '-') catch unreachable;
                    align_b.append(allocator, 'I') catch unreachable;
                    j -= 1;
                } else {
                    align_a.append(allocator, 'M') catch unreachable;
                    align_b.append(allocator, 'M') catch unreachable;
                    i -= 1;
                    j -= 1;
                }
            } else {
                align_a.append(allocator, 'D') catch unreachable;
                align_b.append(allocator, '-') catch unreachable;
                i -= 1;
            }
        }
        return .{ .row = i, .col = j };
    }
};

pub const SWRecurrence = struct {
    match_score: i32,
    mismatch_score: i32,
    gap_open: i32,
    gap_extend: i32,
    sub_matrix: ?*const SubstitutionMatrix = null,
    
    max_score_ptr: *i32,
    max_row_ptr: *usize,
    max_col_ptr: *usize,

    const Self = @This();
    
    pub const isLocal = true;

    pub fn cellSizeBytes() usize { return @sizeOf(i32); }

    pub fn initRowZero(self: Self, curr_row: []i32, b_seq: anytype) void {
        _ = self;
        _ = b_seq;
        @memset(curr_row, 0);
    }
    
    inline fn getScore(self: Self, a: u8, b: u8) i32 {
        if (self.sub_matrix) |sm| return sm.get(a, b);
        return if (a == b) self.match_score else self.mismatch_score;
    }

    pub fn fillForwardRow(self: Self, a_char: anytype, b_seq: anytype, prev_row: []i32, curr_row: []i32) void {
        curr_row[0] = 0;
        for (1..b_seq.len + 1) |j| {
            const b_char = b_seq[j - 1];
            const score = self.getScore(a_char, b_char);
            
            const match = prev_row[j - 1] + score;
            const delete = prev_row[j] + self.gap_extend; // Simplified gap model for basic SW
            const insert = curr_row[j - 1] + self.gap_extend;
            
            var max_score = @max(match, 0);
            max_score = @max(delete, max_score);
            max_score = @max(insert, max_score);
            
            curr_row[j] = max_score;
        }
    }
    
    pub fn updateGlobalMax(self: Self, curr_row: []i32, row_idx: usize) void {
        for (0..curr_row.len) |col_idx| {
            if (curr_row[col_idx] > self.max_score_ptr.*) {
                self.max_score_ptr.* = curr_row[col_idx];
                self.max_row_ptr.* = row_idx;
                self.max_col_ptr.* = col_idx;
            }
        }
    }

    pub fn getTracebackStart(self: Self) ?struct { row: usize, col: usize } {
        return .{ .row = self.max_row_ptr.*, .col = self.max_col_ptr.* };
    }
    
    pub fn fillBlock(self: Self, a_seq: anytype, b_seq: anytype, start_row: []i32, block_matrix: []i32) void {
        const cols = b_seq.len + 1;
        @memcpy(block_matrix[0..cols], start_row);
        for (1..a_seq.len + 1) |i| {
            const prev_row = block_matrix[(i - 1) * cols .. i * cols];
            const curr_row = block_matrix[i * cols .. (i + 1) * cols];
            self.fillForwardRow(a_seq[i - 1], b_seq, prev_row, curr_row);
        }
    }

    pub fn tracebackBlock(
        self: Self, 
        a_seq: anytype, 
        b_seq: anytype, 
        block_matrix: []i32, 
        start_row_idx: usize, 
        start_col_idx: usize, 
        align_a: *std.ArrayListUnmanaged(u8), 
        align_b: *std.ArrayListUnmanaged(u8),
        allocator: std.mem.Allocator
    ) struct { row: usize, col: usize } {
        const cols = b_seq.len + 1;
        var i = start_row_idx;
        var j = start_col_idx;

        while (i > 0) {
            const curr_idx = i * cols + j;
            const curr_score = block_matrix[curr_idx];
            if (curr_score == 0) {
                return .{ .row = i, .col = j };
            }
            
            if (j > 0) {
                const diag_idx = (i - 1) * cols + (j - 1);
                const up_idx = (i - 1) * cols + j;
                const left_idx = i * cols + (j - 1);
                
                const match_score = block_matrix[diag_idx] + self.getScore(a_seq[i - 1], b_seq[j - 1]);
                if (curr_score == match_score) {
                    align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                    align_b.append(allocator, b_seq[j - 1]) catch unreachable;
                    i -= 1; j -= 1;
                } else if (curr_score == block_matrix[up_idx] + self.gap_extend) {
                    align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                    align_b.append(allocator, '-') catch unreachable;
                    i -= 1;
                } else if (curr_score == block_matrix[left_idx] + self.gap_extend) {
                    align_a.append(allocator, '-') catch unreachable;
                    align_b.append(allocator, b_seq[j - 1]) catch unreachable;
                    j -= 1;
                } else {
                    align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                    align_b.append(allocator, b_seq[j - 1]) catch unreachable;
                    i -= 1; j -= 1;
                }
            } else {
                align_a.append(allocator, a_seq[i - 1]) catch unreachable;
                align_b.append(allocator, '-') catch unreachable;
                i -= 1;
            }
        }
        return .{ .row = i, .col = j };
    }
};

pub const AlignmentResult = struct {
    score: i32,
    aligned_a: []const u8,
    aligned_b: []const u8,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.aligned_a);
        allocator.free(self.aligned_b);
    }
};

pub fn globalAlignment(allocator: std.mem.Allocator, seq_a: anytype, seq_b: anytype, opts: anytype) !AlignmentResult {
    const srf = @import("core").scheduling.srf;
    const rec = NWRecurrence{
        .match_score = if (@hasField(@TypeOf(opts), "match_score")) opts.match_score else 2,
        .mismatch_score = if (@hasField(@TypeOf(opts), "mismatch_penalty")) opts.mismatch_penalty else -1,
        .gap_open = if (@hasField(@TypeOf(opts), "gap_penalty")) opts.gap_penalty else -2,
        .gap_extend = if (@hasField(@TypeOf(opts), "gap_penalty")) opts.gap_penalty else -2,
    };
    const dna = @import("molecular").dna;
    var string_a: []const u8 = undefined;
    var string_b: []const u8 = undefined;
    var a_alloc = false;
    var b_alloc = false;
    
    if (@TypeOf(seq_a) == dna.DNA2View) {
        var buf = try allocator.alloc(u8, seq_a.len);
        for (0..seq_a.len) |i| buf[i] = @tagName(seq_a.get(i))[0];
        string_a = buf;
        a_alloc = true;
    } else if (@typeInfo(@TypeOf(seq_a)) == .pointer) {
        string_a = seq_a;
    } else {
        @compileError("Unsupported seq_a type");
    }
    
    if (@TypeOf(seq_b) == dna.DNA2View) {
        var buf = try allocator.alloc(u8, seq_b.len);
        for (0..seq_b.len) |i| buf[i] = @tagName(seq_b.get(i))[0];
        string_b = buf;
        b_alloc = true;
    } else if (@typeInfo(@TypeOf(seq_b)) == .pointer) {
        string_b = seq_b;
    } else {
        @compileError("Unsupported seq_b type");
    }
    
    defer if (a_alloc) allocator.free(string_a);
    defer if (b_alloc) allocator.free(string_b);

    var scheduler = srf.SRFScheduler(NWRecurrence).init(allocator, rec, 1024 * 1024 * 64);
    const dp_res = try scheduler.execute([]const u8, string_a, string_b);
    return AlignmentResult{
        .score = dp_res.score,
        .aligned_a = dp_res.align_a,
        .aligned_b = dp_res.align_b,
    };
}

pub const globalAlignmentString = globalAlignment;

pub fn localAlignment(allocator: std.mem.Allocator, seq_a: anytype, seq_b: anytype, opts: anytype) !AlignmentResult {
    const srf = @import("core").scheduling.srf;
    var max_score: i32 = 0;
    var max_row: usize = 0;
    var max_col: usize = 0;

    const rec = SWRecurrence{
        .match_score = if (@hasField(@TypeOf(opts), "match_score")) opts.match_score else 2,
        .mismatch_score = if (@hasField(@TypeOf(opts), "mismatch_penalty")) opts.mismatch_penalty else -1,
        .gap_open = if (@hasField(@TypeOf(opts), "gap_penalty")) opts.gap_penalty else -2,
        .gap_extend = if (@hasField(@TypeOf(opts), "gap_penalty")) opts.gap_penalty else -2,
        .max_score_ptr = &max_score,
        .max_row_ptr = &max_row,
        .max_col_ptr = &max_col,
    };
    const dna = @import("molecular").dna;
    var string_a: []const u8 = undefined;
    var string_b: []const u8 = undefined;
    var a_alloc = false;
    var b_alloc = false;
    
    if (@TypeOf(seq_a) == dna.DNA2View) {
        var buf = try allocator.alloc(u8, seq_a.len);
        for (0..seq_a.len) |i| buf[i] = @tagName(seq_a.get(i))[0];
        string_a = buf;
        a_alloc = true;
    } else if (@typeInfo(@TypeOf(seq_a)) == .pointer) {
        string_a = seq_a;
    } else {
        @compileError("Unsupported seq_a type");
    }
    
    if (@TypeOf(seq_b) == dna.DNA2View) {
        var buf = try allocator.alloc(u8, seq_b.len);
        for (0..seq_b.len) |i| buf[i] = @tagName(seq_b.get(i))[0];
        string_b = buf;
        b_alloc = true;
    } else if (@typeInfo(@TypeOf(seq_b)) == .pointer) {
        string_b = seq_b;
    } else {
        @compileError("Unsupported seq_b type");
    }
    
    defer if (a_alloc) allocator.free(string_a);
    defer if (b_alloc) allocator.free(string_b);

    var scheduler = srf.SRFScheduler(SWRecurrence).init(allocator, rec, 1024 * 1024 * 64);
    const dp_res = try scheduler.execute([]const u8, string_a, string_b);
    return AlignmentResult{
        .score = dp_res.score,
        .aligned_a = dp_res.align_a,
        .aligned_b = dp_res.align_b,
    };
}
