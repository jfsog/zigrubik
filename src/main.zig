const rl = @import("raylib");
const std = @import("std");
const rc = @import("cube/rubikCube.zig");
const N = 3;

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    const screenWidth: i32 = 640;
    const screenHeight: i32 = 640;

    rl.initWindow(screenWidth, screenHeight, "rubik - Zig + raylib example");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(30); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------
    var cube = try rc.Init(alloc, 3);
    // defer cube.deinit(); // Deinitialize the cube when done
    // std.debug.print("Test {any}\n", .{cube});
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.gray);
        cube.rotate();
        try cube.draw2d();
    }
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
//
// test "use other module" {
//     try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
// }
//
// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
//
// const std = @import("std");
//
// /// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
// const lib = @import("rubik_lib");
