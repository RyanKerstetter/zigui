const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
});
const util = @import("util.zig");
const ui = @import("uicomponent.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    raylib.InitWindow(800, 600, "zigUI");
    raylib.SetTargetFPS(60);

    var file_box = ui.TextBox.init_text(
        util.vec2{ .x = 100, .y = 100 },
        "File",
        20,
        raylib.BLACK,
    );

    var edit_box = ui.TextBox.init_text(
        util.vec2{ .x = 100, .y = 100 },
        "Edit",
        20,
        raylib.BLACK,
    );

    var carousel = ui.Carousel.init(
        util.vec2{ .x = 100, .y = 100 },
        util.vec2{ .x = 300, .y = 100 },
        allocator,
    );
    var ui_arr = [_]*ui.UIComponent{
        &file_box.uicomponent,
        &edit_box.uicomponent,
    };
    carousel.set_children(&ui_arr);

    var root_box = ui.Box.init(
        util.vec2{ .x = 0, .y = 0 },
        util.vec2{ .x = 800, .y = 600 },
        ui.Box.GrowDirection.FREE,
        0,
        allocator,
    );
    root_box.add_child(&carousel.uicomponent);

    var root = &root_box.uicomponent;

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.RAYWHITE);

        const mouse_pos = util.raylib_to_vec2(raylib.GetMousePosition());
        root.update();
        root.hover(mouse_pos);
        if (raylib.IsMouseButtonPressed(raylib.MOUSE_LEFT_BUTTON))
            root.click(mouse_pos);
        root.draw(util.vec2{ .x = 0, .y = 0 });

        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}
