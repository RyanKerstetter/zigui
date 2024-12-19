const std = @import("std");
const util = @import("util.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

pub const UIComponent = struct {
    const Self = @This();
    position: util.vec2,
    size: util.vec2,
    background_color: ?raylib.Color = null,
    border_color: raylib.Color = raylib.BLACK,
    border_width: f32 = -1,
    on_click_closure: ?util.closure(fn (*Self, util.vec2, *const anyopaque) void) = null,
    on_hover_closure: ?util.closure(fn (*Self, util.vec2, *const anyopaque) void) = null,
    update_closure: ?util.closure(fn (*Self, *const anyopaque) void) = null,
    on_size_change_closure: ?util.closure(fn (*Self, *const anyopaque) void) = null,
    draw_closure: util.closure(fn (*const Self, util.vec2, *const anyopaque) void),
    free_closure: ?util.closure(fn (*Self, *const anyopaque) void) = null,
    parent: ?*Self = null,

    pub fn get_global_offset(self: *Self) util.vec2 {
        var offset = self.position;
        if (self.parent) |parent| {
            offset = util.vec2_add(offset, parent.get_global_offset());
        }
        return offset;
    }

    pub fn click(self: *Self, mouse_position: util.vec2) void {
        if (self.contains(mouse_position)) {
            if (self.on_click_closure) |closure| {
                closure.fun(self, mouse_position, closure.ctx);
            }
        }
    }

    pub fn hover(self: *Self, mouse_position: util.vec2) void {
        if (self.contains(mouse_position)) {
            if (self.on_hover_closure) |closure| {
                closure.fun(self, mouse_position, closure.ctx);
            }
        }
    }

    pub fn update(self: *Self) void {
        if (self.update_closure) |closure| {
            closure.fun(self, closure.ctx);
        }
    }

    pub fn size_change(self: *Self) void {
        if (self.on_size_change_closure) |closure| {
            closure.fun(self, closure.ctx);
        }
    }

    pub fn free(self: *Self) void {
        if (self.free_closure) |closure| {
            closure.fun(self, closure.ctx);
        }
    }

    pub fn draw(self: *const Self, parent_offset: util.vec2) void {
        const offset = util.vec2_add(self.position, parent_offset);
        const c_offset: util.c_int_vec2 = util.vec2_to_cint(offset);
        const c_bounds: util.c_int_vec2 = util.vec2_to_cint(self.size);
        raylib.BeginScissorMode(c_offset.x, c_offset.y, c_bounds.x, c_bounds.y);
        if (self.background_color) |background_color| {
            raylib.DrawRectangleV(util.to_raylib(offset), util.to_raylib(self.size), background_color);
        }
        if (self.border_width > 0.0) {
            raylib.DrawRectangleLinesEx(
                raylib.Rectangle{
                    .x = offset.x,
                    .y = offset.y,
                    .width = self.size.x,
                    .height = self.size.y,
                },
                self.border_width,
                self.border_color,
            );
        }
        self.draw_closure.fun(self, offset, self.draw_closure.ctx);
        raylib.EndScissorMode();
    }

    pub fn contains(self: *Self, point: util.vec2) bool {
        const offset = self.get_global_offset();
        return point.x >= offset.x and point.x <= offset.x + self.size.x and
            point.y >= offset.y and point.y <= offset.y + self.size.y;
    }
};

pub const Location = enum(u8) {
    TOP_LEFT = 0,
    TOP_MIDDLE = 1,
    TOP_RIGHT = 2,
    MIDDLE_LEFT = 3,
    MIDDLE = 4,
    MIDDLE_RIGHT = 5,
    BOTTOM_LEFT = 6,
    BOTTOM_MIDDLE = 7,
    BOTTOM_RIGHT = 8,
};

pub const LocationMap = [_]util.vec2{
    util.vec2{ .x = 0, .y = 0 },
    util.vec2{ .x = 0.5, .y = 0 },
    util.vec2{ .x = 1, .y = 0 },
    util.vec2{ .x = 0, .y = 0.5 },
    util.vec2{ .x = 0.5, .y = 0.5 },
    util.vec2{ .x = 1, .y = 0.5 },
    util.vec2{ .x = 0, .y = 1 },
    util.vec2{ .x = 0.5, .y = 1 },
    util.vec2{ .x = 1, .y = 1 },
};

pub const TextBox = struct {
    const Self = @This();
    uicomponent: UIComponent,
    text: []const u8,
    font_size: c_int,
    font_color: raylib.Color,

    pub fn init_text(position: util.vec2, text: []const u8, font_size: c_int, font_color: raylib.Color) Self {
        const c_ptr: [*c]const u8 = text.ptr;
        const width = raylib.MeasureText(c_ptr, 20);
        const height = font_size;
        const size = util.vec2{ .x = @floatFromInt(width), .y = @floatFromInt(height) };

        const draw_closure = util.closure(fn (*const UIComponent, util.vec2, *const anyopaque) void).init(&draw, undefined);

        return Self{
            .uicomponent = UIComponent{
                .position = position,
                .size = size,
                .draw_closure = draw_closure,
            },
            .text = text,
            .font_size = font_size,
            .font_color = font_color,
        };
    }

    fn draw(component_self: *const UIComponent, offset: util.vec2, _: *const anyopaque) void {
        const self: *const Self = util.coerce_ptr_const(UIComponent, component_self, Self);
        const pos_int = util.vec2_to_cint(offset);
        const text_ptr: [*]const u8 = self.text.ptr;
        raylib.DrawText(text_ptr, pos_int.x, pos_int.y, self.font_size, self.font_color);
    }

    pub fn get_ui_ptr(self: *Self) *UIComponent {
        return &self.uicomponent;
    }
};

pub const Formatter = struct {
    const Self = @This();
    uicomponent: UIComponent,
    location: Location = Location.MIDDLE,
    child: *UIComponent = undefined,

    pub fn init(position: util.vec2, size: util.vec2, location: Location) Self {
        const dc = util.closure(fn (*const UIComponent, util.vec2, *const anyopaque) void).init(&draw, undefined);
        const size_change_closure = util.closure(fn (*UIComponent, *const anyopaque) void).init(&size_change, undefined);
        const hover_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&hover, undefined);
        const click_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&click, undefined);
        const update_closure = util.closure(fn (*UIComponent, *const anyopaque) void).init(&update, undefined);

        const uicomponent = UIComponent{
            .position = position,
            .size = size,
            .draw_closure = dc,
            .on_size_change_closure = size_change_closure,
            .on_hover_closure = hover_closure,
            .on_click_closure = click_closure,
            .update_closure = update_closure,
        };

        return Self{
            .uicomponent = uicomponent,
            .location = location,
        };
    }

    pub fn set_child(self: *Self, child: *UIComponent) void {
        self.child = child;
        child.parent = &self.uicomponent;
        self.uicomponent.size_change();
    }

    pub fn size_change(component_self: *UIComponent, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        const size_diff = util.vec2_sub(self.uicomponent.size, self.child.size);
        const location_vec = LocationMap[@intFromEnum(self.location)];
        const child_offset = util.vec2_mul(size_diff, location_vec);
        self.child.position = child_offset;
    }

    fn draw(component_self: *const UIComponent, offset: util.vec2, _: *const anyopaque) void {
        const self: *const Self = util.coerce_ptr_const(UIComponent, component_self, Self);

        self.child.draw(offset);
    }

    pub fn get_ui_ptr(self: *Self) *UIComponent {
        return &self.uicomponent;
    }

    fn update(component_self: *UIComponent, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        self.child.update();
    }

    fn hover(component_self: *UIComponent, mouse_position: util.vec2, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        self.child.hover(mouse_position);
    }

    fn click(component_self: *UIComponent, mouse_position: util.vec2, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        self.child.click(mouse_position);
    }
};

