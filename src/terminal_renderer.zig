const renderer = @import("terminal_renderer/term_renderer.zig");
pub const Renderer = renderer.TerminalRenderer;
pub const PrintOptions = renderer.PrintOptions;
pub const Color = @import("terminal_renderer/ansi_colors.zig").Color;

test "import" {
    //_ = @import("terminal_renderer/ansi_colors.zig");
    //_ = @import("terminal_renderer/ansi_cursor.zig");
    //_ = @import("terminal_renderer/ansi_screen.zig");
    //_ = @import("terminal_renderer/raw_term.zig");
    _ = @import("terminal_renderer/term_renderer.zig");
    //_ = @import("terminal_renderer/term_size.zig");
}
