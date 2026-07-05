const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/plugin.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vs_dep = b.dependency("vapoursynth", .{
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("vapoursynth", vs_dep.module("vapoursynth"));
    // libavisynth is dlopen'd at runtime (src/avs_capi.zig); never link it —
    // the plugin must load into VapourSynth even when AviSynth+ is absent.
    mod.link_libc = true;

    const lib = b.addLibrary(.{
        .name = "vsavsreader",
        .linkage = .dynamic,
        .root_module = mod,
    });

    b.installArtifact(lib);
}
