const std = @import("std");
const testing = std.testing;

/// The static string representing the ansi code to hide the cursor.
pub const CURSOR_HIDE = "\x1B[?25l";
/// The static string representing the ansi code to show the cursor.
pub const CURSOR_SHOW = "\x1B[?25h";
pub const CURSOR_MOVE_FORMAT = "\x1B[{};{}f";

/// # Cursor Move
/// ## Description
/// Writes the ansi code into the provided buffer to move the cursor to the provided x and y location.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn cursor_move(buffer: [*]u8, buffer_len: usize, x: u32, y: u32) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "\x1B[{};{}f", .{ y, x }) catch {
        return 0;
    }).len;
}

/// # Cursor Hide
/// ## Description
/// Writes the ansi code to make the cursor invisible into the provided buffer.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn cursor_hide(buffer: [*]u8, buffer_len: usize) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "{s}", .{CURSOR_HIDE}) catch {
        return 0;
    }).len;
}

/// # Cursor Show
/// ## Description
/// Writes the ansi code to make the cursor visible into the provided buffer.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn cursor_show(buffer: [*]u8, buffer_len: usize) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "{s}", .{CURSOR_SHOW}) catch {
        return 0;
    }).len;
}

//test "Move cursor to 0,999" {
//    var buffer: [100:0]u8 = undefined;
//    const c = cursor_move(&buffer, buffer.len, 0, 999);
//    buffer[c] = 0;
//    try testing.expect(c > 0);
//    try std.io.getStdOut().writer().print("{s}", .{buffer});
//}
