const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/plugin.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Pull in vapoursynth-zig (ZAPI)
    const vs_dep = b.dependency("vapoursynth", .{
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("vapoursynth", vs_dep.module("vapoursynth"));

    // Add include path for capi.h (used by @cImport in plugin.zig)
    mod.addIncludePath(b.path("src"));

    // Add C++ bridge source to the module
    mod.addCSourceFile(.{
        .file = b.path("src/capi.cpp"),
        .flags = &.{
            "-std=c++17",
            "-I/opt/homebrew/Cellar/avisynthplus/3.7.5/include/avisynth",
        },
    });
    mod.link_libc = true;
    mod.link_libcpp = true;
    mod.linkSystemLibrary("avisynth", .{});

    // Build as shared library
    const lib = b.addLibrary(.{
        .name = "vsavsreader",
        .linkage = .dynamic,
        .root_module = mod,
    });

    b.installArtifact(lib);
}