pub const Box = struct {
    const Self = @This();
    pub const GrowDirection = enum {
        RIGHT,
        DOWN,
        LEFT,
        UP,
        FREE,
    };
    const GrowDirectionMap = [_]util.vec2{
        util.vec2{ .x = 1, .y = 0 },
        util.vec2{ .x = 0, .y = 1 },
        util.vec2{ .x = -1, .y = 0 },
        util.vec2{ .x = 0, .y = -1 },
        util.vec2{ .x = -1, .y = -1 },
    };
    uicomponent: UIComponent,
    children: std.ArrayList(*UIComponent),
    grow_direction: GrowDirection,
    spacing: f32,

    pub fn init(position: util.vec2, size: util.vec2, grow_direction: GrowDirection, spacing: f32, allocator: std.mem.Allocator) Self {
        const list = std.ArrayList(*UIComponent).init(allocator);

        const draw_closure = util.closure(fn (*const UIComponent, util.vec2, *const anyopaque) void).init(&draw, undefined);
        const hover_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&hover, undefined);
        const click_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&click, undefined);
        const update_closure = util.closure(fn (*UIComponent, *const anyopaque) void).init(&update, undefined);

        return Self{
            .uicomponent = UIComponent{
                .position = position,
                .size = size,
                .draw_closure = draw_closure,
                .on_hover_closure = hover_closure,
                .on_click_closure = click_closure,
                .update_closure = update_closure,
            },
            .children = list,
            .grow_direction = grow_direction,
            .spacing = spacing,
        };
    }

    pub fn add_child(self: *Self, child: *UIComponent) void {
        if (self.grow_direction == GrowDirection.FREE) {
            self.children.append(child) catch unreachable;
            return;
        }

        if (self.grow_direction == GrowDirection.RIGHT or self.grow_direction == GrowDirection.LEFT) {
            child.size.y = self.uicomponent.size.y;
        } else {
            child.size.x = self.uicomponent.size.x;
        }
        child.size_change();

        if (self.children.items.len == 0) {
            child.position = util.vec2{ .x = 0, .y = 0 };
            if (self.grow_direction == GrowDirection.LEFT) {
                child.position.x = self.uicomponent.size.x - child.size.x;
            } else if (self.grow_direction == GrowDirection.UP) {
                child.position.y = self.uicomponent.size.y - child.size.y;
            }
            self.children.append(child) catch unreachable;
            return;
        }
        const last_child = self.children.getLast();
        const last_child_size = last_child.size;
        const grow_direction_vec = GrowDirectionMap[@intFromEnum(self.grow_direction)];
        const last_child_offset = util.vec2_add(last_child.position, util.vec2_scale(grow_direction_vec, self.spacing));
        if (self.grow_direction == GrowDirection.RIGHT or self.grow_direction == GrowDirection.DOWN) {
            child.position = util.vec2_add(last_child_offset, util.vec2_mul(last_child_size, grow_direction_vec));
        } else {
            child.position = util.vec2_add(last_child_offset, util.vec2_mul(child.size, grow_direction_vec));
        }
        self.children.append(child) catch unreachable;
    }

    pub fn draw(component_self: *const UIComponent, offset: util.vec2, _: *const anyopaque) void {
        const self: *const Self = util.coerce_ptr_const(UIComponent, component_self, Self);

        for (self.children.items) |child| {
            child.draw(offset);
        }
    }

    pub fn hover(component_self: *UIComponent, mouse_position: util.vec2, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        for (self.children.items) |child| {
            child.hover(mouse_position);
        }
    }

    pub fn click(component_self: *UIComponent, mouse_position: util.vec2, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        for (self.children.items) |child| {
            child.click(mouse_position);
        }
    }

    pub fn update(component_self: *UIComponent, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);
        for (self.children.items) |child| {
            child.update();
        }
    }
};

