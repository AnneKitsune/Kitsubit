const CharacterSlot = struct {
    char: u8 = ' ', // ascii TODO support utf8
    color_index: u8 = colorIndex(.white, .black),
};

char_buffer: MultiArrayList(CharacterSlot),
size_x: usize = 0,
size_y: usize = 0,
alloc: std.mem.Allocator,
opts: Options,

// Backend field with compile-time type selection
backend: selectBackend(),
// Logging scope for terminal renderer
log_scope: log.LogScope,
