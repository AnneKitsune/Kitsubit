const std = @import("std");
const Type = std.builtin.Type;

pub fn AutoInitStruct(comptime types: []const type) type {
    comptime var fields: []const Type.StructField = &.{};
    inline for (types) |ty| {
        fields = fields ++ &[_]Type.StructField{
            .{
                .type = ty,
                .name = std.fmt.comptimePrint("{}", .{fields.len}),
                .default_value = null,
                .alignment = 0,
                .is_comptime = false,
            },
        };
    }

    const InnerTypes = @Type(.{ .@"struct" = .{
        .fields = fields,
        .is_tuple = false,
        .layout = .auto,
        .decls = &.{},
    } });

    return struct {
        inner: InnerTypes,
        allocator: std.mem.Allocator,

        pub const Inner: type = InnerTypes;
        const S = @This();
        pub fn init(alloc: std.mem.Allocator) !S {
            var in: InnerTypes = undefined;

            inline for (types, 0..) |ty, i| {
                const field_name = std.fmt.comptimePrint("{}", .{i});
                if (@hasDecl(ty, "init")) {
                    const init_fn_info = @typeInfo(@TypeOf(ty.init)).Fn;
                    var ret: init_fn_info.return_type.? = undefined;
                    if (init_fn_info.params.len == 1) {
                        ret = ty.init(alloc);
                    } else {
                        ret = ty.init();
                    }
                    if (@typeInfo(@TypeOf(ret)) == .errorunion) {
                        @field(in, field_name) = try ret;
                    } else {
                        @field(in, field_name) = ret;
                    }
                } else {
                    @field(in, field_name) = .{};
                }
            }

            return S{
                .inner = in,
                .allocator = alloc,
            };
        }

        pub fn get(s: *const S, comptime ty: type) *const ty {
            inline for (types, 0..) |t, i| {
                if (ty == t) {
                    const field_name = std.fmt.comptimePrint("{}", .{i});
                    return &@field(s.inner, field_name);
                }
            }
            @compileError("Type " ++ @typeName(ty) ++ " is not inside of the AutoInitStruct.");
        }

        pub fn getMut(s: *S, comptime ty: type) *ty {
            inline for (types, 0..) |t, i| {
                if (ty == t) {
                    const field_name = std.fmt.comptimePrint("{}", .{i});
                    return &@field(s.inner, field_name);
                }
            }
            @compileError("Type " ++ @typeName(ty) ++ " is not inside of the AutoInitStruct.");
        }

        pub fn deinit(s: *S) void {
            inline for (types, 0..) |ty, i| {
                if (@hasDecl(ty, "deinit")) {
                    const field_name = std.fmt.comptimePrint("{}", .{i});
                    const deinit_fn_info = @typeInfo(@TypeOf(ty.deinit)).@"fn";
                    if (deinit_fn_info.params.len == 2) {
                        @field(s.inner, field_name).deinit(s.allocator);
                    } else {
                        @field(s.inner, field_name).deinit();
                    }
                }
            }
        }
    };
}

pub fn genSystem(comptime ty: type, comptime func: []const u8) fn (*ty) error{}!void {
    return struct {
        pub fn sys(data: *ty) !void {
            if (!@hasDecl(ty, func)) {
                @compileError("Provided type (" ++ @typeName(ty) ++ ") to genUpkeep does not have the requested \"" ++ func ++ "\" function.");
            }
            @field(ty, func)(data);
        }
    }.sys;
}

fn genSystemsTypes(comptime world: type, comptime func: []const u8) type {
    comptime var fields: []const Type.StructField = &.{};
    //comptime var types: []const type = &.{};
    inline for (std.meta.fields(world.Inner)) |field| {
        if (@hasDecl(field.type, func)) {
            //types = types ++ &[_]type {@TypeOf(genSystem(field.type, func))};
            fields = fields ++ &[_]Type.StructField{
                .{
                    .type = @TypeOf(genSystem(field.type, func)),
                    .name = std.fmt.comptimePrint("{}", .{fields.len}),
                    .default_value = null,
                    .alignment = 0,
                    .is_comptime = false,
                },
            };
        }
    }

    return @Type(.{ .@"struct" = .{
        .fields = fields,
        .is_tuple = true,
        .layout = .auto,
        .decls = &.{},
    } });
    //return std.meta.Tuple(types);
}

/// Generates a tuple of systems that each call the specified function in a specific type of the given world, if the type has that function.
/// The generated systems are meant to be used in a `Dispatcher`.
pub fn genSystems(comptime world: type, comptime func: []const u8) genSystemsTypes(world, func) {
    comptime var systems: genSystemsTypes(world, func) = undefined;
    inline for (std.meta.fields(world.Inner), 0..) |field, i| {
        if (@hasDecl(field.type, func)) {
            @field(systems, std.meta.fields(@TypeOf(systems))[i].name) = genSystem(field.type, func);
        }
    }
    return systems;
}

/// Generates systems that call the upkeep function on every resource contained in the world if that resource has that function.
pub fn genUpkeepSystems(comptime world: type) genSystemsTypes(world, "upkeep") {
    return comptime genSystems(world, "upkeep");
}

test "Upkeep" {
    const A = struct {
        const S = @This();
        pub fn upkeep(s: *S) void {
            _ = s;
        }
    };
    const B = struct {};
    var world = try AutoInitStruct(&.{
        A, B,
    }).init(std.testing.allocator);

    const upkeepSystems = comptime genUpkeepSystems(@TypeOf(world));

    const Dispatcher = @import("dispatcher.zig").Dispatcher;
    const dispatch = Dispatcher(upkeepSystems){};
    try dispatch.runSeq(&world.inner);
}

const TestDefault = struct {
    a: i32 = 0,
};

const TestInit = struct {
    a: i32,

    const S = @This();
    pub fn init(alloc: std.mem.Allocator) S {
        _ = alloc;
        return S{
            .a = 0,
        };
    }
    pub fn deinit(s: *S) void {
        _ = s;
    }
};

test "auto init struct" {
    var cont = try AutoInitStruct(&.{ TestDefault, TestInit }).init(std.testing.allocator);
    _ = cont.get(TestDefault);
    _ = cont.getMut(TestInit);
    defer cont.deinit();
}
