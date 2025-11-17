const renderer = @import("terminal_renderer.zig");
const Color = renderer.Color;
const Renderer = renderer.Renderer;
const PrintOptions = renderer.PrintOptions;
const Direction = @import("math.zig").Direction;

const std = @import("std");

pub fn hline(r: *Renderer, x: usize, y: usize, len: usize, char: u8, options: PrintOptions) void {
    for (0..len) |i| {
        r.print(x + i, y, "{c}", .{char}, options);
    }
}

pub fn vline(r: *Renderer, x: usize, y: usize, len: usize, char: u8, options: PrintOptions) void {
    for (0..len) |i| {
        r.print(x, y + i, "{c}", .{char}, options);
    }
}

pub fn box(r: *Renderer, x: usize, y: usize, width: usize, height: usize, options: PrintOptions) void {
    std.debug.assert(width >= 2);
    std.debug.assert(height >= 2);

    r.print(x, y, "+", .{}, options);
    r.print(x + width - 1, y, "+", .{}, options);
    r.print(x, y + height - 1, "+", .{}, options);
    r.print(x + width - 1, y + height - 1, "+", .{}, options);

    hline(r, x + 1, y, width - 2, '-', options);
    hline(r, x + 1, y + height - 1, width - 2, '-', options);
    vline(r, x, y + 1, height - 2, '|', options);
    vline(r, x + width - 1, y + 1, height - 2, '|', options);
}

/// Fill: [0, 1]
pub fn progress(r: *Renderer, x: usize, y: usize, width: usize, fill: f32, options: PrintOptions) void {
    std.debug.assert(fill >= 0.0);
    std.debug.assert(fill <= 1.0);
    const fill_width_abstract = fill * @as(f32, @floatFromInt(width));
    // fully filled bars
    const fill_width = @as(u32, @intFromFloat(fill_width_abstract));
    const remainder = fill_width_abstract - @as(f32, @floatFromInt(fill_width));

    var i: usize = 0;
    while (i < fill_width) : (i += 1) {
        r.print(x + i, y, "|", .{}, options);
    }

    if (fill_width == width) return;

    if (remainder < 0.3333) {
        r.print(x + i, y, ".", .{}, options);
    } else if (remainder < 0.6666) {
        r.print(x + i, y, "\\", .{}, options);
    } else {
        r.print(x + i, y, "|", .{}, options);
    }
}

pub fn MultiCursor(comptime count: usize) type {
    return struct {
        x: i32 = 0,
        y: [count]i32,

        const S = @This();

        pub fn init() S {
            var slice: [count]i32 = undefined;
            for (&slice) |*v| {
                v.* = -1;
            }

            return S{
                .y = slice,
            };
        }

        pub fn getX(s: *const S) usize {
            return @intCast(s.x);
        }

        pub fn getY(s: *const S, x: usize) ?usize {
            if (s.y[x] >= 0) {
                return @intCast(s.y[x]);
            } else {
                return null;
            }
        }

        pub fn getSelectedY(s: *const S) ?usize {
            return s.getY(s.getX());
        }

        pub fn reset(s: *S) void {
            s.x = 0;
            for (&s.y) |*v| {
                v.* = -1;
            }
        }

        pub fn move(s: *S, dir: Direction, limits: [count]usize) void {
            const x_usize: usize = @intCast(s.x);
            switch (dir) {
                .left => s.x = @intCast(@mod(s.x - 1, @as(i32, @intCast(count)))),
                .right => s.x = @intCast(@mod(s.x + 1, @as(i32, @intCast(count)))),
                .up => s.y[x_usize] = @intCast(@mod(s.y[x_usize] - 1, @max(@as(i32, @intCast(limits[x_usize])), 1))),
                .down => s.y[x_usize] = @intCast(@mod(s.y[x_usize] + 1, @max(@as(i32, @intCast(limits[x_usize])), 1))),
                .none => {},
            }

            // ensure all y are within limits
            s.fixY(limits);
        }

        pub fn fixY(s: *S, limits: [count]usize) void {
            for (&s.y, 0..) |*v, i| {
                if (v.* >= limits[i]) {
                    // we were past the limit of selectable items, clamp to the last item
                    v.* = @as(i32, @intCast(limits[i])) - 1;
                } else if (v.* < 0 and limits[i] > 0) {
                    // we had nothing selected but now we can have the first one
                    v.* = 0;
                }
            }
        }
    };
}

pub const TextEdit = struct {
    str: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    const S = @This();
    pub fn init(alloc: std.mem.Allocator) S {
        const str = std.ArrayList(u8).init(alloc);
        return S{
            .str = str,
            .allocator = alloc,
        };
    }

    // when enter is the input, a copy of the inner string is returned.
    // when escape is the input, an empty string is returned.
    // when any other input is entered, null is returned.
    pub fn handleInput(s: *S, input: u8) !?[]const u8 {
        if (input == 13) {
            // enter
            const cpy = try s.allocator.alloc(u8, s.str.items.len);
            std.mem.copyForwards(u8, cpy, s.str.items);
            s.str.clearRetainingCapacity();
            return cpy;
        } else if (input == 27) {
            // escape
            s.str.clearRetainingCapacity();
            return "";
        } else if (input == 127) {
            // backspace
            _ = s.str.popOrNull();
        } else if (input >= 'A' and input <= 'z') {
            try s.str.append(input);
        }
        return null;
    }

    pub fn deinit(s: *S) void {
        s.str.deinit();
    }
};

test "text edit normal" {
    var te = TextEdit.init(std.testing.allocator);
    defer te.deinit();

    try std.testing.expectEqual(try te.handleInput('h'), null);
    try std.testing.expectEqual(try te.handleInput('e'), null);
    try std.testing.expectEqual(try te.handleInput('l'), null);
    try std.testing.expectEqual(try te.handleInput('l'), null);
    try std.testing.expectEqual(try te.handleInput('o'), null);
    try std.testing.expectEqual(try te.handleInput(127), null);
    const str = (try te.handleInput(13)).?;
    try std.testing.expectEqual(te.str.items.len, 0);
    try std.testing.expect(std.mem.eql(u8, str, "hell"));
    std.testing.allocator.free(str);
}

test "text edit cancelled" {
    var te = TextEdit.init(std.testing.allocator);
    defer te.deinit();

    try std.testing.expectEqual(try te.handleInput('h'), null);
    try std.testing.expectEqual(te.str.items.len, 1);
    const str = (try te.handleInput(27)).?;
    try std.testing.expectEqual(te.str.items.len, 0);
    std.testing.allocator.free(str);
}
