const std = @import("std");
const builtin = @import("builtin");
const MultiArrayList = std.MultiArrayList;
const testing = std.testing;

const ansi_backend = @import("backends/ansi.zig");
const log = @import("log");
const vector = @import("../math/vector.zig");

const Position2 = vector.Position2;
const Dimension2 = vector.Dimension2;
const TextStyle = @import("../text/style.zig").TextStyle;

/// Enum of 16 possible colors.
pub const Color = @import("../color.zig").Color;
/// Function to convert a foreground and background color into an index.
/// It is more efficient to store the index (one byte) than two colors (2 bytes).
pub const colorIndex = ansi_backend.colorIndex;

// TODO: There might be a way to skip this and forward the bytes directly all the way to the inner writer (for ansi, at least...)
pub const TEXT_BUFFER_SIZE = 4096;

/// Errors that can occur during the renderer's initialization.
pub const TerminalError = error{
    AnsiEscapesUnsupported,
    RawModeFailed,
    WriteFailed,
    NoSize,
    FlushFailed,
};

pub const TerminalRenderer = struct {
    backend_ptr: *anyopaque,
    vtable: *const VTable,
    position: Position2(u16) = .{ .x = 0, .y = 0 },
    fg_color: Color = .{ .ansi_terminal = .white },
    bg_color: Color = .{ .ansi_terminal = .black },
    style: TextStyle = .{},

    const S = @This();
    pub const VTable = struct {
        // prints the given text at the specified position using the color and style, if supported.
        write: *const fn (*anyopaque, x: u16, y: u16, fg_color: Color, bg_color: Color, style: TextStyle, text: [:0]const u8) TerminalError!void,
        // returns the previous size. changes the size if new_size isn't null.
        setSize: *const fn (*anyopaque, new_size: ?Dimension2(u16)) TerminalError!Dimension2(u16),
        // flush the internal buffer, if any or supported.
        flush: *const fn (*anyopaque, clear: bool) TerminalError!void,
    };

    pub fn setSize(s: *S, dims: Dimension2(u16)) !void {
        _ = try s.vtable.setSize(s.backend_ptr, dims);
    }

    pub fn getSize(s: *S) !Dimension2(u16) {
        return try s.vtable.setSize(s.backend_ptr, null);
    }

    pub fn color(s: *S, fg: Color, bg: Color) void {
        s.fg_color = fg;
        s.bg_color = bg;
    }

    pub fn goto(s: *S, x: u16, y: u16) void {
        s.position.x = x;
        s.position.y = y;
    }

    pub fn blink(s: *S, b: bool) void {
        s.style.blink = b;
    }

    pub fn italic(s: *S, b: bool) void {
        s.style.italic = b;
    }

    pub fn bold(s: *S, b: bool) void {
        s.style.bold = b;
    }

    pub fn underline(s: *S, b: bool) void {
        s.style.underline = b;
    }

    pub fn strikethrough(s: *S, b: bool) void {
        s.style.strikethrough = b;
    }

    pub fn resetStyle(s: *S) void {
        s.style = .{};
    }

    pub fn print(s: *S, comptime fmt: []const u8, args: anytype) !void {
        // TODO it would be nice to skip doing the formatting here and pass fmt & args down into the backend which can handle it
        // more optimally (like pass it directly to a writer in some cases.)
        var text: [TEXT_BUFFER_SIZE]u8 = undefined;
        const filled_text = try std.fmt.bufPrintZ(text[0..], fmt, args);
        try s.vtable.write(s.backend_ptr, s.position.x, s.position.y, s.fg_color, s.bg_color, s.style, filled_text);
    }

    pub fn flush(s: *S, clear: bool) !void {
        try s.vtable.flush(s.backend_ptr, clear);
    }
};

test "import" {
    std.testing.refAllDecls(TerminalRenderer);
}
