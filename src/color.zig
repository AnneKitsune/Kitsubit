pub const ColorType = enum {
    ansi_terminal,
    color256,
    rgb,
    rgba,
    rgba16,
    rgbaf,
};

pub const Color = union(ColorType) {
    ansi_terminal: @import("terminal_renderer/ansi_colors.zig").Color,
    color256: u8,
    rgb: ColorRgb,
    rgba: ColorRgba,
    rgba16: ColorRgba16,
    rgbaf: ColorRgbaf,

    const S = @This();
    pub fn convert(s: *S, other_type: type) S {
        switch (other_type) {
            .ansi_terminal => {
                switch (s) {
                    .color256 => |from| {
                        if (s.color256 < 16) {
                            return .{ .color256 = from };
                        }
                        @panic("Unimplemented");
                    },
                }
            },
            else => @compileError("Unimplemented!"),
        }
    }
};

pub const ColorRgb = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const ColorRgba = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

pub const ColorRgba16 = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16 = 65535,
};

pub const ColorRgbaf = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,
};
