//! VS_AvsReader — AviSynth script reader for VapourSynth (Zig ZAPI + C API)
const std = @import("std");
const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;
const ZAPI = vapoursynth.ZAPI;

const avs = @import("avs_capi.zig");

const AvsReader = struct {
    avs_env: avs.Env,
    vi: vs.VideoInfo,
    // AVS plane request constants for VS plane indices 0..num_planes-1.
    num_planes: u8,
    avs_planes: [3]c_int,
};

fn avsrGetFrame(
    n: c_int,
    activation_reason: vs.ActivationReason,
    instance_data: ?*anyopaque,
    frame_data: ?*?*anyopaque,
    frame_ctx: ?*vs.FrameContext,
    core: ?*vs.Core,
    vsapi: ?*const vs.API,
) callconv(.c) ?*const vs.Frame {
    _ = frame_data;
    const d: *AvsReader = @ptrCast(@alignCast(instance_data));
    const zapi = ZAPI.init(vsapi, core, frame_ctx);

    if (activation_reason != .Initial) return null;

    const frame = d.avs_env.getFrame(n) orelse {
        zapi.setFilterError("avsr: AviSynth returned no frame");
        return null;
    };
    defer d.avs_env.releaseFrame(frame);
    // AviSynth reports runtime frame errors on the clip, not by returning null.
    if (d.avs_env.getClipError()) |msg| {
        zapi.setFilterError(std.mem.span(msg));
        return null;
    }

    const dst = zapi.newVideoFrame(
        &d.vi.format, d.vi.width, d.vi.height, null,
    ) orelse return null;

    const props = zapi.getFramePropertiesRW(dst);
    _ = zapi.mapSetInt(props, "_DurationNum", d.vi.fpsDen, .Replace);
    _ = zapi.mapSetInt(props, "_DurationDen", d.vi.fpsNum, .Replace);

    // Post-normalization every format is planar: one blit loop for all.
    var p: u8 = 0;
    while (p < d.num_planes) : (p += 1) {
        const ap = d.avs_planes[p];
        const src = d.avs_env.getReadPtr(frame, ap) orelse {
            zapi.setFilterError("avsr: missing plane in AviSynth frame");
            zapi.freeFrame(dst);
            return null;
        };
        const sp: usize = @intCast(d.avs_env.getPitch(frame, ap));
        const rs: usize = @intCast(d.avs_env.getRowSize(frame, ap));
        const h: usize = @intCast(d.avs_env.getHeight(frame, ap));
        const dp = zapi.getWritePtr(dst, p);
        const ds: usize = @intCast(zapi.getStride(dst, p));

        var y: usize = 0;
        while (y < h) : (y += 1) {
            @memcpy(dp[y * ds ..][0..rs], src[y * sp ..][0..rs]);
        }
    }
    return dst;
}

fn avsrFree(
    instance_data: ?*anyopaque,
    _: ?*vs.Core,
    _: ?*const vs.API,
) callconv(.c) void {
    const d: *AvsReader = @ptrCast(@alignCast(instance_data));
    d.avs_env.deinit();
    std.heap.c_allocator.destroy(d);
}

pub fn importCreate(
    in: ?*const vs.Map, out: ?*vs.Map,
    _: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API,
) callconv(.c) void { createFilter(in, out, "Import", core, vsapi); }

pub fn evalCreate(
    in: ?*const vs.Map, out: ?*vs.Map,
    _: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API,
) callconv(.c) void { createFilter(in, out, "Eval", core, vsapi); }

fn createFilter(
    in: ?*const vs.Map,
    out: ?*vs.Map,
    mode: [:0]const u8,
    core: ?*vs.Core,
    vsapi: ?*const vs.API,
) void {
    const zapi = ZAPI.init(vsapi, core, null);
    const mi = zapi.initZMap(in);
    const mo = zapi.initZMap(out);

    const bitdepth = mi.getValue(i32, "bitdepth") orelse 8;
    const alpha = mi.getValue(i32, "alpha") orelse 0;
    const input = if (mode[0] == 'E')
        mi.getData("lines", 0) orelse ""
    else
        mi.getData("script", 0) orelse "";

    // The legacy MSB/LSB stacked bitdepth hack is gone: AviSynth+ high bit
    // depth formats are mapped natively, so only the default 8 is accepted.
    if (bitdepth != 8) {
        mo.setError("avsr: invalid bitdepth (parameter removed; AVS+ high bit depth is mapped natively)");
        return;
    }
    if (alpha != 0) {
        mo.setError("avsr: alpha output is not implemented");
        return;
    }
    if (input.len < 1) {
        mo.setError("avsr: empty script");
        return;
    }

    var avs_env = avs.Env.init(mode, input) catch |err| {
        switch (err) {
            error.AvisynthNotFound => mo.setError("avsr: libavisynth not found (install AviSynth+ 3.6 or later)"),
            error.MissingSymbol, error.TooOld => mo.setError("avsr: AviSynth+ is too old (3.6+ / interface V8 required)"),
            else => {
                const msg = avs.getEvalError();
                if (msg.len > 0) {
                    mo.setError(msg);
                } else {
                    mo.setError("avsr: failed to create AviSynth environment");
                }
            },
        }
        return;
    };

    const mapped = avs_env.mapFormat() catch {
        mo.setError("avsr: unsupported pixel format");
        avs_env.deinit();
        return;
    };
    const color_family: vs.ColorFamily = switch (mapped.family) {
        .Gray => .Gray,
        .RGB => .RGB,
        .YUV => .YUV,
    };
    const sample_type: vs.SampleType = if (mapped.is_float) .Float else .Integer;

    const fmt = blk: {
        var f: vs.VideoFormat = undefined;
        if (zapi.queryVideoFormat(&f, color_family, sample_type, mapped.bits, mapped.sub_w, mapped.sub_h) != 0)
            break :blk f;
        break :blk null;
    } orelse {
        mo.setError("avsr: unsupported pixel format");
        avs_env.deinit();
        return;
    };

    const data = std.heap.c_allocator.create(AvsReader) catch {
        mo.setError("avsr: allocation failed");
        avs_env.deinit();
        return;
    };

    data.* = .{
        .avs_env = avs_env,
        .vi = .{
            .format = fmt,
            .fpsNum = avs_env.vi.fps_numerator,
            .fpsDen = avs_env.vi.fps_denominator,
            .width = avs_env.vi.width,
            .height = avs_env.vi.height,
            .numFrames = avs_env.vi.num_frames,
        },
        .num_planes = mapped.num_planes,
        .avs_planes = mapped.planes,
    };

    const deps = [_]vs.FilterDependency{};

    zapi.createVideoFilter(
        out, mode, &data.vi,
        avsrGetFrame, avsrFree,
        .Unordered, &deps, data,
    );
}
