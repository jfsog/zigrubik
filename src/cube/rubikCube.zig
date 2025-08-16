const std = @import("std");
const rl = @import("raylib");

alloc: std.mem.Allocator = undefined,
cube: std.ArrayList([]CubeColor) = undefined,
neighbors: []Neighbors = undefined,
size: usize,
deslocationAcc: usize,
keyMovements: []const rl.KeyboardKey = &[_]rl.KeyboardKey{ .l, .f, .r, .b, .u, .d, .h, .v, .s },
rendermod: RenderMode = .RENDER_2D,

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

const RenderMode = enum { RENDER_2D, RENDER_3D };

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
        .deslocationAcc = 0,
    };
    const l = @typeInfo(CubeColor).@"enum".fields.len;
    for (0..l) |i| {
        // Initialize each face of the cube with a specific color
        const face: []CubeColor = try allocator.alloc(CubeColor, size * size);
        @memset(face, @enumFromInt(i));
        c.cube.append(face) catch return error.OutOfMemory;
    }
    const N: i64 = @intCast(size);

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

fn shuffle(self: *RubikCube) void {
    const possibleMoves: usize = (2 * 6) + 3 * (self.size - 2) * 2;
    const rand = std.crypto.random;
    for (0..1) |_| {
        const num: usize = rand.intRangeAtMost(usize, 0, possibleMoves);
        switch (num) {
            0...11 => {
                const key: rl.KeyboardKey = self.keyMovements[num % 6];
                const clockwise: bool = (num / 6) != 0;
                self.processKey(key, clockwise);
            },
            else => {
                var newNum = num - 12;
                const key: rl.KeyboardKey = self.keyMovements[6 + newNum % 3];
                newNum /= 3;
                const clockwise: bool = newNum / (self.size - 2) != 0;
                self.deslocationAcc = 1 + newNum % (self.size - 2);
                self.processKey(key, clockwise);
            },
        }
    }
}

pub fn getNeighbors(self: *RubikCube, face: CubeColor) []Neighbors {
    const neighborStartIndex: usize = @as(usize, @intFromEnum(face)) * 4;
    std.debug.assert(neighborStartIndex <= self.neighbors.len);
    std.debug.assert(neighborStartIndex + 4 <= self.neighbors.len);
    return self.neighbors[neighborStartIndex .. neighborStartIndex + 4];
}

pub fn deinit(self: *RubikCube) void {
    self.cube.deinit();
}

fn drawCube(self: *RubikCube) void {
    switch (self.rendermod) {
        .RENDER_2D => self.draw2d(),
        .RENDER_3D => self.draw3d(),
    }
}

