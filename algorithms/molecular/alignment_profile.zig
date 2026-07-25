const std = @import("std");

pub const ColumnProfile = struct {
    freqs: [5]f32,
};

pub const ProfileRecurrence = struct {
    gap_open: i32,
    gap_extend: i32,

    pub const Cell = struct {
        score: i32,
        direction: u8,
    };

    pub fn cellSizeBytes() usize {
        return @sizeOf(Cell);
    }

    pub fn fillForwardRow(self: *const ProfileRecurrence, current_row: []u8, prev_row: []const u8, seq_a: []const u8, char_b: u8, start_col: usize) void {
        _ = self;
        _ = current_row;
        _ = prev_row;
        _ = seq_a;
        _ = char_b;
        _ = start_col;
        @panic("ProfileRecurrence forward pass to be implemented mathematically.");
    }

    pub fn fillBlock(self: *const ProfileRecurrence, matrix: []u8, width: usize, height: usize, seq_a_block: []const u8, seq_b_block: []const u8) void {
        _ = self;
        _ = matrix;
        _ = width;
        _ = height;
        _ = seq_a_block;
        _ = seq_b_block;
        @panic("ProfileRecurrence block pass to be implemented mathematically.");
    }

    pub fn tracebackBlock(self: *const ProfileRecurrence, matrix: []const u8, width: usize, height: usize, start_r: usize, start_c: usize) struct { r: usize, c: usize } {
        _ = self;
        _ = matrix;
        _ = width;
        _ = height;
        _ = start_r;
        _ = start_c;
        @panic("ProfileRecurrence traceback to be implemented mathematically.");
    }
};
