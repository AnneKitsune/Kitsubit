const std = @import("std");
const db = @import("db.zig");

// state { dispatcher, inputcontext }. enter(); update(); quit();
// state auto pushes inputcontext on top of the resource and pops on quit (in state manager, when you push or pop a state it runs.)

pub const InputEvent = struct {
    keycode: u7,
};
pub const InputEvents = db.Table(InputEvent, null, db.EventProps);

/// Alias for a Table. If generated, the keymap will not be loaded or saved.
/// If not generated and a filename is provided, they keymap will be loaded and saved (but the event type must be serializable!)
/// Also, a KeyMap will use the Table's UUID as the key press keycode.
/// This means that the Table's key will always be between [0, 127] for keymaps.
pub fn KeyMap(comptime event: type, filename: ?[]const u8, comptime generated: bool) type {
    if (generated) {
        return db.Table(event, null, db.ResourceProps);
    } else {
        return db.Table(event, filename, db.ConfigProps);
    }
}

/// A bitset indicating which input contexts are active.
/// Usually stored in InputContextStack.
pub fn InputContext(comptime contexts: type) type {
    //return std.StaticBitSet(@typeInfo(contexts).Enum.fields.len);
    return std.StaticBitSet(@bitSizeOf(contexts));
}

/// A stack of input contexts.
/// Designed this way instead of having a single input contexts, because you might want to open an options menu while in game and not lose your game's input context.
/// This neatly solves the problem; simply push the options menu's context on top and pop it once you leave the menu!
pub fn InputContextStack(comptime contexts: type) type {
    return struct {
        input_contexts: std.ArrayList(InputContext(contexts)),
        const S = @This();

        pub fn init(allocator: std.mem.Allocator) S {
            return S{
                .input_contexts = std.ArrayList(InputContext(contexts)).init(allocator),
            };
        }

        pub fn deinit(s: *S) void {
            s.input_contexts.deinit();
        }

        // can be used by states to track how many the need to pop when they get popped from the state stack.
        pub fn count(s: *const S) usize {
            return s.input_contexts.len;
        }

        pub fn push(s: *S, bitset: InputContext(contexts)) !void {
            try s.input_contexts.append(bitset);
        }

        pub fn pop(s: *S) void {
            std.debug.assert(s.input_contexts.items.len > 0);
            _ = s.input_contexts.pop();
        }

        pub fn get(s: *const S) *const InputContext(contexts) {
            std.debug.assert(s.input_contexts.items.len > 0);
            return &s.input_contexts.items[s.input_contexts.items.len - 1];
        }

        pub fn getMut(s: *S) *InputContext(contexts) {
            std.debug.assert(s.input_contexts.items.len > 0);
            return &s.input_contexts.items[s.input_contexts.items.len - 1];
        }
    };
}

/// This function will generate a system that converts a keyboard input event into a game-specific event.
/// To do so, it will first verify the InputContextStack resource and compare with the provided `context` value.
/// If the provided context is currently enabled, the system will proceed.
/// Then, it will use the provided keymap table to find a matching event for the keyboard input keycode.
/// If it finds one, it will insert it into the events table.
///
/// ### Parameters
/// Context must be a variant of the game's input context enum.
/// This input context enum must match the one provided to the InputContextStack resource.
/// The generated system can be accessed using genKeyMapSystem(...).system.
pub fn genKeyMapSystem(comptime context: anytype, comptime keymap_table: type, comptime events_table: type) type {
    return struct {
        const context_enum = @TypeOf(context); // not sure if this is gonna work.
        pub fn system(input_context_stack: *const InputContextStack(context_enum), inputs: *const InputEvents, keymap: *const keymap_table, events: *events_table) !void {
            if (!input_context_stack.get().isSet(@intFromEnum(context))) {
                return;
            }

            for (inputs.values()) |input_event| {
                const keycode = input_event.keycode;
                if (keymap.get(.{ .value = keycode })) |mapped_event| {
                    _ = try events.add(mapped_event);
                }
            }
        }
    };
}

// TODO move to ui
pub const KeyMapTextBox = KeyMap(EventTextBox, null, true);
pub fn generateKeyMapTextBox(alloc: *std.mem.Allocator) !KeyMapTextBox {
    var keymap = KeyMapTextBox.init(alloc);
    try keymap.addWithKey(27, .{ .escape = {} });
    try keymap.addWithKey(8, .{ .backspace = {} });
    try keymap.addWithKey(127, .{ .delete = {} });
    try keymap.addWithKey(10, .{ .confirm = {} });
    for (32..127) |keycode| {
        try keymap.addWithKey(keycode, .{ .key = keycode });
    }
    return keymap;
}

// TODO move to ui
pub const EventTextBox = union(enum) {
    key: u7,
    escape: void,
    backspace: void,
    delete: void,
    confirm: void,
};

// ------ Tests Start

const comp = @import("comptime.zig");
const Dispatcher = @import("dispatcher.zig").Dispatcher;

const EventTest = enum {
    one,
    two,
};
const EventTests = db.Table(EventTest, null, db.EventProps); // careful here. if you set db.ConfigProps or db.ResourceProps, you risk having EventTests = KeyMapTest.
const KeyMapTest = KeyMap(EventTest, null, true);

const TestInputContexts = enum(u64) {
    walking = 1,
    driving = 2,
    text_box = 4,
};

const test_world_types = &.{
    InputContextStack(TestInputContexts),
    KeyMapTest,
    EventTests,
    InputEvents,
};
const TestWorld: type = comp.AutoInitStruct(test_world_types);

const test_systems = .{
    genKeyMapSystem(TestInputContexts.walking, KeyMapTest, EventTests).system, // test system that maps only when we are in the walking context
    genKeyMapSystem(TestInputContexts.driving, KeyMapTest, EventTests).system, // test system that maps only when we are in the driving context
};

test "input system" {
    const dispatch_test = Dispatcher(test_systems){};
    var world = try TestWorld.init(std.testing.allocator);
    defer world.deinit();

    _ = try world.getMut(InputEvents).add(.{ .keycode = 0 });
    try world.getMut(KeyMapTest).addWithKey(.{ .value = 0 }, .two);

    var input_ctx = InputContext(TestInputContexts).initEmpty();
    input_ctx.set(@intFromEnum(TestInputContexts.walking)); // we are in the "walking" context
    try world.getMut(InputContextStack(TestInputContexts)).push(input_ctx);

    try dispatch_test.runSeq(&world.inner);

    const events = world.get(EventTests).values();
    try std.testing.expectEqual(1, events.len);
    try std.testing.expectEqual(EventTest.two, events[0]);
}
