//! Extremely simplified subset of tsv
//! Assumes that the first field is the Uuid key.

const std = @import("std");
const testing = std.testing;
const Uuid = @import("uuid.zig").Uuid;
const Key = @import("db.zig").Key;
const UuidType = @import("uuid.zig").UuidType;
const db = @import("db.zig");
const log = @import("logger.zig");

const LINE_BUF_LEN = 4096;

pub const TsvError = error{
    EnumNotFound,
    MissingField,
    ParsedTooManyFields,
    WrongTypeParsed,
    InvalidUuid,
};

fn parsePrimitive(comptime ty: type, input: []const u8, allocator: std.mem.Allocator) !ty {
    switch (@typeInfo(ty)) {
        .Int => {
            return try std.fmt.parseInt(ty, input, 10);
        },
        .Float => return std.fmt.parseFloat(ty, input),
        .Bool => {
            if (std.mem.eql(u8, input, "true")) {
                return true;
            } else if (std.mem.eql(u8, input, "false")) {
                return false;
            } else {
                return TsvError.WrongTypeParsed;
            }
        },
        .Enum => |info| {
            inline for (info.fields) |field| {
                if (std.mem.eql(u8, field.name, input)) {
                    return @enumFromInt(field.value);
                }
            }
            return error.EnumNotFound;
        },
        @typeInfo([]u8) => {
            const mem = try allocator.alloc(u8, input.len);
            std.mem.copyForwards(u8, mem, input);
            return mem;
        },
        else => {},
    }

    if (ty == Uuid) {
        const v = try std.fmt.parseInt(UuidType, input, 10);
        return Uuid{
            .value = v,
        };
    }

    // Assuming it is a Key(T)
    if (@hasField(ty, "key")) {
        const v = try std.fmt.parseInt(UuidType, input, 10);
        return ty{
            .key = Uuid{
                .value = v,
            },
        };
    }

    @compileError("Cannot parse type '" ++ @typeName(ty) ++ "'");
}

pub fn parse(comptime ty: type, reader: anytype, ret: *db.Map(ty), allocator: std.mem.Allocator) !void {
    if (@typeInfo(ty) != .Struct) {
        @compileError("Expected ty to be of struct type.");
    }
    //var line_iterator = std.mem.split(u8, input, "\n");
    var line_buf: [LINE_BUF_LEN]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        var field_iterator = std.mem.split(u8, line, "\t");
        var built_ty: ty = undefined;

        const uuid_str = field_iterator.next() orelse return error.MissingField;
        const uuid_val = std.fmt.parseInt(UuidType, uuid_str, 10) catch return error.InvalidUuid;
        const uuid = Uuid{
            .value = uuid_val,
        };

        inline for (@typeInfo(ty).Struct.fields) |field| {
            const field_str = field_iterator.next() orelse return error.MissingField;
            @field(built_ty, field.name) = try parsePrimitive(field.type, field_str, allocator);
        }

        if (field_iterator.next()) |_| {
            return error.ParsedTooManyFields;
        }

        if (@typeInfo(ty) == .Struct and @hasDecl(ty, "deinit")) {
            if (ret.getPtr(uuid)) |removed| {
                removed.deinit(allocator);
            }
        }
        try ret.put(uuid, built_ty);
    }
}

pub fn write(comptime ty: type, input: *const db.Map(ty), writer: anytype) !void {
    if (@typeInfo(ty) != .Struct) {
        @compileError("Expected ty to be of struct type");
    }

    try writer.print("#uuid", .{});
    inline for (@typeInfo(ty).Struct.fields) |field| {
        try writer.print("\t{s}", .{field.name});
    }
    try writer.print("\n", .{});

    var it = input.iterator();
    while (it.next()) |pair| {
        const uuid = pair.key_ptr.*;
        const value = pair.value_ptr.*;

        try writer.print("{}", .{uuid.value});

        inline for (@typeInfo(ty).Struct.fields) |field| {
            const v = @field(value, field.name);
            const v_ty = @TypeOf(v);
            switch (@typeInfo(v_ty)) {
                .Int, .Float => {
                    try writer.print("\t{}", .{v});
                    continue;
                },
                .Bool => {
                    if (v) {
                        try writer.print("\ttrue", .{});
                    } else {
                        try writer.print("\tfalse", .{});
                    }
                    continue;
                },
                .Enum => {
                    try writer.print("\t{}", .{@intFromEnum(v)});
                    continue;
                },
                @typeInfo([]u8) => {
                    try writer.print("\t{s}", .{v});
                    continue;
                },
                else => {},
            }

            if (v_ty == Uuid) {
                try writer.print("\t{}", .{v.value});
                continue;
            }

            // Assuming it is a Key(T)
            if (@hasField(v_ty, "key")) {
                try writer.print("\t{}", .{v.key.value});
                continue;
            }

            @compileError("Cannot serialize field of type '" ++ @typeName(v_ty) ++ "'");
        }
        try writer.print("\n", .{});
    }
}

test "Parse all supported types" {
    const TestEnum = enum {
        henlo,
    };
    const TestStruct = struct {
        a: []u8,
        b: i32,
        c: f32,
        d: bool,
        e: TestEnum,
        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            allocator.free(self.a);
        }
    };

    var data = db.Map(TestStruct).init(std.testing.allocator);
    defer data.deinit();

    const test_content = "155\thenlouste\t-55\t-55.55\ttrue\thenlo";
    var stream = std.io.fixedBufferStream(test_content);
    try parse(TestStruct, stream.reader(), &data, testing.allocator);
    defer data.values()[0].deinit(std.testing.allocator);

    try testing.expectEqualStrings("henlouste", data.values()[0].a);
    try testing.expectEqual(@as(i32, -55), data.values()[0].b);
    try testing.expectEqual(@as(f32, -55.55), data.values()[0].c);
    try testing.expect(data.values()[0].d);
    try testing.expectEqual(TestEnum.henlo, data.values()[0].e);
}
