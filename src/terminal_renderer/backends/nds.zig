const vector = @import("../../math/vector.zig");

const TerminalRenderer = @import("../term_renderer.zig").TerminalRenderer;
const Color = @import("../../color.zig").Color;
const TextStyle = @import("../../text/style.zig").TextStyle;
const Position2 = vector.Position2;
const Dimension2 = vector.Dimension2;

const c = @import("../../root.zig").c;

pub const NdsBackend = struct {
    size: Dimension2(u16) = .{ .x = 0, .y = 0 },
    screen: c.PrintConsole,

    const S = @This();

    pub const Options = struct {
        /// true: top screen
        /// false: bottom screen
        top_screen: bool,
    };

    pub fn init(opts: Options) S {
        _ = c.videoSetMode(c.MODE_0_2D);
        _ = c.videoSetModeSub(c.MODE_0_2D);

        _ = c.vramSetBankA(c.VRAM_A_MAIN_BG);
        _ = c.vramSetBankC(c.VRAM_C_SUB_BG);

        _ = c.dmaFillHalfWords(0, c.VRAM_A, 128 * 1024);
        _ = c.setBackdropColor(c.RGB15(0, 0, 0));

        var screen: c.PrintConsole = undefined;
        _ = c.consoleInit(&screen, 3, c.BgType_Text4bpp, c.BgSize_T_256x256, 31, 0, opts.top_screen, true);

        return .{
            .screen = screen,
        };
    }

    pub fn deinit(s: *S) void {
        _ = s;
    }

    pub fn renderer(s: *S) TerminalRenderer {
        return .{
            .backend_ptr = s,
            .vtable = comptime &.{
                .write = write,
                .setSize = setSize,
                .flush = flush,
            },
        };
    }

    pub fn write(ctx: *anyopaque, x: u16, y: u16, fg_color: Color, bg_color: Color, style: TextStyle, text: [:0]const u8) !void {
        const s: *S = @ptrCast(@alignCast(ctx));
        _ = fg_color;
        _ = bg_color;
        // TODO check if we can handle style at all
        _ = style;

        // select top or bottom screen
        // TODO find a way to remove this call when writing multiple time to the same screen??
        _ = c.consoleSelect(&s.screen);

        // set position
        _ = c.iprintf("\x1B[%d;%df", y, x);

        // print text
        _ = c.iprintf(text);

        // TODO colors
        //_ = c.iprintf("   \x1b[32mKitsubit by AnneKitsune\n\n\x1b[39m");
    }

    /// Does not support changing the terminal size.
    pub fn setSize(ctx: *anyopaque, new_size: ?Dimension2(u16)) !Dimension2(u16) {
        if (new_size) |new| {
            _ = new;
            @panic("Cannot change the size on Nds.");
        }

        const s: *S = @ptrCast(@alignCast(ctx));

        return .{
            .x = @intCast(s.screen.consoleWidth),
            .y = @intCast(s.screen.consoleHeight),
        };
    }

    pub fn flush(ctx: *anyopaque, clear: bool) !void {
        const s: *S = @ptrCast(@alignCast(ctx));
        // select top or bottom screen
        _ = c.consoleSelect(&s.screen);

        c.swiWaitForVBlank();
        if (clear) {
            c.consoleClear();
        }
    }
};
