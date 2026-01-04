pub fn Vec2(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        const S = @This();
    };
}

pub const Dimension2 = Vec2;
pub const Position2 = Vec2;
