const kitsubit = @import("kitsubit");
const c = kitsubit.c;

// https://github.com/devkitPro/calico/blob/master/include/calico/gba/keypad.h
const KEY_LID = c.KEY_LID;
const KEY_TOUCH = 1 << 13;

export fn main() void {
    var backend_bottom = kitsubit.terminal_renderer.TerminalBackendNds.init(.{ .top_screen = false });
    defer backend_bottom.deinit();
    var renderer_bottom = backend_bottom.renderer();

    // setup input
    // args: delay before start repeat, modulo between repeats
    c.keysSetRepeat(5, 5);

    var frame: u32 = 0;
    while (c.pmMainLoop()) {
        // print header info
        renderer_bottom.goto(0, 0);
        renderer_bottom.print("Hello World!", .{}) catch {};
        renderer_bottom.goto(0, 1);
        renderer_bottom.print("\x1b[32mKitsubit by AnneKitsune\x1b[39m", .{}) catch {};

        // print line
        const screen_size = renderer_bottom.getSize() catch {
            return;
        };
        const width = screen_size.x;
        for (0..width) |x| {
            renderer_bottom.goto(@intCast(x), 10);
            if (x == 0 or (width > 0 and x == width - 1)) {
                renderer_bottom.print("+", .{}) catch {};
            } else {
                renderer_bottom.print("-", .{}) catch {};
            }
        }

        // frame print
        renderer_bottom.goto(4, 9);
        renderer_bottom.print("{}", .{frame}) catch {};
        frame = (frame + 1) % 0xFFFF;

        // input processor
        c.scanKeys();
        const keys_down = c.keysDown();
        const keys_held = c.keysHeld();
        const keys_repeat = c.keysDownRepeat();
        const keys_up = c.keysUp();
        // press down event
        renderer_bottom.goto(0, 11);
        renderer_bottom.print("down: {b:0>16}", .{keys_down}) catch {};
        renderer_bottom.goto(0, 12);
        renderer_bottom.print("held: {b:0>16}", .{keys_held}) catch {};
        renderer_bottom.goto(0, 13);
        renderer_bottom.print("repe: {b:0>16}", .{keys_repeat}) catch {};
        renderer_bottom.goto(0, 14);
        renderer_bottom.print("up  : {b:0>16}", .{keys_up}) catch {};

        // touchpad
        var touch_data: c.TouchData = undefined;
        const touched = c.touchRead(&touch_data);
        if (touched) {
            renderer_bottom.goto(0, 15);
            renderer_bottom.print("touch: {},{}", .{ touch_data.px, touch_data.py }) catch {};
        } else {
            renderer_bottom.goto(0, 15);
            renderer_bottom.print("touch: n/a     ", .{}) catch {};
        }

        // line render
        //c.glBegin2D();
        //c.glBox(10, 10, 20, 20, 0xAAAA);
        //c.glEnd2D();

        renderer_bottom.flush(true) catch {};
    }
}
