const std = @import("std");
const geom = @import("../geometry/geometry.zig");
const Vec3 = geom.Vec3;

pub const Element = union(enum) {
    H,
    C,
    N,
    O,
    P,
    S,
    generic: [2]u8, // e.g., 'F', 'e', 'M', 'g', etc. (up to 2 chars)

    pub fn toString(self: Element, dest: *[2]u8) []const u8 {
        switch (self) {
            .H => {
                dest[0] = 'H';
                return dest[0..1];
            },
            .C => {
                dest[0] = 'C';
                return dest[0..1];
            },
            .N => {
                dest[0] = 'N';
                return dest[0..1];
            },
            .O => {
                dest[0] = 'O';
                return dest[0..1];
            },
            .P => {
                dest[0] = 'P';
                return dest[0..1];
            },
            .S => {
                dest[0] = 'S';
                return dest[0..1];
            },
            .generic => |bytes| {
                dest[0] = bytes[0];
                dest[1] = bytes[1];
                return if (bytes[1] == 0) dest[0..1] else dest[0..2];
            },
        }
    }
};

pub const Atom = struct {
    id: usize,
    pos: Vec3,
    occupancy: f64,
    b_factor: f64,
    formal_charge: ?i8 = null,
    name: [4]u8,
    name_len: u8,
    element: Element,

    pub fn init(
        id: usize,
        name: []const u8,
        element: Element,
        pos: Vec3,
        occupancy: f64,
        b_factor: f64,
        formal_charge: ?i8,
    ) !Atom {
        if (name.len > 4) return error.AtomNameTooLong;
        var result = Atom{
            .id = id,
            .name = [_]u8{0} ** 4,
            .name_len = @as(u8, @intCast(name.len)),
            .element = element,
            .pos = pos,
            .occupancy = occupancy,
            .b_factor = b_factor,
            .formal_charge = formal_charge,
        };
        for (name, 0..) |c, i| {
            result.name[i] = c;
        }
        return result;
    }

    pub fn getName(self: *const Atom) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn distance(self: *const Atom, other: Atom) f64 {
        return geom.distance(self.pos, other.pos);
    }

    pub fn transform(self: *Atom, rotation: [3][3]f64, translation: Vec3) void {
        const p = self.pos;
        self.pos = Vec3.init(
            rotation[0][0] * p.x + rotation[0][1] * p.y + rotation[0][2] * p.z + translation.x,
            rotation[1][0] * p.x + rotation[1][1] * p.y + rotation[1][2] * p.z + translation.y,
            rotation[2][0] * p.x + rotation[2][1] * p.y + rotation[2][2] * p.z + translation.z,
        );
    }

    pub fn equals(self: *const Atom, other: Atom) bool {
        if (self.id != other.id) return false;
        if (self.name_len != other.name_len) return false;
        if (!std.mem.eql(u8, self.getName(), other.getName())) return false;
        if (self.occupancy != other.occupancy or self.b_factor != other.b_factor or self.formal_charge != other.formal_charge) return false;
        if (self.pos.x != other.pos.x or self.pos.y != other.pos.y or self.pos.z != other.pos.z) return false;

        // Element comparison
        const self_tag = std.meta.activeTag(self.element);
        const other_tag = std.meta.activeTag(other.element);
        if (self_tag != other_tag) return false;
        if (self_tag == .generic) {
            return std.mem.eql(u8, &self.element.generic, &other.element.generic);
        }
        return true;
    }

    pub fn hash(self: *const Atom) u64 {
        const XxHash64 = @import("core").hashing.XxHash64;
        var hash_val: u64 = 5381;

        var id_bytes: [@sizeOf(usize)]u8 = undefined;
        std.mem.writeInt(usize, &id_bytes, self.id, .little);
        hash_val = XxHash64.hash(&id_bytes, hash_val);

        var pos_bytes: [@sizeOf(f64) * 3]u8 = undefined;
        std.mem.writeInt(u64, pos_bytes[0..8], @bitCast(self.pos.x), .little);
        std.mem.writeInt(u64, pos_bytes[8..16], @bitCast(self.pos.y), .little);
        std.mem.writeInt(u64, pos_bytes[16..24], @bitCast(self.pos.z), .little);
        hash_val = XxHash64.hash(&pos_bytes, hash_val);

        return hash_val;
    }

    pub fn serialize(self: *const Atom, writer: anytype) !void {
        const serializeBinary = @import("core").serialization.serialize;
        try serializeBinary(writer, self.id);
        try serializeBinary(writer, self.name);
        try serializeBinary(writer, @as(u8, self.name_len));

        const element_tag = @as(u8, @intFromEnum(std.meta.activeTag(self.element)));
        try serializeBinary(writer, element_tag);
        if (std.meta.activeTag(self.element) == .generic) {
            try serializeBinary(writer, self.element.generic);
        }

        try serializeBinary(writer, self.pos.x);
        try serializeBinary(writer, self.pos.y);
        try serializeBinary(writer, self.pos.z);
        try serializeBinary(writer, self.occupancy);
        try serializeBinary(writer, self.b_factor);
        try serializeBinary(writer, self.formal_charge);
    }

    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Atom {
        const deserializeBinary = @import("core").serialization.deserialize;
        const id = try deserializeBinary(reader, usize, allocator);
        const name = try deserializeBinary(reader, [4]u8, allocator);
        const name_len_u8 = try deserializeBinary(reader, u8, allocator);
        const name_len = @as(u3, @truncate(name_len_u8));

        const element_tag_val = try deserializeBinary(reader, u8, allocator);
        const ElementTag = std.meta.Tag(Element);
        const element_tag = @as(ElementTag, @enumFromInt(element_tag_val));

        const element = switch (element_tag) {
            .H => Element.H,
            .C => Element.C,
            .N => Element.N,
            .O => Element.O,
            .P => Element.P,
            .S => Element.S,
            .generic => Element{ .generic = try deserializeBinary(reader, [2]u8, allocator) },
        };

        const x = try deserializeBinary(reader, f64, allocator);
        const y = try deserializeBinary(reader, f64, allocator);
        const z = try deserializeBinary(reader, f64, allocator);
        const occupancy = try deserializeBinary(reader, f64, allocator);
        const b_factor = try deserializeBinary(reader, f64, allocator);
        const formal_charge = try deserializeBinary(reader, ?i8, allocator);

        return Atom{
            .id = id,
            .name = name,
            .name_len = name_len,
            .element = element,
            .pos = Vec3.init(x, y, z),
            .occupancy = occupancy,
            .b_factor = b_factor,
            .formal_charge = formal_charge,
        };
    }
};
