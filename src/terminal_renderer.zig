const renderer = @import("terminal_renderer/term_renderer.zig");
pub const Renderer = renderer.TerminalRenderer;
pub const TerminalBackendAnsi = @import("terminal_renderer/backends/ansi.zig").AnsiBackend;
pub const TerminalBackendNds = @import("terminal_renderer/backends/nds.zig").NdsBackend;
pub const TerminalBackendNull = @import("terminal_renderer/backends/null.zig").NullBackend;

test "import" {
    //_ = @import("terminal_renderer/ansi_colors.zig");
    //_ = @import("terminal_renderer/ansi_cursor.zig");
    //_ = @import("terminal_renderer/ansi_screen.zig");
    //_ = @import("terminal_renderer/raw_term.zig");
    _ = @import("terminal_renderer/term_renderer.zig");
    _ = @import("terminal_renderer/backends/ansi.zig");
    _ = @import("terminal_renderer/backends/nds.zig");
    _ = @import("terminal_renderer/backends/null.zig");
    //_ = @import("terminal_renderer/term_size.zig");
}
