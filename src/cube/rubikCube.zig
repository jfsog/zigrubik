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
    if (size <= 1) {
        return error.OutOfRange;
    }
    var c: RubikCube = .{
        .alloc = allocator,
        .size = size,
        .cube = try std.ArrayList([]CubeColor).initCapacity(allocator, 6),
        .neighbors = try allocator.alloc(Neighbors, 4),
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
    c.neighbors[0] = Neighbors.new(.Red, 0, N);
    c.neighbors[1] = Neighbors.new(.Blue, 0, N);
    c.neighbors[2] = Neighbors.new(.Orange, 0, N);
    c.neighbors[3] = Neighbors.new(.Green, N * N - 1, -N);
    //
    // vizinhos[4] = L.Node{ .data = Neighbors.new(.Red, 0, N) };
    // vizinhos[5] = L.Node{ .data = Neighbors.new(.Blue, 0, N) };
    // vizinhos[6] = L.Node{ .data = Neighbors.new(.Orange, 0, N) };
    // vizinhos[7] = L.Node{ .data = Neighbors.new(.Green, N * N - 1, -N) };
    // try c.neighbors.append(Neighbors.new(.Red, N * (N - 1), 1));
    // try c.neighbors.append(Neighbors.new(.Yellow, 0, N));
    // try c.neighbors.append(Neighbors.new(.Orange, N - 1, N));
    // try c.neighbors.append(Neighbors.new(.White, N * N - 1, -N));

    // var right = L.Node{ .data = Neighbors.new(.Blue, 0, N) };
    // var bottom = L.Node{ .data = Neighbors.new(.Orange, N * N - 1, -N) };
    // var left = L.Node{ .data = Neighbors.new(.Green, N * N - 1, -N) };
    // list1.append(top2);
    // list1.append(&right);
    // list1.append(&bottom);
    // list1.append(&left);
    // std.debug.print("top: {any}", .{top2.data});

    // // Neighbors for the blue

    return c;
}
pub fn getNeighbors(self: *RubikCube, face: CubeColor) ![]Neighbors {
    const index = @intFromEnum(face) * 4;
    if (index >= self.neighbors.len) {
        return error.OutOfRange;
    }
    //monipular aqui
    return self.neighbors[@intFromEnum(face) * 4 .. @intFromEnum(face) * 4 + 4];
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
    // falta criar número a partir de sequência de teclas? talvez desnecessário!
    const clockwise: bool = !rl.isKeyDown(rl.KeyboardKey.left_shift);
    var key: rl.KeyboardKey = rl.getKeyPressed();
    // std.debug.print("Press any key to rotate the cube, or ESC to exit...\n", .{});
    while (key != .null) : (key = rl.getKeyPressed()) {
        // std.debug.print("key :{}, {}\n", .{ key, clockwise });
        switch (key) {
            // .r => self.faceRotate(.Blue, clockwise),
            // .l => self.faceRotate(.Green, clockwise),
            .f => try self.faceRotate(.White, clockwise),
            // .b => self.faceRotate(.Yellow, clockwise),
            // .u => self.faceRotate(.Orange, clockwise),
            // .d => self.faceRotate(.Red, clockwise),
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

fn faceRotate(self: *RubikCube, face: CubeColor, clockwise: bool) !void {
    // Implement the rotation logic for the specified face
    std.debug.print("Rotating face: {}, {}, {}\n", .{ face, clockwise, @intFromEnum(face) });
    const cf = self.cube.items[@intFromEnum(face)];
    // for (0..cf.len) |i| {
    //     cf[i] = @enumFromInt(i % 6);
    // }
    const buffer: []CubeColor = self.alloc.dupe(CubeColor, cf) catch |err| {
        std.debug.print("Error duplicating face: {}\n", .{err});
        return;
    };
    defer self.alloc.free(buffer);
    const N = self.size;
    if (clockwise) { // Rotate clockwise
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
    const neighbors: []Neighbors = try self.getNeighbors(face);
    if (neighbors.len == 0) {
        std.debug.print("No neighbors found for face: {}\n", .{face});
        return;
    }
    const L = std.DoublyLinkedList(Neighbors);
    var list = L{};
    var lnode: []L.Node = try self.alloc.alloc(L.Node, neighbors.len);
    defer self.alloc.free(lnode);
    for (0..neighbors.len) |i| {
        lnode[i] = L.Node{ .data = neighbors[i] };
        list.append(&lnode[i]);
    }
    list.first.?.prev = list.last.?;
    list.last.?.next = list.first.?; // Make it circular
    var it: ?*L.Node = list.first;
    var i: usize = 0;
    while (it) |node| : (i += 1) {
        if (i >= neighbors.len) break; // Prevent loop
        var next: ?*L.Node = undefined;
        if (clockwise) {
            try self.swapNeighbor(&node.data, &node.next.?.data);
            next = it.?.prev;
        } else {
            try self.swapNeighbor(&node.data, &node.prev.?.data);
            next = it.?.next;
        }
        it = next;
    }
}
fn swapNeighbor(self: *RubikCube, n1: *Neighbors, n2: *Neighbors) !void {
    const buffer: []CubeColor = try self.alloc.alloc(CubeColor, self.size);
    defer self.alloc.free(buffer);

    for (0..self.size) |i| {
        const oi: usize = @intCast(@as(i64, @intCast(i)) * n1.step + n1.startIndex);
        buffer[i] = self.cube.items[n1.getIndex()][oi];
    }
    std.debug.print("n1 {any} e n2 {any}\n", .{ n1.color, n2.color });
    std.debug.print("array {any}\n", .{buffer});
}