fn draw2d(self: RubikCube) void {
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

fn draw3d(self: *RubikCube) void {
    const sw: usize = @intCast(rl.getScreenWidth());
    const sh: usize = @intCast(rl.getScreenHeight());

    const fsw: f32 = @floatFromInt(sw / 2);
    const fsh: f32 = @floatFromInt(sh / 2);

    const fsize: f32 = @floatFromInt(self.size);
    const center = rl.Vector2.init(fsw, fsh);
    const N: f32 = @as(f32, @min(fsw, fsh)) / (@as(f32, fsize) * 3);

    const dfc = [_]f32{ 210, 330, 450 };
    // from top l -> top r, botton r, botton l
    const trapezoidAngles = [_]f32{ -30, 30, 150 };

    var ps: [4]rl.Vector2 = undefined;
    for (0..3) |f| {
        switch (f) {
            // orange
            0 => {
                //n * N
                for (0..self.size) |i| {
                    for (0..self.size) |j| {
                        const fi: f32 = @floatFromInt(i);
                        const fj: f32 = @floatFromInt(j);

                        const tempV = moveVecToAngle(center, dfc[1], N * (fsize - fi - 1.0));
                        ps[0] = moveVecToAngle(tempV, dfc[f], N * (fsize - fj));
                        ps[1] = moveVecToAngle(ps[0], trapezoidAngles[0], N);
                        ps[2] = moveVecToAngle(ps[1], trapezoidAngles[1], N);
                        ps[3] = moveVecToAngle(ps[2], trapezoidAngles[2], N);
                        const color = self.cube.items[@intFromEnum(CubeColor.Orange)][self.size * i + j].getColor();
                        rl.drawTriangle(ps[0], ps[3], ps[2], color);
                        rl.drawTriangle(ps[2], ps[1], ps[0], color);

                        rl.drawLineEx(ps[0], ps[1], 5, rl.Color.black);
                        rl.drawLineEx(ps[1], ps[2], 5, rl.Color.black);
                        rl.drawLineEx(ps[2], ps[3], 5, rl.Color.black);
                        rl.drawLineEx(ps[0], ps[3], 5, rl.Color.black);
                    }
                }
            },
            // yellow
            1 => {
                for (0..self.size) |i| {
                    for (0..self.size) |j| {
                        const fi: f32 = @floatFromInt(i);

                        const fj: f32 = @floatFromInt(j);

                        const tempV = moveVecToAngle(center, dfc[1], N * (fj));
                        ps[0] = moveVecToAngle(tempV, dfc[2], (N * fi));
                        ps[1] = moveVecToAngle(ps[0], trapezoidAngles[0], N);
                        ps[2] = moveVecToAngle(ps[1], 90, N);
                        ps[3] = moveVecToAngle(ps[2], trapezoidAngles[2], N);
                        const color = self.cube.items[@intFromEnum(CubeColor.Yellow)][self.size * i + j].getColor();
                        drawTrapezoid(ps, color);
                    }
                }
            },
            // blue
            2 => {
                for (0..self.size) |i| {
                    for (0..self.size) |j| {
                        const fi: f32 = @floatFromInt(i);

                        const fj: f32 = @floatFromInt(j);

                        const tempV = moveVecToAngle(center, dfc[0], N * (fsize - fj));
                        ps[0] = moveVecToAngle(tempV, dfc[2], (N * fi));
                        ps[1] = moveVecToAngle(ps[0], 30, N);
                        ps[2] = moveVecToAngle(ps[1], 90, N);

                        ps[3] = moveVecToAngle(ps[2], 210, N);
                        const color = self.cube.items[@intFromEnum(CubeColor.Blue)][self.size * i + j].getColor();
                        drawTrapezoid(ps, color);
                    }
                }
            },
            else => unreachable,
        }
    }
}

fn drawLineWithWithAngle(v1: rl.Vector2, degrees: f32, thickness: f32, length: f32, color: rl.Color) void {
    const dest = moveVecToAngle(v1, degrees, length);
    rl.drawLineEx(v1, dest, thickness, color);
}

fn moveVecToAngle(v1: rl.Vector2, degrees: f32, length: f32) rl.Vector2 {
    const theta: f32 = std.math.degreesToRadians(degrees);
    return rl.Vector2.init(v1.x + length * @cos(theta), v1.y + length * @sin(theta));
}

pub fn renderCube(self: *RubikCube) void {
    self.processInput();
    self.drawCube();
}

fn processInput(self: *RubikCube) void {
    const clockwise: bool = !rl.isKeyDown(rl.KeyboardKey.left_shift);
    var key: rl.KeyboardKey = rl.getKeyPressed();
    while (key != .null) : (key = rl.getKeyPressed()) {
        self.processKey(key, clockwise);
    }
}

fn drawTrapezoid(ps: [4]rl.Vector2, color: rl.Color) void {
    rl.drawTriangle(ps[0], ps[3], ps[2], color);
    rl.drawTriangle(ps[2], ps[1], ps[0], color);

    rl.drawLineEx(ps[0], ps[1], 5, rl.Color.black);
    rl.drawLineEx(ps[1], ps[2], 5, rl.Color.black);
    rl.drawLineEx(ps[2], ps[3], 5, rl.Color.black);
    rl.drawLineEx(ps[0], ps[3], 5, rl.Color.black);
}

fn processKey(self: *RubikCube, key: rl.KeyboardKey, clockwise: bool) void {
    switch (key) {
        .l => self.faceRotate(.White, clockwise),
        .f => self.faceRotate(.Blue, clockwise),
        .r => self.faceRotate(.Yellow, clockwise),
        .b => self.faceRotate(.Green, clockwise),
        .u => self.faceRotate(.Orange, clockwise),
        .d => self.faceRotate(.Red, clockwise),
        .h => self.rotateHorizontalMiddleLayer(clockwise),
        .v => self.rotateVerticalMiddleLayer(clockwise),
        .s => self.rotateSideMiddleLayer(clockwise),
        // numeric keys to implement middle layer rotations
        .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine => {
            const current: usize = @intCast(@intFromEnum(key) - @intFromEnum(rl.KeyboardKey.zero));
            self.deslocationAcc = self.deslocationAcc *% 10 +% current;
        },
        .kp_0, .kp_1, .kp_2, .kp_3, .kp_4, .kp_5, .kp_6, .kp_7, .kp_8, .kp_9 => {
            const current: usize = @intCast(@intFromEnum(key) - @intFromEnum(rl.KeyboardKey.kp_0));
            self.deslocationAcc = self.deslocationAcc *% 10 +% current;
        },
        .space => self.shuffle(),
        .f1 => self.rendermod = .RENDER_2D,
        .f2 => self.rendermod = .RENDER_3D,
        else => {},
    }
}
// rotaciona a face
fn faceRotate(self: *RubikCube, face: CubeColor, clockwise: bool) void {
    const cf = self.cube.items[@intFromEnum(face)];
    const buffer: []CubeColor = self.alloc.dupe(CubeColor, cf) catch |err| {
        std.debug.panic("erro: {any}", .{err});
        return;
    };

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
    self.rotateLayers(self.getNeighbors(face), clockwise);
}

fn rotateHorizontalMiddleLayer(self: *RubikCube, clockwise: bool) void {
    if (self.size <= 2) {
        return;
    }
    // clamp para garantir que deslocation esteja dentro dos limites das camadas centrais
    // deslocation deve ser >= 1 e <= size - 2
    const middleLayer: usize = self.clampMiddleLayer();
    const sIndex: i64 = @intCast(middleLayer * self.size);
    var middleLayers: [4]Neighbors = undefined;
    inline for (&.{ .White, .Blue, .Yellow, .Green }, 0..) |color, i| {
        //camadas centrais laterais (em relação à camada laranja)
        middleLayers[i] = Neighbors.new(color, sIndex, 1);
    }
    self.rotateLayers(&middleLayers, clockwise);
}

fn rotateVerticalMiddleLayer(self: *RubikCube, clockwise: bool) void {
    if (self.size <= 2) {
        return;
    }
    const sIndex: i64 = @intCast(self.clampMiddleLayer());
    const N: i64 = @intCast(self.size);
    var middleLayers = [_]Neighbors{
        //camadas centrais laterais (em relação à camada branca)
        Neighbors.new(.Orange, sIndex, N),
        Neighbors.new(.Blue, sIndex, N),
        Neighbors.new(.Red, sIndex, N),
        Neighbors.new(.Green, N * N - sIndex - 1, -N),
    };
    self.rotateLayers(&middleLayers, clockwise);
}

fn rotateSideMiddleLayer(self: *RubikCube, clockwise: bool) void {
    if (self.size <= 2) {
        return;
    }
    const sIndex: i64 = @intCast(self.clampMiddleLayer());
    const N: i64 = @intCast(self.size);
    var middleLayers = [_]Neighbors{
        //camadas centrais laterais (em relação à camada azul)
        Neighbors.new(.Orange, N * N - (N * (sIndex + 1)), 1),
        Neighbors.new(.Yellow, sIndex, N),
        Neighbors.new(.Red, (N - 1) + (N * sIndex), -1),
        Neighbors.new(.White, N * N - 1 - sIndex, -N),
    };
    self.rotateLayers(&middleLayers, clockwise);
}

fn rotateLayers(self: *RubikCube, neighbors: []const Neighbors, clockwise: bool) void {
    if (clockwise) {
        self.swapNeighbor(&neighbors[0], &neighbors[3]);
        self.swapNeighbor(&neighbors[3], &neighbors[2]);
        self.swapNeighbor(&neighbors[2], &neighbors[1]);
    } else {
        self.swapNeighbor(&neighbors[0], &neighbors[1]);
        self.swapNeighbor(&neighbors[1], &neighbors[2]);
        self.swapNeighbor(&neighbors[2], &neighbors[3]);
    }
    self.deslocationAcc = 0;
}

//rotaciona os vizinhos
fn swapNeighbor(self: *RubikCube, n1: *const Neighbors, n2: *const Neighbors) void {
    var temp: CubeColor = undefined;

    for (0..self.size) |i| {
        const di: usize = @intCast(@as(i64, @intCast(i)) * n2.step + n2.startIndex);
        const oi: usize = @intCast(@as(i64, @intCast(i)) * n1.step + n1.startIndex);
        temp = self.cube.items[n1.getIndex()][oi];
        self.cube.items[n1.getIndex()][oi] = self.cube.items[n2.getIndex()][di];
        self.cube.items[n2.getIndex()][di] = temp;
    }
}

fn clampMiddleLayer(self: *RubikCube) usize {
    return if (self.deslocationAcc == 0) self.size / 2 else std.math.clamp(self.deslocationAcc, 1, self.size - 2);
}
