const std = @import("std");
const testing = std.testing;

// Color indices use the following bit pattern: brightbg bg bg bg brightfg fg fg fg

/// Array containing the ansi code to change the color for each of the color indices.
pub const COLOR_CODES = block: {
    var arr: [256][10:0]u8 = undefined;
    var i = 0;
    while (i < 256) : (i += 1) {
        const fg_offset = if (i & 0b1000 > 0) 90 else 30;
        const bg_offset = if (i & 0b10000000 > 0) 100 else 40;
        const fg = (i & 0b0111) + fg_offset;
        const bg = ((i & 0b01110000) >> 4) + bg_offset;
        // NOTE: Using bufPrintZ instead of directly writing into the array noticeably slows down the compiler.
        _ = std.fmt.bufPrintZ(&arr[i], "\x1B[{};{}m", .{ fg, bg }) catch {
            @compileError("");
        };
    }
    break :block arr;
};

/// Array containing the ansi code apply the legacy text attributes for each of the color indices.
pub const LEGACY_CODES = block: {
    var arr: [256][7:0]u8 = undefined;
    var i = 0;
    while (i < 256) : (i += 1) {
        if (i & 0b10001000 == 0b10001000) {
            // Bright fg and bg
            _ = std.fmt.bufPrintZ(&arr[i], "\x1B[1;5m", .{}) catch {
                @compileError("");
            };
        } else if (i & 0b10000000 > 0) {
            // Bright bg
            _ = std.fmt.bufPrintZ(&arr[i], "\x1B[5m", .{}) catch {
                @compileError("");
            };
        } else if (i & 0b1000 > 0) {
            // Bright fg
            _ = std.fmt.bufPrintZ(&arr[i], "\x1B[1m", .{}) catch {
                @compileError("");
            };
        } else {
            _ = std.fmt.bufPrintZ(&arr[i], "", .{}) catch {
                @compileError("");
            };
        }
    }
    break :block arr;
};

/// The ansi code to reset the text attributes and colors.
pub const RESET_CODE = "\x1B[0m";

/// Defines the color values of the 16 different colors available in the linux console.
pub const Color = enum(u8) {
    black = 0,
    red_dark = 1,
    green_dark = 2,
    brown = 3,
    blue_dark = 4,
    magenta_dark = 5,
    cyan_dark = 6,
    gray = 7,
    gray_dark = 8,
    red = 9,
    green = 10,
    yellow = 11,
    blue = 12,
    magenta = 13,
    cyan = 14,
    white = 15,
};

/// # Color Reset
/// ## Description
/// Writes the ansi code to fully reset the text attributes into the provided buffer.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn color_reset(buffer: [*]u8, buffer_len: usize) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "{s}", .{RESET_CODE}) catch {
        return 0;
    }).len - 1;
}

/// # Color Code
/// ## Description
/// Writes the ansi code to change the color to the specified color pair index into the provided buffer.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn color_code(buffer: [*]u8, buffer_len: usize, color_pair: u8) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "{s}", .{COLOR_CODES[color_pair]}) catch {
        return 0;
    }).len - 1;
}

/// # Color Legacy
/// ## Description
/// Writes the ansi code to apply the previous color change using legacy text attributes into the provided buffer.
/// The legacy code should be written after the color change from color_code/3.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn color_legacy(buffer: [*]u8, buffer_len: usize, color_pair: u8) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "{s}", .{LEGACY_CODES[color_pair]}) catch {
        return 0;
    }).len - 1;
}

/// # Color Index
/// ## Description
/// Calculates the color index for the specified foreground and background colors.
/// The legacy code should be written after theh color change from color_code/3.
/// ## Returns
/// The color index to be used with other functions of this library or the code arrays.
pub export fn color_index(foreground: Color, background: Color) u8 {
    return @intFromEnum(foreground) | (@intFromEnum(background) << 4);
}

//test "Write all colors non-legacy C" {
//    var stdout = std.io.getStdOut();
//    var writer = stdout.writer();
//    var i = @as(u16, 0);
//    while (i < 256) : (i += 1) {
//        var buf1: [100]u8 = undefined;
//        var buf2: [100]u8 = undefined;
//        const color = color_index(@as(Color, @enumFromInt(i % 16)), @as(Color, @enumFromInt(i / 16)));
//        const len1 = color_code(&buf1, buf1.len, color);
//        const len2 = color_reset(&buf2, buf2.len);
//        if (i % 16 == 0) {
//            try writer.print("\n", .{});
//        }
//        try writer.print("{s}a{s}", .{ buf1[0..len1], buf2[0..len2] });
//    }
//}
//
//test "Write all colors legacy C" {
//    var stdout = std.io.getStdOut();
//    var writer = stdout.writer();
//    var i = @as(u16, 0);
//    while (i < 256) : (i += 1) {
//        var buf1: [100]u8 = undefined;
//        var buf2: [100]u8 = undefined;
//        const color = color_index(@as(Color, @enumFromInt(i % 16)), @as(Color, @enumFromInt(i / 16)));
//        const len1 = color_code(&buf1, buf1.len, color);
//        const len2 = color_legacy(@as([*]u8, @ptrCast(buf1[len1..])), buf1.len - len1, color);
//        const len3 = color_reset(&buf2, buf2.len);
//        if (i % 16 == 0) {
//            try writer.print("\n", .{});
//        }
//        try writer.print("{s}a{s}", .{ buf1[0..(len1 + len2)], buf2[0..len3] });
//    }
//}

// Color indices use the following bit pattern: brightbg bg bg bg brightfg fg fg fg
test "Bright yellow" {
    var buf: [100]u8 = undefined;
    const len = color_code(&buf, buf.len, 0b00001010);
    try testing.expectEqualStrings("[92;40m", buf[1 .. len - 1]);
}

//test "Write all colors legacy Zig" {
//    var stdout = std.io.getStdOut();
//    var writer = stdout.writer();
//    var i = @as(u16, 0);
//    while (i < 256) : (i += 1) {
//        if (i % 16 == 0) {
//            try writer.print("\n", .{});
//        }
//        try writer.print("{s}{s}a{s}", .{ COLOR_CODES[i], LEGACY_CODES[i], RESET_CODE });
//    }
//}
