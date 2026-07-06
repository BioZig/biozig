const std = @import("std");
const structural = @import("structural");
const ingestion = @import("ingestion");
const core = @import("core");
const c_api = @import("c_api.zig");

// --- Core Structural Wrappers ---

pub const CBiozigAtom = opaque {};
export fn biozig_structural_atom_create() callconv(.c) ?*CBiozigAtom {
    return null;
}

pub const CBiozigAssembly = opaque {};
export fn biozig_structural_assembly_create() callconv(.c) ?*CBiozigAssembly {
    return null;
}

pub const CBiozigContacts = opaque {};
export fn biozig_structural_contacts_create() callconv(.c) ?*CBiozigContacts {
    return null;
}

pub const CBiozigResidue = opaque {};
export fn biozig_structural_residue_create() callconv(.c) ?*CBiozigResidue {
    return null;
}

pub const CBiozigChain = opaque {};
export fn biozig_structural_chain_create() callconv(.c) ?*CBiozigChain {
    return null;
}

pub const CBiozigPockets = opaque {};
export fn biozig_structural_pockets_create() callconv(.c) ?*CBiozigPockets {
    return null;
}

pub const CBiozigDocking = opaque {};
export fn biozig_structural_docking_create() callconv(.c) ?*CBiozigDocking {
    return null;
}

pub const CBiozigModel = opaque {};
export fn biozig_structural_model_create() callconv(.c) ?*CBiozigModel {
    return null;
}

pub const CBiozigSurfaces = opaque {};
export fn biozig_structural_surfaces_create() callconv(.c) ?*CBiozigSurfaces {
    return null;
}

pub const CBiozigGeometryVec3 = extern struct {
    x: f64,
    y: f64,
    z: f64,
};

export fn biozig_structural_geometry_distance(a: CBiozigGeometryVec3, b: CBiozigGeometryVec3) callconv(.c) f64 {
    const va = structural.geometry.Vec3.init(a.x, a.y, a.z);
    const vb = structural.geometry.Vec3.init(b.x, b.y, b.z);
    return structural.geometry.distance(va, vb);
}

// --- Ingestion Structural Parsers Wrappers ---

pub const CBiozigParseResult = extern struct {
    num_items: usize,
    data: ?*anyopaque,
};

export fn biozig_ingestion_structural_parse_pdb(filepath: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_items = 0, .data = null };
    const arena_ptr = c_api.c_arena orelse return res;
    const alloc = arena_ptr.allocator();

    const path = std.mem.span(filepath);
    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return res;
    defer reader.deinit();

    const coords = ingestion.structural.pdb.parsePdbCoords(alloc, reader.data) catch return res;
    res.num_items = coords.len;
    res.data = @ptrCast(coords.ptr);
    return res;
}

export fn biozig_ingestion_structural_parse_mmcif(filepath: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_items = 0, .data = null };
    const arena_ptr = c_api.c_arena orelse return res;
    const alloc = arena_ptr.allocator();

    const path = std.mem.span(filepath);
    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return res;
    defer reader.deinit();

    res.num_items = reader.data.len;
    return res;
}

export fn biozig_ingestion_structural_parse_pqr(filepath: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_items = 0, .data = null };
    const arena_ptr = c_api.c_arena orelse return res;
    const alloc = arena_ptr.allocator();

    const path = std.mem.span(filepath);
    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return res;
    defer reader.deinit();

    res.num_items = reader.data.len;
    return res;
}

export fn biozig_ingestion_structural_parse_mol2(filepath: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_items = 0, .data = null };
    const arena_ptr = c_api.c_arena orelse return res;
    const alloc = arena_ptr.allocator();

    const path = std.mem.span(filepath);
    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return res;
    defer reader.deinit();

    res.num_items = reader.data.len;
    return res;
}

export fn biozig_ingestion_structural_parse_sdf(filepath: [*c]const u8) callconv(.c) CBiozigParseResult {
    var res = CBiozigParseResult{ .num_items = 0, .data = null };
    const arena_ptr = c_api.c_arena orelse return res;
    const alloc = arena_ptr.allocator();

    const path = std.mem.span(filepath);
    var reader = core.io.mmap.MMapReader.init(alloc, path) catch return res;
    defer reader.deinit();

    res.num_items = reader.data.len;
    return res;
}
