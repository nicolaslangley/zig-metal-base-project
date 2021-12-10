const std = @import("std");

const glfw_native = @cImport({
    @cDefine("GLFW_EXPOSE_NATIVE_COCOA", {});
    @cInclude("GLFW/glfw3native.h");
});
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

pub fn main() anyerror!void {
    if (glfw.glfwInit() != 1)
    {
        std.log.info("Failed to initialize GLFW", .{});
        return;
    }

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

    const window: *glfw.GLFWwindow = glfw.glfwCreateWindow(640, 480, "Metal Triangle", null, null) orelse return;

    while (glfw.glfwWindowShouldClose(window) != 1)
    {
        glfw.glfwPollEvents();
    }

    glfw.glfwDestroyWindow(window);
    glfw.glfwTerminate();
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
