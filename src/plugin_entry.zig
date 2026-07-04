//! VS_AvsReader — VapourSynth plugin entry point
const std = @import("std");
const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;
const ZAPI = vapoursynth.ZAPI;

const plugin = @import("plugin.zig");

const PLUGIN_ID = "chikuzen.does.not.have.his.own.domain.avsr";
const PLUGIN_NAMESPACE = "avsr";
const PLUGIN_NAME = "AviSynth Script Reader for VapourSynth v3.0.0";

export fn VapourSynthPluginInit2(
    pl: *vs.Plugin,
    vspapi: *const vs.PLUGINAPI,
) void {
    ZAPI.Plugin.config(
        PLUGIN_ID,
        PLUGIN_NAMESPACE,
        PLUGIN_NAME,
        .{ .major = 3, .minor = 0, .patch = 0 },
        pl,
        vspapi,
    );

    ZAPI.Plugin.function(
        "Import",
        "script:data;bitdepth:int:opt;alpha:int:opt;",
        "clip:vnode;",
        plugin.importCreate,
        pl,
        vspapi,
    );

    ZAPI.Plugin.function(
        "Eval",
        "lines:data;bitdepth:int:opt;alpha:int:opt;",
        "clip:vnode;",
        plugin.evalCreate,
        pl,
        vspapi,
    );
}
