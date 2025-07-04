const rl = @import("raylib");
const std = @import("std");
const rc = @import("cube/rubikCube.zig");
const N = 3;

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    const screenWidth: i32 = 640;
    const screenHeight: i32 = 640;

    rl.initWindow(screenWidth, screenHeight, "rubik - Zig + raylib");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(30); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------
    var cube = try rc.Init(alloc, 3);
    // defer cube.deinit(); // Deinitialize the cube when done
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.gray);
        try cube.processInput();
        try cube.draw2d();
    }
}
