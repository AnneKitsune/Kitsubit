const vector = @import("../../math/vector.zig");

const TerminalRenderer = @import("../term_renderer.zig").TerminalRenderer;
const Color = @import("../../color.zig").Color;
const TextStyle = @import("../../text/style.zig").TextStyle;
const Position2 = vector.Position2;
const Dimension2 = vector.Dimension2;

pub const NullBackend = struct {
    size: Dimension2(u16) = .{ .x = 0, .y = 0 },

    const S = @This();
    pub fn renderer(s: *S) TerminalRenderer {
        return .{
            .backend_ptr = s,
            .vtable = comptime &.{
                .write = write,
                .setSize = setSize,
                .flush = flush,
            },
        };
    }

    pub fn write(ctx: *anyopaque, x: u16, y: u16, fg_color: Color, bg_color: Color, style: TextStyle, text: [:0]const u8) !void {
        _ = ctx;
        _ = x;
        _ = y;
        _ = fg_color;
        _ = bg_color;
        _ = style;
        _ = text;
    }

    pub fn setSize(ctx: *anyopaque, new_size: ?Dimension2(u16)) !Dimension2(u16) {
        var s: *S = @ptrCast(@alignCast(ctx));
        if (new_size) |new| {
            s.size = new;
        }
        return s.size;
    }

    pub fn flush(ctx: *anyopaque, clear: bool) !void {
        _ = ctx;
        _ = clear;
    }
};

test "Create null terminal renderer" {
    var backend = NullBackend{};
    const renderer = backend.renderer();
    _ = renderer;
}
