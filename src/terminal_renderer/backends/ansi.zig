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

/// Export Color type for compatibility
pub const Color = ansi_colors.Color;
pub const colorIndex = ansi_colors.color_index;

/// ANSI terminal backend implementation
pub const AnsiBackend = struct {
    stdin: File,
    stdout: File,
    legacy_colors: bool = false,

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
    pub fn deinit(self: *S, log_scope: *const log.LogScope) void {
        raw.disable_raw_mode() catch |err| {
            log_scope.err("Failed to disable raw mode: {}", .{err});
        };
        self.stdout.writer().print("{s}{s}{s}", .{ ansi_cursor.CURSOR_SHOW, ansi_colors.RESET_CODE, screen.SCREEN_ERASE }) catch {};
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
    pub fn write(self: *S, log_scope: *const log.LogScope, comptime format: []const u8, args: anytype) void {
        self.stdout.writer().print(format, args) catch |e| {
            log_scope.err("Failed to print to stdout, err: {}", .{e});
        };
    }

    /// Write color code to stdout
    pub fn writeColor(self: *S, log_scope: *const log.LogScope, color_index: u8) void {
        if (!self.legacy_colors) {
            self.write(log_scope, "{s}", .{ansi_colors.COLOR_CODES[color_index]});
        } else {
            self.write(log_scope, "{s}{s}", .{ ansi_colors.COLOR_CODES[color_index], ansi_colors.LEGACY_CODES[color_index] });
        }
    }

    /// Show cursor
    pub fn cursorShow(self: *S, log_scope: *const log.LogScope) void {
        self.write(log_scope, ansi_cursor.CURSOR_SHOW, .{});
    }

    /// Move cursor to position
    pub fn cursorMove(self: *S, log_scope: *const log.LogScope, x: usize, y: usize) void {
        self.write(log_scope, ansi_cursor.CURSOR_MOVE_FORMAT, .{ y + 1, x + 1 });
    }

    /// Hide cursor
    pub fn cursorHide(self: *S, log_scope: *const log.LogScope) void {
        self.write(log_scope, ansi_cursor.CURSOR_HIDE, .{});
    }

    /// Get input from stdin
    pub fn getInput(self: *S) !u8 {
        return self.stdin.reader().readByte();
    }
};

test "ansi_backend_import" {
    std.testing.refAllDecls(AnsiBackend);
}
