const std = @import("std");
const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("objc/message.h");
    @cInclude("cgltf.h");
});
