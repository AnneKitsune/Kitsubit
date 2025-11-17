const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const windows = std.os.windows;

// https://learn.microsoft.com/en-us/windows/console/setconsolemode
const WFLAGS: windows.DWORD = 0x0002 | 0x0004;

pub extern "kernel32" fn SetConsoleMode(console_handle: ?*anyopaque, dw_mode: windows.DWORD) callconv(windows.WINAPI) ?*void;

fn setIflag(flags: *std.posix.tc_iflag_t, value: bool) void {
    flags.BRKINT = value;
    flags.ICRNL = value;
    flags.INPCK = value;
    flags.ISTRIP = value;
    flags.IXON = value;
}
fn setOflag(flags: *std.posix.tc_oflag_t, value: bool) void {
    flags.OPOST = value;
}
fn setLflag(flags: *std.posix.tc_lflag_t, value: bool) void {
    flags.ECHO = value;
    flags.ICANON = value;
    flags.IEXTEN = value;
    flags.ISIG = value;
}

/// Enables the flags required to turn a linux terminal to it's "raw mode".
pub export fn enable_raw_mode() bool {
    switch (builtin.os.tag) {
        .macos, .linux, .freebsd, .netbsd, .openbsd => {
            var term = std.posix.tcgetattr(std.posix.STDIN_FILENO) catch {
                return false;
            };
            setIflag(&term.iflag, false);
            setOflag(&term.oflag, false);
            setLflag(&term.lflag, false);
            std.posix.tcsetattr(std.posix.STDIN_FILENO, std.posix.TCSA.FLUSH, term) catch {
                return false;
            };
        },
        .windows => {
            const handle = windows.GetStdHandle(windows.STD_INPUT_HANDLE) catch {
                return false;
            };
            var mode: windows.DWORD = 0;
            _ = windows.kernel32.GetConsoleMode(handle, &mode);
            _ = SetConsoleMode(handle, mode | ~WFLAGS);
        },
        else => @compileError("Unsupported platform"),
    }
    return true;
}

/// Disables the linux terminal "raw mode".
pub export fn disable_raw_mode() bool {
    switch (builtin.os.tag) {
        .macos, .linux, .freebsd, .netbsd, .openbsd => {
            var term = std.posix.tcgetattr(std.posix.STDIN_FILENO) catch {
                return false;
            };
            setIflag(&term.iflag, true);
            setOflag(&term.oflag, true);
            setLflag(&term.lflag, true);
            std.posix.tcsetattr(std.posix.STDIN_FILENO, std.posix.TCSA.FLUSH, term) catch {
                return false;
            };
        },
        .windows => {
            const handle = windows.GetStdHandle(windows.STD_INPUT_HANDLE) catch {
                return false;
            };
            var mode: windows.DWORD = 0;
            _ = windows.kernel32.GetConsoleMode(handle, &mode);
            _ = SetConsoleMode(handle, mode | WFLAGS);
        },
        else => @compileError("Unsupported platform"),
    }
    return true;
}

//test "basic functionality" {
//try testing.expect(enable_raw_mode());
//try testing.expect(disable_raw_mode());
//}
