const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const compile_metal_ir = b.addSystemCommand(&[_][]const u8{
        "xcrun",
        "-sdk",
        "macosx",
        "metal",
        "-c",
        "src/shaders.metal",
        "-I",
        "include",
        "-o",
        "src/shaders.air",
    });

    var compile_metal_lib = b.addSystemCommand(&[_][]const u8{
        "xcrun",
        "-sdk",
        "macosx",
        "metallib",
        "src/shaders.air",
        "-o",
        "src/shaders.metallib",
    });
    compile_metal_lib.step.dependOn(&compile_metal_ir.step);

    var install_metal_lib = b.addInstallFileWithDir(.{ .path = "src/shaders.metallib" }, .prefix, "bin/default.metallib");
    install_metal_lib.step.dependOn(&compile_metal_lib.step);

    var clean_metal_artifacts = b.addSystemCommand(&[_][]const u8{
        "rm",
        "src/shaders.air",
        "src/shaders.metallib",
    });
    clean_metal_artifacts.step.dependOn(&install_metal_lib.step);

    b.getInstallStep().dependOn(&clean_metal_artifacts.step);
    
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("metal-triangle", "src/main.zig");

    exe.addPackagePath("c", "libs/c.zig");
    exe.addPackagePath("darwin", "libs/darwin.zig");
    exe.addPackagePath("metal", "libs/metal.zig");
    exe.addPackagePath("simd", "libs/simd.zig");

    exe.addIncludeDir("external/src");
    exe.addCSourceFile("external/src/cgltf.c", &[_][]const u8{"-std=c99"});
    // GLFW
    exe.addLibPath("external/bin");
    exe.linkSystemLibrary("glfw"); 

    // System frameworks for Metal
    exe.linkFramework("QuartzCore"); 
    exe.linkFramework("Metal"); 

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
