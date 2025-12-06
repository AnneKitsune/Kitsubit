const std = @import("std");
const MultiArrayList = std.MultiArrayList;
const testing = std.testing;

const ansi_backend = @import("backends/ansi.zig");
const log = @import("log");

/// Enum of 16 possible colors.
pub const Color = ansi_backend.Color;
/// Function to convert a foreground and background color into an index.
/// It is more efficient to store the index (one byte) than two colors (2 bytes).
pub const colorIndex = ansi_backend.colorIndex;

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

/// Backend selection based on compilation target
fn selectBackend() type {
    return struct {
        const is_pc = @import("builtin").target.isDarwin() or
            @import("builtin").target.isLinux() or
            @import("builtin").target.isWindows();

        const Backend = if (is_pc) ansi_backend.AnsiBackend else void;
    };
}

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
    size_x: usize = 0,
    size_y: usize = 0,
    alloc: std.mem.Allocator,

    // Backend field with compile-time type selection
    backend: selectBackend().Backend,
    // Logging scope for terminal renderer
    log_scope: log.LogScope,

    const S = @This();

    /// Creates a new TerminalRenderer.
    pub fn init(alloc: std.mem.Allocator, logger: *log.Log) !S {
        const char_buffer = MultiArrayList(CharacterSlot){};
        const backend = try selectBackend().Backend.init();
        const log_scope = logger.scope("terminal_renderer");

        var r = TerminalRenderer{
            .alloc = alloc,
            .char_buffer = char_buffer,
            .backend = backend,
            .log_scope = log_scope,
        };

        try r.updateSize();

        return r;
    }

    /// Brings the terminal back to it's normal state.
    pub fn deinit(s: *S) void {
        s.render() catch {};
        s.backend.deinit(&s.log_scope);
        s.char_buffer.deinit(s.alloc);
    }

    /// Legacy colors indicates if we should be using the "bold" text attribute to have
    /// bright text instead of the newer ansi codes.
    /// Only enable if bright colors (8 to 15) are identical to non-bright colors (0 to 7).
    pub fn setLegacyColors(s: *S, legacy: bool) void {
        s.legacy_colors = legacy;
        s.backend.setLegacyColors(legacy);
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
                    s.backend.writeColor(&s.log_scope, colors[idx]);
                }
                // print
                s.backend.write(&s.log_scope, "{c}", .{chars[idx]});
            }
        }
        try s.updateSize();
        s.clearBuffer();
    }

    /// Updates the internal size struct. Automatically called on init(bool) and on render().
    fn updateSize(s: *S) !void {
        s.backend.updateSize(&s.log_scope, &s.size_x, &s.size_y);
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
        s.backend.cursorShow(&s.log_scope);
    }

    /// Moves cursor to the requested position.
    pub fn cursorMove(s: *S, x: usize, y: usize) void {
        s.backend.cursorMove(&s.log_scope, x, y);
    }

    /// Makes the cursor invisible.
    pub fn cursorHide(s: *S) void {
        s.backend.cursorHide(&s.log_scope);
    }

    /// Print a string into the internal buffer.
    pub fn print(s: *S, x: usize, y: usize, comptime format: []const u8, args: anytype, options: PrintOptions) void {
        var str_buf: [PRINT_BUFFER_SIZE]u8 = undefined;
        const str = std.fmt.bufPrint(&str_buf, format, args) catch @panic("String too long for TerminalRenderer buffer.");

        if (std.debug.runtime_safety and y >= s.size_y) {
            s.log_scope.err("Writing to terminal at y={} but terminal size is {}. String was: {s}. Ignoring.", .{ y, s.size_y, str });
            return;
        }

        const depths = s.char_buffer.items(.depth);
        for (str, 0..) |c, i| {
            const idx = y * s.size_x + x + i;

            if (std.debug.runtime_safety and x + i >= s.size_x) {
                s.log_scope.err("Writing to terminal at x={} but terminal size is {}. String was: {s}. Stopping current print.", .{ x, s.size_x, str });
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
        return self.backend.getInput();
    }
};

test "import" {
    std.testing.refAllDecls(TerminalRenderer);
}
