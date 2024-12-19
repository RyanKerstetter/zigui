const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
});

pub const vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub fn vec3_add(a: vec3, b: vec3) vec3 {
    return vec3{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

pub fn vec3_sub(a: vec3, b: vec3) vec3 {
    return vec3{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
}

pub fn vec3_dot(a: vec3, b: vec3) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

pub fn vec3_cross(a: vec3, b: vec3) vec3 {
    return vec3{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

pub fn vec3_scale(a: vec3, b: f32) vec3 {
    return vec3{ .x = a.x * b, .y = a.y * b, .z = a.z * b };
}

pub fn vec3_length(a: vec3) f32 {
    const dot = vec3_dot(a, a);
    const distance = std.math.sqrt(dot);
    return distance;
}

pub fn vec3_normalize(a: vec3) vec3 {
    const length = vec3_length(a);
    return vec3_scale(a, 1.0 / length);
}

pub fn vec3_lerp(a: vec3, b: vec3, t: f32) vec3 {
    return vec3_add(vec3_scale(a, 1.0 - t), vec3_scale(b, t));
}

pub fn vec3_reflect(a: vec3, b: vec3) vec3 {
    const dot = vec3_dot(a, b);
    const scale = vec3_scale(b, 2.0 * dot);
    return vec3_sub(a, scale);
}

pub const vec2 = struct {
    x: f32,
    y: f32,
};

pub fn vec2_add(a: vec2, b: vec2) vec2 {
    return vec2{ .x = a.x + b.x, .y = a.y + b.y };
}

pub fn vec2_sub(a: vec2, b: vec2) vec2 {
    return vec2{ .x = a.x - b.x, .y = a.y - b.y };
}

pub fn vec2_dot(a: vec2, b: vec2) f32 {
    return a.x * b.x + a.y * b.y;
}

pub fn vec2_scale(a: vec2, b: f32) vec2 {
    return vec2{ .x = a.x * b, .y = a.y * b };
}

pub fn vec2_distance(a: vec2, b: vec2) f32 {
    return vec2_length(vec2_sub(a, b));
}

pub fn vec2_length(a: vec2) f32 {
    const dot = vec2_dot(a, a);
    const distance = std.math.sqrt(dot);
    return distance;
}

pub fn vec2_normalize(a: vec2) vec2 {
    const length = vec2_length(a);
    return vec2_scale(a, 1.0 / length);
}

pub fn vec2_lerp(a: vec2, b: vec2, t: f32) vec2 {
    return vec2_add(vec2_scale(a, 1.0 - t), vec2_scale(b, t));
}

pub fn vec2_mul(a: vec2, b: vec2) vec2 {
    return vec2{ .x = a.x * b.x, .y = a.y * b.y };
}

pub fn to_raylib(a: vec2) raylib.Vector2 {
    return raylib.Vector2{ .x = a.x, .y = a.y };
}

pub fn float_to_cint(a: f32) c_int {
    const result: c_int = @intFromFloat(a);
    return result;
}

pub fn vec2_to_cint(a: vec2) c_int_vec2 {
    const x: c_int = @intFromFloat(a.x);
    const y: c_int = @intFromFloat(a.y);
    return c_int_vec2{ .x = x, .y = y };
}

pub fn raylib_to_vec2(a: raylib.Vector2) vec2 {
    return vec2{ .x = a.x, .y = a.y };
}

pub fn coerce_ptr(src_type: type, src_ptr: *src_type, dest_type: type) *dest_type {
    const new_ptr: *dest_type = @ptrFromInt(@intFromPtr(src_ptr));
    return new_ptr;
}

pub fn coerce_ptr_const(src_type: type, ptr: *const src_type, dest_type: type) *const dest_type {
    const new_ptr: *const dest_type = @ptrFromInt(@intFromPtr(ptr));
    return new_ptr;
}

pub const c_int_vec2 = struct {
    x: c_int,
    y: c_int,
};

pub fn closure(function_type: type) type {
    const Closure = struct {
        const Self = @This();
        ctx: *const anyopaque,
        fun: *const function_type,

        pub fn init(function: *const function_type, context: *const anyopaque) Self {
            return Self{
                .ctx = context,
                .fun = function,
            };
        }

        pub fn free(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.ctx);
        }
    };
    return Closure;
}

pub fn copy_literal_array_to_slice(comptime T: type, comptime array: []const T, allocator: std.mem.Allocator) *[]T {
    var slice = allocator.alloc(T, array.len) catch unreachable;
    var i: usize = 0;
    for (array) |item| {
        slice[i] = item;
        i += 1;
    }
    return &slice;
}

pub const Timer = struct {
    duration: i32,
    elapsed: i32,
    pub fn init(duration: i32) Timer {
        return Timer{
            .duration = duration,
            .elapsed = 0,
        };
    }

    pub fn update(self: *Timer) bool {
        self.elapsed += 1;
        return self.elapsed >= self.duration;
    }

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }
};
