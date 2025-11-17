const std = @import("std");
const testing = std.testing;

/// The ansi code to erase the screen content.
pub const SCREEN_ERASE = "\x1B[2J";

/// # Screen Erase
/// ## Description
/// Writes the ansi code to completely erase all text content on screen.
/// ## Returns
/// The number of bytes written.
/// ## Errors
/// Returns zero if there was insufficient space in the buffer. It might or might not have written bytes into it.
pub export fn screen_erase(buffer: [*]u8, buffer_len: usize) usize {
    return (std.fmt.bufPrint(buffer[0..buffer_len], "{s}", .{SCREEN_ERASE}) catch {
        return 0;
    }).len;
}

test "Erase screen" {
    var buf: [100]u8 = undefined;
    const len = screen_erase(&buf, buf.len);
    _ = len;
    //try std.io.getStdOut().writer().print("{s}", .{buf[0..len]});
}
