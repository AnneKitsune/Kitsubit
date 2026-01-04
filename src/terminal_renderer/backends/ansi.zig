//! ANSI terminal backend for PC platforms
//! Provides terminal rendering capabilities using ANSI escape sequences

const std = @import("std");
const File = std.fs.File;

const raw = @import("../raw_term.zig");
const term_size = @import("../term_size.zig");
const ansi_colors = @import("../ansi_colors.zig");
const ansi_cursor = @import("../ansi_cursor.zig");
const screen = @import("../ansi_screen.zig");
const log = @import("log");
const vector = @import("../../math/vector.zig");

const TerminalRenderer = @import("../term_renderer.zig").TerminalRenderer;
const Color = @import("../../color.zig").Color;
const TextStyle = @import("../../text/style.zig").TextStyle;
const Position2 = vector.Position2;
const Dimension2 = vector.Dimension2;

/// Export Color type for compatibility
const colorIndex = ansi_colors.color_index;

/// ANSI terminal backend implementation
pub const AnsiBackend = struct {
    stdin: File,
    stdout: File,
    legacy_colors: bool = false,
    // TODO implement check to skip setting color if its already correct.
    last_fg: ?Color = null,
    last_bg: ?Color = null,

    const S = @This();

    /// Initialize the ANSI backend
    pub fn init() !S {
        const stdin = std.io.getStdIn();
        const stdout = std.io.getStdOut();

        if (!stdin.supportsAnsiEscapeCodes()) {
            return error.ansi_escapes_unsupported;
        }

        if (!raw.enable_raw_mode()) {
            return error.raw_mode_failed;
        }

        try stdout.writer().print("{s}{s}", .{ ansi_cursor.CURSOR_HIDE, screen.SCREEN_ERASE });

        return S{
            .stdin = stdin,
            .stdout = stdout,
        };
    }

    /// Deinitialize the ANSI backend
    pub fn deinit(self: *S) void {
        raw.disable_raw_mode() catch {};
        self.stdout.writer().print("{s}{s}{s}", .{ ansi_cursor.CURSOR_SHOW, ansi_colors.RESET_CODE, screen.SCREEN_ERASE }) catch {};
    }

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
        const s: *S = @ptrCast(@alignCast(ctx));

        if (style.bold or style.italic or style.strikethrough) {
            @panic("TODO: Unimplemented");
        }

        const fg = fg_color.convert(.ansi_terminal).ansi_terminal;
        const bg = bg_color.convert(.ansi_terminal).ansi_terminal;
        const color_index = colorIndex(fg, bg);

        try s.cursorMove(@intCast(x), @intCast(y));
        try s.writeColor(color_index);
        try s.print("{s}", text);
    }

    pub fn setSize(ctx: *anyopaque, new_size: ?Dimension2(u16)) !Dimension2(u16) {
        const s: *S = @ptrCast(@alignCast(ctx));
        _ = s;

        if (new_size) |n| {
            _ = n;
            @panic("Unimplemented");
        }

        var ret: Dimension2(u16) = undefined;
        if (!term_size.term_size(&ret.x, &ret.y)) {
            return error.NoSize;
        }
        return ret;
    }

    pub fn flush(ctx: *anyopaque, clear: bool) !void {
        const s: *S = @ptrCast(@alignCast(ctx));
        try s.flush();
        // TODO handle clear
        _ = clear;
    }

    /// Set legacy colors mode
    pub fn setLegacyColors(self: *S, legacy: bool) void {
        self.legacy_colors = legacy;
    }

    /// Update terminal size
    pub fn updateSize(self: *S, log_scope: *const log.LogScope, size_x: *usize, size_y: *usize) void {
        _ = self;
        if (!term_size.term_size(size_x, size_y)) {
            log_scope.info("Failed to update terminal size. Skipping size update for this time.", .{});
        }
    }

    /// Write formatted string to stdout
    pub fn print(self: *S, comptime format: []const u8, args: anytype) !void {
        try self.stdout.writer().print(format, args);
    }

    /// Write color code to stdout
    pub fn writeColor(self: *S, color_index: u8) !void {
        if (!self.legacy_colors) {
            try self.print("{s}", .{ansi_colors.COLOR_CODES[color_index]});
        } else {
            try self.print("{s}{s}", .{ ansi_colors.COLOR_CODES[color_index], ansi_colors.LEGACY_CODES[color_index] });
        }
    }

    /// Show cursor
    pub fn cursorShow(self: *S) !void {
        try self.print(ansi_cursor.CURSOR_SHOW, .{});
    }

    /// Move cursor to position
    pub fn cursorMove(self: *S, x: usize, y: usize) !void {
        try self.print(ansi_cursor.CURSOR_MOVE_FORMAT, .{ y + 1, x + 1 });
    }

    /// Hide cursor
    pub fn cursorHide(self: *S) !void {
        try self.print(ansi_cursor.CURSOR_HIDE, .{});
    }

    /// Get input from stdin
    /// TODO move out of here
    pub fn getInput(self: *S) !u8 {
        return self.stdin.reader().readByte();
    }
};

