const std = @import("std");
const rl = @import("raylib");

alloc: std.mem.Allocator = undefined,
cube: std.ArrayList([]CubeColor) = undefined,
neighbors: []Neighbors = undefined,
size: usize,

pub const RubikCube = @This();

const Neighbors = struct {
    color: CubeColor,
    startIndex: i64, // starting index in the face
    step: i64, // step in the rotation
    pub fn new(color: CubeColor, startIndex: i64, step: i64) Neighbors {
        return Neighbors{ .color = color, .startIndex = startIndex, .step = step };
    }
    pub fn getIndex(self: Neighbors) usize {
        return @intFromEnum(self.color);
    }
};

const CubeColor = enum(u3) {
    White = 0,
    Blue = 1,
    Yellow = 2,
    Green = 3,
    Orange = 4,
    Red = 5,
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
    if (size <= 1) {
        return error.OutOfRange;
    }
    var c: RubikCube = .{
        .alloc = allocator,
        .size = size,
        .cube = try std.ArrayList([]CubeColor).initCapacity(allocator, 6),
        // 6 faces com 4 vizinhos
        .neighbors = try allocator.alloc(Neighbors, 6 * 4),
    };
    const l = @typeInfo(CubeColor).@"enum".fields.len;
    for (0..l) |i| {
        // Initialize each face of the cube with a specific color
        const face: []CubeColor = try allocator.alloc(CubeColor, size * size);
        @memset(face, @enumFromInt(i));
        c.cube.append(face) catch return error.OutOfMemory;
    }
    const N: i64 = @intCast(size);
    // Define neighbors for white, blue, yellow, green, red, and orange faces

    @memset(c.neighbors, .{
        .color = undefined,
        .startIndex = 0,
        .step = 0,
    });
    // vizinhos do branco
    c.neighbors[0] = Neighbors.new(.Orange, 0, N);
    c.neighbors[1] = Neighbors.new(.Blue, 0, N);
    c.neighbors[2] = Neighbors.new(.Red, 0, N);
    c.neighbors[3] = Neighbors.new(.Green, N * N - 1, -N);
    // vizinhos do azul
    c.neighbors[4] = Neighbors.new(.Orange, N * (N - 1), 1);
    c.neighbors[5] = Neighbors.new(.Yellow, 0, N);
    c.neighbors[6] = Neighbors.new(.Red, N - 1, -1);
    c.neighbors[7] = Neighbors.new(.White, N * N - 1, -N);
    // vizinhos do amarelo
    c.neighbors[8] = Neighbors.new(.Orange, N * N - 1, -N);
    c.neighbors[9] = Neighbors.new(.Green, 0, N);
    c.neighbors[10] = Neighbors.new(.Red, N * N - 1, -N);
    c.neighbors[11] = Neighbors.new(.Blue, N * N - 1, -N);
    // vizinhos do verde
    c.neighbors[12] = Neighbors.new(.Orange, N - 1, -1);
    c.neighbors[13] = Neighbors.new(.White, 0, N);
    c.neighbors[14] = Neighbors.new(.Red, N * (N - 1), 1);
    c.neighbors[15] = Neighbors.new(.Yellow, N * N - 1, -N);
    // vizinhos do laranja
    c.neighbors[16] = Neighbors.new(.Green, N - 1, -1);
    c.neighbors[17] = Neighbors.new(.Yellow, N - 1, -1);
    c.neighbors[18] = Neighbors.new(.Blue, N - 1, -1);
    c.neighbors[19] = Neighbors.new(.White, N - 1, -1);
    // vizinhos do vermelho
    c.neighbors[20] = Neighbors.new(.Blue, N * (N - 1), 1);
    c.neighbors[21] = Neighbors.new(.Yellow, N * (N - 1), 1);
    c.neighbors[22] = Neighbors.new(.Green, N * (N - 1), 1);
    c.neighbors[23] = Neighbors.new(.White, N * (N - 1), 1);

    return c;
}
pub fn getNeighbors(self: *RubikCube, face: CubeColor) []Neighbors {
    const neighborStartIndex: usize = @as(usize, @intFromEnum(face)) * 4;
    std.debug.assert(neighborStartIndex + 4 <= self.neighbors.len);
    return self.neighbors[neighborStartIndex .. neighborStartIndex + 4];
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
pub fn processInput(self: *RubikCube) !void {
    const clockwise: bool = !rl.isKeyDown(rl.KeyboardKey.left_shift);
    var key: rl.KeyboardKey = rl.getKeyPressed();
    // apenas face branca implementada
    while (key != .null) : (key = rl.getKeyPressed()) {
        switch (key) {
            .l => try self.faceRotate(.White, clockwise),
            .f => try self.faceRotate(.Blue, clockwise),
            .r => try self.faceRotate(.Yellow, clockwise),
            .b => try self.faceRotate(.Green, clockwise),
            .u => try self.faceRotate(.Orange, clockwise),
            .d => try self.faceRotate(.Red, clockwise),
            //todo implementar rotações centrais
            .h => {},
            .v => {},
            .s => {},
            // numeric keys to implement middle layer rotations
            .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine => {},
            .kp_0, .kp_1, .kp_2, .kp_3, .kp_4, .kp_5, .kp_6, .kp_7, .kp_8, .kp_9 => {},
            else => {},
        }
    }
}

// rotaciona a face
fn faceRotate(self: *RubikCube, face: CubeColor, clockwise: bool) !void {
    const cf = self.cube.items[@intFromEnum(face)];
    const buffer: []CubeColor = try self.alloc.dupe(CubeColor, cf);
    defer self.alloc.free(buffer);
    const N = self.size;
    if (clockwise) {
        // Rotate clockwise
        for (0..N) |i| {
            for (0..N) |j| {
                const new_i = j;
                const new_j = N - 1 - i;
                cf[new_i * N + new_j] = buffer[i * N + j];
            }
        }
    } else {
        // Rotate counter-clockwise
        for (0..N) |i| {
            for (0..N) |j| {
                const new_i = N - 1 - j;
                const new_j = i;
                cf[new_i * N + new_j] = buffer[i * N + j];
            }
        }
    }
    try self.rotateNeighbors(face, clockwise);
}
fn rotateNeighbors(self: *RubikCube, face: CubeColor, clockwise: bool) !void {
    const neighbors: []Neighbors = self.getNeighbors(face);
    // assegura que cada face tem 4 vizinhos
    std.debug.assert(neighbors.len == 4);
    if (clockwise) {
        try self.swapNeighbor(&neighbors[0], &neighbors[3]);
        try self.swapNeighbor(&neighbors[3], &neighbors[2]);
        try self.swapNeighbor(&neighbors[2], &neighbors[1]);
    } else {
        try self.swapNeighbor(&neighbors[0], &neighbors[1]);
        try self.swapNeighbor(&neighbors[1], &neighbors[2]);
        try self.swapNeighbor(&neighbors[2], &neighbors[3]);
    }
}
//rotaciona os vizinhos
fn swapNeighbor(self: *RubikCube, n1: *Neighbors, n2: *Neighbors) !void {
    var temp: CubeColor = undefined;

    for (0..self.size) |i| {
        const di: usize = @intCast(@as(i64, @intCast(i)) * n2.step + n2.startIndex);
        const oi: usize = @intCast(@as(i64, @intCast(i)) * n1.step + n1.startIndex);
        temp = self.cube.items[n1.getIndex()][oi];
        self.cube.items[n1.getIndex()][oi] = self.cube.items[n2.getIndex()][di];
        self.cube.items[n2.getIndex()][di] = temp;
    }
}