pub const Space = struct {
    const Self = @This();
    uicomponent: UIComponent,
    pub fn init(size: util.vec2) Self {
        const draw_closure = util.closure(fn (*const UIComponent, util.vec2, *const anyopaque) void).init(&draw, undefined);
        return Self{
            .uicomponent = UIComponent{
                .position = util.vec2{ .x = 0, .y = 0 },
                .size = size,
                .draw_closure = draw_closure,
            },
        };
    }

    pub fn draw(_: *const UIComponent, _: util.vec2, _: *const anyopaque) void {}
};

pub const Carousel = struct {
    const Self = @This();
    uicomponent: UIComponent,
    children: std.ArrayList(*UIComponent),
    left_button: Formatter = undefined,
    right_button: Formatter = undefined,
    middle_content: Formatter = undefined,
    current_index: i32,
    allocator: std.mem.Allocator,

    pub fn init(position: util.vec2, size: util.vec2, allocator: std.mem.Allocator) Self {
        const list = std.ArrayList(*UIComponent).init(allocator);
        const draw_closure = util.closure(fn (*const UIComponent, util.vec2, *const anyopaque) void).init(&draw, undefined);
        const hover_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&hover, undefined);
        const click_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&click, undefined);
        return Self{
            .uicomponent = UIComponent{
                .position = position,
                .size = size,
                .draw_closure = draw_closure,
                .on_hover_closure = hover_closure,
                .on_click_closure = click_closure,
            },
            .children = list,
            .current_index = 0,
            .allocator = allocator,
        };
    }

    pub fn load(self: *Self) void {
        const index: usize = @intCast(self.current_index);
        const middle_space = self.uicomponent.size.x - 100;
        var text_left_ptr = self.allocator.create(TextBox) catch unreachable;
        text_left_ptr.* = TextBox.init_text(util.vec2{ .x = 0, .y = 0 }, "<", 20, raylib.BLACK);
        self.left_button = Formatter.init(util.vec2{ .x = 0, .y = 0 }, util.vec2{ .x = 50, .y = 50 }, Location.MIDDLE);
        self.left_button.set_child(&text_left_ptr.uicomponent);
        self.left_button.uicomponent.parent = &self.uicomponent;

        self.middle_content = Formatter.init(util.vec2{ .x = 50, .y = 0 }, util.vec2{ .x = middle_space, .y = 50 }, Location.MIDDLE);
        self.middle_content.set_child(self.children.items[index]);
        self.middle_content.uicomponent.parent = &self.uicomponent;

        var text_right_ptr = self.allocator.create(TextBox) catch unreachable;
        text_right_ptr.* = TextBox.init_text(util.vec2{ .x = 0, .y = 0 }, ">", 20, raylib.BLACK);
        self.right_button = Formatter.init(util.vec2{ .x = 50 + middle_space, .y = 0 }, util.vec2{ .x = 50, .y = 50 }, Location.MIDDLE);
        self.right_button.set_child(&text_right_ptr.uicomponent);
        self.right_button.uicomponent.parent = &self.uicomponent;

        const closure_data = struct {
            carousel: *Self,
        };

        const Anon = struct {
            pub fn left_click(_: *UIComponent, _: util.vec2, ctx: *const anyopaque) void {
                const data: *const closure_data = util.coerce_ptr_const(anyopaque, ctx, closure_data);
                const carousel = data.carousel;
                carousel.change_index(-1);
            }

            pub fn right_click(_: *UIComponent, _: util.vec2, ctx: *const anyopaque) void {
                const data: *const closure_data = util.coerce_ptr_const(anyopaque, ctx, closure_data);
                const carousel = data.carousel;
                carousel.change_index(1);
            }
        };
        const closure_data_ptr = self.allocator.create(closure_data) catch unreachable;
        closure_data_ptr.* = closure_data{ .carousel = self };
        const left_click_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&Anon.left_click, closure_data_ptr);
        const right_click_closure = util.closure(fn (*UIComponent, util.vec2, *const anyopaque) void).init(&Anon.right_click, closure_data_ptr);

        self.left_button.uicomponent.on_click_closure = left_click_closure;
        self.right_button.uicomponent.on_click_closure = right_click_closure;
    }

    pub fn set_children(self: *Self, children: []const *UIComponent) void {
        for (children) |child| {
            self.children.append(child) catch unreachable;
        }
        self.load();
    }

    fn free(component_self: *UIComponent, _: *const anyopaque) void {
        const self: *Self = util.coerce_ptr(UIComponent, component_self, Self);

        self.allocator.destroy(&self.left_button);
        self.allocator.destroy(&self.right_button);
        for (self.children.items) |child| {
            self.allocator.destroy(child);
        }
        self.children.deinit();
    }

    pub fn change_index(self: *Self, offset: i32) void {
        self.current_index += offset;
        if (self.current_index < 0) {
            self.current_index = @intCast(self.children.items.len - 1);
        } else if (self.current_index >= self.children.items.len) {
            self.current_index = 0;
        }
        const index: usize = @intCast(self.current_index);
        self.middle_content.set_child(self.children.items[index]);
    }

    fn draw(component_self: *const UIComponent, offset: util.vec2, _: *const anyopaque) void {
        const self: *const Self = util.coerce_ptr_const(UIComponent, component_self, Self);

        self.left_button.uicomponent.draw(offset);
        self.middle_content.uicomponent.draw(offset);
        self.right_button.uicomponent.draw(offset);
    }

    fn hover(component_self: *UIComponent, mouse_position: util.vec2, _: *const anyopaque) void {
        var self: *Self = util.coerce_ptr(UIComponent, component_self, Self);

        self.left_button.uicomponent.hover(mouse_position);
        self.middle_content.uicomponent.hover(mouse_position);
        self.right_button.uicomponent.hover(mouse_position);
    }

    fn click(component_self: *UIComponent, mouse_position: util.vec2, _: *const anyopaque) void {
        var self: *Self = util.coerce_ptr(UIComponent, component_self, Self);

        self.left_button.uicomponent.click(mouse_position);
        self.middle_content.uicomponent.click(mouse_position);
        self.right_button.uicomponent.click(mouse_position);
    }
};