test "ansi_backend_import" {
    std.testing.refAllDecls(AnsiBackend);
}

// Structure holding information used to buffer drawing commands, get inputs and render to the terminal.
//
// Created using the init function.
//
// Most methods don't affect the terminal directly, but instead write to an internal
// buffer. Use the render() method to apply changes to the terminal.
//
// If the internal buffer is completely filled, it will automatically apply changes
// to the terminal.
// If this happens, max_reached_buffer_pos will be equal to WRITE_BUF_LEN and indicates that
// WRITE_BUF_LEN should be increased for your use case.
//pub const TerminalBackendAnsi = struct {
//    const S = @This();
//
//    pub const Options = struct {
//        ansi_legacy_colors: bool = false,
//        sync_size_to_terminal: bool = true,
//    };
//
//    pub fn init() S {
//        return .{};
//    }
//
//    pub fn renderer(s: *S) TerminalRenderer {
//        return .{
//            .backend_ptr = s,
//            .vtable = comptime &.{
//                .write = write,
//                .setSize = setSize,
//                .flush = flush,
//            },
//        };
//    }
//
//    /// Flush the internal buffer to the terminal to make the requested changes visible.
//    pub fn render(s: *S) !void {
//        // Move cursor
//        var last_color: u8 = 255;
//        const chars = s.char_buffer.items(.char);
//        const colors = s.char_buffer.items(.color_index);
//        for (0..s.size_y) |y| {
//            s.cursorMove(0, y);
//            for (0..s.size_x) |x| {
//                const idx = y * s.size_x + x;
//                // set color
//                if (last_color != colors[idx]) {
//                    last_color = colors[idx];
//                    s.backend.writeColor(&s.log_scope, colors[idx]);
//                }
//                // print
//                s.backend.write(&s.log_scope, "{c}", .{chars[idx]});
//            }
//        }
//        try s.updateSize();
//        s.clearBuffer();
//    }
//
//    /// Updates the internal size struct. Automatically called on init(bool) and on render().
//    fn updateSize(s: *S) !void {
//        s.backend.updateSize(&s.log_scope, &s.size_x, &s.size_y);
//        try s.char_buffer.ensureTotalCapacity(s.alloc, s.size_x * s.size_y);
//        const add_count = s.char_buffer.capacity - s.char_buffer.len;
//        for (0..add_count) |_| {
//            s.char_buffer.appendAssumeCapacity(CharacterSlot{});
//        }
//    }
//
//    fn clearBuffer(s: *S) void {
//        const len = s.size_x * s.size_y;
//        @memset(s.char_buffer.items(.char)[0..len], ' ');
//        @memset(s.char_buffer.items(.depth)[0..len], 0);
//        @memset(s.char_buffer.items(.color_index)[0..len], colorIndex(.white, .black));
//    }
//
//    /// Print a string into the internal buffer.
//    pub fn print(s: *S, x: usize, y: usize, comptime format: []const u8, args: anytype, options: PrintOptions) void {
//        var str_buf: [PRINT_BUFFER_SIZE]u8 = undefined;
//        const str = std.fmt.bufPrint(&str_buf, format, args) catch @panic("String too long for TerminalRenderer buffer.");
//
//        if (std.debug.runtime_safety and y >= s.size_y) {
//            s.log_scope.err("Writing to terminal at y={} but terminal size is {}. String was: {s}. Ignoring.", .{ y, s.size_y, str });
//            return;
//        }
//
//        const depths = s.char_buffer.items(.depth);
//        for (str, 0..) |c, i| {
//            const idx = y * s.size_x + x + i;
//
//            if (std.debug.runtime_safety and x + i >= s.size_x) {
//                s.log_scope.err("Writing to terminal at x={} but terminal size is {}. String was: {s}. Stopping current print.", .{ x, s.size_x, str });
//                return;
//            }
//
//            if (options.depth >= depths[idx]) {
//                s.char_buffer.set(idx, .{
//                    .char = c,
//                    .color_index = colorIndex(options.fg, options.bg),
//                    .depth = options.depth,
//                });
//            }
//        }
//    }
//
//};
//
