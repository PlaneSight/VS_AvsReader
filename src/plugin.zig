//! VS_AvsReader — AviSynth script reader for VapourSynth (Zig ZAPI + C API)
const std = @import("std");
const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;
const ZAPI = vapoursynth.ZAPI;

const avs = @import("avs_capi.zig");

const AvsReader = struct {
    avs_env: avs.Env,
    vi: vs.VideoInfo,
    write_frame: WriteFrameFn,
};

const WriteFrameFn = *const fn (
    reader: *const AvsReader,
    dst: *vs.Frame,
    n: c_int,
    zapi: *const ZAPI,
) void;

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

    if (activation_reason == .Initial) {
        const dst = zapi.newVideoFrame(
            &d.vi.format, d.vi.width, d.vi.height, null,
        ) orelse return null;

        const props = zapi.getFramePropertiesRW(dst);
        _ = zapi.mapSetInt(props, "_DurationNum", d.vi.fpsDen, .Replace);
        _ = zapi.mapSetInt(props, "_DurationDen", d.vi.fpsNum, .Replace);

        d.write_frame(d, dst, n, &zapi);
        return dst;
    }
    return null;
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

fn writeYUV(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    const frame = reader.avs_env.getFrame(n) orelse return;
    var p: u32 = 0;
    while (p < 3) : (p += 1) {
        const src = reader.avs_env.getReadPtr(frame, @intCast(p)) orelse break;
        const sp = reader.avs_env.getPitch(frame, @intCast(p));
        const rs = reader.avs_env.getRowSize(frame, @intCast(p));
        const h = reader.avs_env.getHeight(frame, @intCast(p));
        const dp = zapi.getWritePtr(dst, @intCast(p));
        const ds = zapi.getStride(dst, @intCast(p));

        var y: i32 = 0;
        while (y < h) : (y += 1) {
            const yu = @as(usize, @intCast(y));
            @memcpy(dp[yu * @as(usize, @intCast(ds)) ..][0..@intCast(rs)],
                    src[yu * @as(usize, @intCast(sp)) ..][0..@intCast(rs)]);
        }
    }
}

fn writeRGB24(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    writeRGB(reader, dst, n, zapi, 3);
}

fn writeRGB32(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    writeRGB(reader, dst, n, zapi, 4);
}

// AviSynth BGR is bottom-up; VapourSynth RGB is top-down.
// sy walks source rows h-1→0, dy walks dest rows 0→h-1.
fn writeRGB(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI, channels: i32) void {
    const frame = reader.avs_env.getFrame(n) orelse return;
    const src = reader.avs_env.getReadPtr(frame, 0) orelse return;
    const sp = reader.avs_env.getPitch(frame, 0);
    const rb = reader.avs_env.getRowSize(frame, 0);
    const h  = reader.avs_env.getHeight(frame, 0);
    const w  = @divExact(rb, channels);
    const ds = zapi.getStride(dst, 0);
    const dr = zapi.getWritePtr(dst, 0);
    const dg = zapi.getWritePtr(dst, 1);
    const db = zapi.getWritePtr(dst, 2);

    var sy: i32 = h - 1;
    var dy: i32 = 0;
    while (dy < h) : ({ dy += 1; sy -= 1; }) {
        const dy_off = @as(usize, @intCast(dy)) * @as(usize, @intCast(ds));
        const sy_off = @as(usize, @intCast(sy)) * @as(usize, @intCast(sp));
        var x: i32 = 0;
        while (x < w) : (x += 1) {
            const off = @as(usize, @intCast(x)) * @as(usize, @intCast(channels));
            const dx = @as(usize, @intCast(x));
            db[dy_off + dx] = src[sy_off + off + 0];
            dg[dy_off + dx] = src[sy_off + off + 1];
            dr[dy_off + dx] = src[sy_off + off + 2];
        }
    }
}

fn writeGray(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    const frame = reader.avs_env.getFrame(n) orelse return;
    const src = reader.avs_env.getReadPtr(frame, 0) orelse return;
    const sp = reader.avs_env.getPitch(frame, 0);
    const rs = reader.avs_env.getRowSize(frame, 0);
    const h  = reader.avs_env.getHeight(frame, 0);
    const dp = zapi.getWritePtr(dst, 0);
    const ds = zapi.getStride(dst, 0);

    var y: i32 = 0;
    while (y < h) : (y += 1) {
        const yu = @as(usize, @intCast(y));
        @memcpy(dp[yu * @as(usize, @intCast(ds)) ..][0..@intCast(rs)],
                src[yu * @as(usize, @intCast(sp)) ..][0..@intCast(rs)]);
    }
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
    const input = if (mode[0] == 'E')
        mi.getData("lines", 0) orelse ""
    else
        mi.getData("script", 0) orelse "";

    if (bitdepth != 8 and bitdepth != 9 and bitdepth != 10 and bitdepth != 16) {
        mo.setError("avsr: invalid bitdepth");
        return;
    }
    if (input.len < 1) {
        mo.setError("avsr: empty script");
        return;
    }

    var avs_env = avs.Env.init(input) catch {
        mo.setError("avsr: failed to create AviSynth environment");
        return;
    };

    const cf = avs_env.colorFamily();
    const ss = avs_env.subSampling();
    const color_family: vs.ColorFamily = switch (cf) {
        .Gray => .Gray,
        .RGB => .RGB,
        .YUV => .YUV,
    };

    const fmt = blk: {
        var f: vs.VideoFormat = undefined;
        if (vsapi.?.queryVideoFormat.?(&f, color_family, .Integer, 8, ss.w, ss.h, core) != 0)
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

    const vs_width: i32 = if (bitdepth > 8) @divTrunc(avs_env.vi.width, 2) else avs_env.vi.width;

    const writer: WriteFrameFn = switch (cf) {
        .RGB => if (avs_env.vi.pixel_type == @intFromEnum(avs.PixelType.RGB32)) writeRGB32 else writeRGB24,
        .Gray => writeGray,
        .YUV => writeYUV,
    };

    data.* = .{
        .avs_env = avs_env,
        .vi = .{
            .format = fmt,
            .fpsNum = avs_env.vi.fps_numerator,
            .fpsDen = avs_env.vi.fps_denominator,
            .width = vs_width,
            .height = avs_env.vi.height,
            .numFrames = avs_env.vi.num_frames,
        },
        .write_frame = writer,
    };

    const deps = [_]vs.FilterDependency{};

    zapi.createVideoFilter(
        out, mode, &data.vi,
        avsrGetFrame, avsrFree,
        .Unordered, &deps, data,
    );
}
