const std = @import("std");
const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("glfw3.h");
    @cInclude("cgltf.h");
});
