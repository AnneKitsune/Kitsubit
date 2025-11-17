const kitsubit = @import("kitsubit");
const c = kitsubit.c;

// https://github.com/devkitPro/calico/blob/master/include/calico/gba/keypad.h
const KEY_LID = c.KEY_LID;
const KEY_TOUCH = 1 << 13;

fn clear() void {
    c.consoleClear();
}

export fn main() void {
    _ = c.videoSetMode(c.MODE_0_2D);
    _ = c.videoSetModeSub(c.MODE_0_2D);

    _ = c.vramSetBankA(c.VRAM_A_MAIN_BG);
    _ = c.vramSetBankC(c.VRAM_C_SUB_BG);

    _ = c.dmaFillHalfWords(0, c.VRAM_A, 128 * 1024);
    _ = c.setBackdropColor(c.RGB15(0, 0, 0));

    var top_screen: c.PrintConsole = undefined;
    var bottom_screen: c.PrintConsole = undefined;
    _ = c.consoleInit(&top_screen, 3, c.BgType_Text4bpp, c.BgSize_T_256x256, 31, 0, true, true);
    _ = c.consoleInit(&bottom_screen, 3, c.BgType_Text4bpp, c.BgSize_T_256x256, 31, 0, false, true);

    _ = c.consoleSelect(&top_screen);
    _ = c.iprintf("Hello World!\n");
    _ = c.consoleSelect(&bottom_screen);
    _ = c.iprintf("   \x1b[32mKitsubit by AnneKitsune\n\n\x1b[39m");

    // print line
    _ = c.iprintf("\x1B[10;0f");
    const width: usize = @intCast(bottom_screen.consoleWidth);
    for (0..width) |x| {
        if (x == 0 or (width > 0 and x == width - 1)) {
            _ = c.printf("+");
        } else {
            _ = c.printf("-");
        }
    }
    _ = c.printf("\n");

    // setup input
    // args: delay before start repeat, modulo between repeats
    c.keysSetRepeat(5, 5);

    var frame: u32 = 0;
    while (c.pmMainLoop()) {

        // frame print
        _ = c.iprintf("\x1B[9;4f%i    ", frame);
        frame = (frame + 1) % 0xFFFF;

        // input processor
        c.scanKeys();
        const keys_down = c.keysDown();
        const keys_held = c.keysHeld();
        const keys_repeat = c.keysDownRepeat();
        const keys_up = c.keysUp();
        // press down event
        _ = c.iprintf("\x1B[11;0fdown: %i     ", keys_down);
        // currently down
        _ = c.iprintf("\x1B[12;0fheld: %i     ", keys_held);
        // held down over threshold time
        _ = c.iprintf("\x1B[13;0frepe: %i     ", keys_repeat);
        // released event
        _ = c.iprintf("\x1B[14;0fup  : %i     ", keys_up);

        // touchpad
        var touch_data: c.TouchData = undefined;
        const touched = c.touchRead(&touch_data);
        if (touched) {
            _ = c.iprintf("\x1B[15;0ftouch: %i,%i     ", touch_data.px, touch_data.py);
        } else {
            _ = c.iprintf("\x1B[15;0ftouch: n/a     ");
        }

        // line render
        //c.glBegin2D();
        //c.glBox(10, 10, 20, 20, 0xAAAA);
        //c.glEnd2D();

        c.swiWaitForVBlank();
    }
}
