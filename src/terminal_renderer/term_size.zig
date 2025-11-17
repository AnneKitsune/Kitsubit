const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;

const iocgwinsz = linux.T.IOCGWINSZ;

/// Gets the current terminal size and returns it in the arguments pointers.
/// Returns true if it succeeds.
pub export fn term_size(x: *usize, y: *usize) bool {
    while (true) {
        var wsz: linux.winsize = undefined;
        const fd = @as(usize, @bitCast(@as(isize, linux.STDOUT_FILENO)));
        const rc = linux.syscall3(.ioctl, fd, iocgwinsz, @intFromPtr(&wsz));
        switch (rc) {
            // SUCCESS
            0 => {
                x.* = @as(usize, @intCast(wsz.ws_col));
                y.* = @as(usize, @intCast(wsz.ws_row));
                return true;
            },
            // EINTR
            4 => continue,
            // Other errors, see errno -l or man errno(1)
            else => return false,
        }
    }
}

//test "Get a positive size" {
//var x: usize = 0;
//var y: usize = 0;
//try testing.expect(term_size(&x, &y));
//try testing.expect(x > 0);
//try testing.expect(y > 0);
//}
