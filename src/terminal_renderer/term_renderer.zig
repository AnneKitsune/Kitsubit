const std = @import("std");
const File = std.fs.File;
const MultiArrayList = std.MultiArrayList;
const testing = std.testing;

const raw = @import("raw_term.zig");
const term_size = @import("term_size.zig");
const ansi_colors = @import("ansi_colors.zig");
const ansi_cursor = @import("ansi_cursor.zig");
const screen = @import("ansi_screen.zig");
const logger = @import("../logger.zig");

/// Enum of 16 possible colors.
pub const Color = ansi_colors.Color;
/// Function to convert a foreground and background color into an index.
/// It is more efficient to store the index (one byte) than two colors (2 bytes).
pub const colorIndex = ansi_colors.color_index;

/// Errors that can occur during the renderer's initialization.
pub const TerminalInitError = error{
    ansi_escapes_unsupported,
    raw_mode_failed,
};

const CharacterSlot = struct {
    char: u8 = ' ', // ascii
    depth: u8 = 0, // higher = more towards the user = higher draw priority.
    color_index: u8 = colorIndex(.white, .black),
};

pub const PrintOptions = struct {
    fg: Color = .white,
    bg: Color = .black,
    depth: u8 = 0,
};

const PRINT_BUFFER_SIZE = 2048;

/// Structure holding information used to buffer drawing commands, get inputs and render to the terminal.
///
/// Created using the init function.
///
/// Most methods don't affect the terminal directly, but instead write to an internal
/// buffer. Use the render() method to apply changes to the terminal.
///
/// If the internal buffer is completely filled, it will automatically apply changes
/// to the terminal.
/// If this happens, max_reached_buffer_pos will be equal to WRITE_BUF_LEN and indicates that
/// WRITE_BUF_LEN should be increased for your use case.
pub const TerminalRenderer = struct {
    char_buffer: MultiArrayList(CharacterSlot),
    legacy_colors: bool = false,
    stdin: File,
    stdout: File,
    size_x: usize = 0,
    size_y: usize = 0,
    alloc: std.mem.Allocator,

    const S = @This();
    /// Creates a new TerminalRenderer.
    pub fn init(alloc: std.mem.Allocator) !S {
        const stdin = std.io.getStdIn();
        const stdout = std.io.getStdOut();
        const char_buffer = MultiArrayList(CharacterSlot){};

        if (!stdin.supportsAnsiEscapeCodes()) {
            return TerminalInitError.ansi_escapes_unsupported;
        }

        if (!raw.enable_raw_mode()) {
            return TerminalInitError.raw_mode_failed;
        }

        try stdout.writer().print("{s}{s}", .{ ansi_cursor.CURSOR_HIDE, screen.SCREEN_ERASE });

        var r = TerminalRenderer{
            .stdin = stdin,
            .stdout = stdout,
            .alloc = alloc,
            .char_buffer = char_buffer,
        };

        try r.updateSize();

        return r;
    }

    /// Brings the terminal back to it's normal state.
    pub fn deinit(s: *S) void {
        s.render() catch {};
        _ = raw.disable_raw_mode();
        s.stdout.writer().print("{s}{s}{s}", .{ ansi_cursor.CURSOR_SHOW, ansi_colors.RESET_CODE, screen.SCREEN_ERASE }) catch {};
        s.char_buffer.deinit(s.alloc);
    }

    /// Legacy colors indicates if we should be using the "bold" text attribute to have
    /// bright text instead of the newer ansi codes.
    /// Only enable if bright colors (8 to 15) are identical to non-bright colors (0 to 7).
    pub fn setLegacyColors(s: *S, legacy: bool) void {
        s.legacy_colors = legacy;
    }

    /// Flush the internal buffer to the terminal to make the requested changes visible.
    pub fn render(s: *S) !void {
        // Move cursor
        var last_color: u8 = 255;
        const chars = s.char_buffer.items(.char);
        const colors = s.char_buffer.items(.color_index);
        for (0..s.size_y) |y| {
            s.cursorMove(0, y);
            for (0..s.size_x) |x| {
                const idx = y * s.size_x + x;
                // set color
                if (last_color != colors[idx]) {
                    last_color = colors[idx];
                    if (!s.legacy_colors) {
                        s.write("{s}", .{ansi_colors.COLOR_CODES[last_color]});
                    } else {
                        s.write("{s}{s}", .{ ansi_colors.COLOR_CODES[last_color], ansi_colors.LEGACY_CODES[last_color] });
                    }
                }
                // print
                s.write("{c}", .{chars[idx]});
            }
        }
        try s.updateSize();
        s.clearBuffer();
    }

    /// Updates the internal size struct. Automatically called on init(bool) and on render().
    fn updateSize(s: *S) !void {
        if (!term_size.term_size(&s.size_x, &s.size_y)) {
            logger.info("Failed to update terminal size. Skipping size update for this time.", .{});
        }
        try s.char_buffer.ensureTotalCapacity(s.alloc, s.size_x * s.size_y);
        const add_count = s.char_buffer.capacity - s.char_buffer.len;
        for (0..add_count) |_| {
            s.char_buffer.appendAssumeCapacity(CharacterSlot{});
        }
    }

    fn clearBuffer(s: *S) void {
        const len = s.size_x * s.size_y;
        @memset(s.char_buffer.items(.char)[0..len], ' ');
        @memset(s.char_buffer.items(.depth)[0..len], 0);
        @memset(s.char_buffer.items(.color_index)[0..len], colorIndex(.white, .black));
    }

    /// Makes the cursor visible.
    pub fn cursorShow(s: *S) void {
        s.write(ansi_cursor.CURSOR_SHOW, .{});
    }

    /// Moves cursor to the requested position.
    pub fn cursorMove(s: *S, x: usize, y: usize) void {
        s.write(ansi_cursor.CURSOR_MOVE_FORMAT, .{ y + 1, x + 1 });
    }

    /// Makes the cursor invisible.
    pub fn cursorHide(s: *S) void {
        s.write(ansi_cursor.CURSOR_HIDE, .{});
    }

    /// Print a string into the internal buffer.
    pub fn print(s: *S, x: usize, y: usize, comptime format: []const u8, args: anytype, options: PrintOptions) void {
        var str_buf: [PRINT_BUFFER_SIZE]u8 = undefined;
        const str = std.fmt.bufPrint(&str_buf, format, args) catch @panic("String too long for TerminalRenderer buffer.");

        if (std.debug.runtime_safety and y >= s.size_y) {
            logger.err("Writing to terminal at y={} but terminal size is {}. String was: {s}. Ignoring.", .{ y, s.size_y, str });
            return;
        }

        const depths = s.char_buffer.items(.depth);
        for (str, 0..) |c, i| {
            const idx = y * s.size_x + x + i;

            if (std.debug.runtime_safety and x + i >= s.size_x) {
                logger.err("Writing to terminal at x={} but terminal size is {}. String was: {s}. Stopping current print.", .{ x, s.size_x, str });
                return;
            }

            if (options.depth >= depths[idx]) {
                s.char_buffer.set(idx, .{
                    .char = c,
                    .color_index = colorIndex(options.fg, options.bg),
                    .depth = options.depth,
                });
            }
        }
    }

    /// Wait for a keyboard input and return it.
    pub fn getInput(self: *S) !u8 {
        const input = try self.stdin.reader().readByte();
        return input;
    }

    fn write(s: *S, comptime format: []const u8, args: anytype) void {
        s.stdout.writer().print(format, args) catch |e| {
            logger.err("Failed to print to stdout, err: {}", .{e});
        };
    }
};

test "import" {
    _ = TerminalRenderer;
}
