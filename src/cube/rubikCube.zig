const std = @import("std");
const rl = @import("raylib");

alloc: std.mem.Allocator = undefined,
// cube: []u3 = undefined,
cube: std.ArrayList([]CubeColor) = undefined,
size: usize,

pub const RubikCube = @This();

const CubeColor = enum(u3) {
    White = 0,
    Blue = 1,
    Yellow = 2,
    Green = 3,
    Red = 4,
    Orange = 5,
    pub fn getColor(self: CubeColor) rl.Color {
        return switch (self) {
            .White => .white,
            .Yellow => .yellow,
            .Blue => .blue,
            .Green => .green,
            .Red => .red,
            .Orange => .orange,
        };
    }
};

pub fn Init(allocator: std.mem.Allocator, size: usize) !RubikCube {
    var c: RubikCube = .{
        .alloc = allocator,
        .size = size,
        .cube = try std.ArrayList([]CubeColor).initCapacity(allocator, 6),
    };
    const l = @typeInfo(CubeColor).@"enum".fields.len;
    for (0..l) |i| {
        // Initialize each face of the cube with a specific color
        const face: []CubeColor = try allocator.alloc(CubeColor, size * size);
        @memset(face, @enumFromInt(i));
        c.cube.append(face) catch return error.OutOfMemory;
    }
    return c;
}
pub fn deinit(self: *RubikCube) void {
    if (self.cube) |c| {
        self.alloc.free(c);
    }
}

pub fn draw2d(self: RubikCube) !void {
    const sw: usize = @intCast(rl.getScreenWidth());
    const sh: usize = @intCast(rl.getScreenHeight());
    const my: usize = @divExact(sh, 2);

    const faceSize: usize = @divFloor(sw, (self.size * 4));
    const startY: usize = my - (faceSize * @divTrunc(self.size, 2));
    const startX: usize = 0;

    for (self.cube.items, 0..) |face, i| {
        for (face, 0..) |value, j| {
            var x: usize = startX + @rem(j, self.size) * faceSize;
            var y: usize = startY + (@divTrunc(j, self.size) * faceSize);
            switch (i) {
                0...3 => {
                    x += (i * self.size * faceSize);
                },
                4...5 => {
                    x += (self.size * faceSize);
                    if (i & 1 == 1)
                        y += (self.size * faceSize)
                    else
                        y -= (self.size * faceSize);
                },
                else => unreachable,
            }
            rl.drawRectangle(@intCast(x), @intCast(y), @intCast(faceSize), @intCast(faceSize), value.getColor());
            rl.drawRectangleLines(@intCast(x), @intCast(y), @intCast(faceSize), @intCast(faceSize), rl.Color.black);
        }
    }
}
pub fn rotate(self: *RubikCube) void {
    // falta criar número a partir de sequência de teclas? talvez desnecessário!
    const clockwise: bool = !rl.isKeyDown(rl.KeyboardKey.left_shift);
    var key: rl.KeyboardKey = rl.getKeyPressed();
    // std.debug.print("Press any key to rotate the cube, or ESC to exit...\n", .{});
    while (key != .null) : (key = rl.getKeyPressed()) {
        std.debug.print("key :{}, {}\n", .{ key, clockwise });
        switch (key) {
            .r => {},
            .l => {},
            .f => {},
            .b => {},
            .u => {},
            .d => {},
            .h => {},
            .v => {},
            .s => {},
            // rl.KeyboardKey.l => {},
            // rl.KeyboardKey.f => {},
            // rl.KeyboardKey.b => {},
            // rl.KeyboardKey.t => {},
            // rl.KeyboardKey.b => {},
            else => {},
        }

        var bf = @intFromEnum(key);
        // const char: u8 = @truncate(bf);
        if (bf >= @intFromEnum(rl.KeyboardKey.zero) and bf <= @intFromEnum(rl.KeyboardKey.nine)) {
            bf -= @intFromEnum(rl.KeyboardKey.zero); // Convert ASCII digit to integer
        } else if (bf >= @intFromEnum(rl.KeyboardKey.kp_0) and bf <= @intFromEnum(rl.KeyboardKey.kp_9)) {
            bf -= @intFromEnum(rl.KeyboardKey.kp_0); // Convert keypad digit to integer
        }
        // const char: usize = @intCast(bf);
        const ctrunc: u8 = @truncate(@as(usize, @intCast(bf)));
        const isDigit = std.ascii.isDigit(ctrunc + 48);
        std.debug.print("Pressed key: {d}, char: {d}, digit?: {}\n", .{ bf, ctrunc, isDigit });
        _ = self;
    }
}
