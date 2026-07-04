//! VS_AvsReader — AviSynth script reader for VapourSynth (Zig ZAPI rewrite)
//! Every CPU cycle matters. Memory is a resource.
const std = @import("std");
const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;
const ZAPI = vapoursynth.ZAPI;

const PLUGIN_ID = "chikuzen.does.not.have.his.own.domain.avsr";
const PLUGIN_NAMESPACE = "avsr";
const PLUGIN_NAME = "AviSynth Script Reader for VapourSynth v3.0.0";

// C bridge: dlopen → AviSynth+ script environment
const c_api = @cImport({
    @cInclude("capi.h");
});

// ---------------------------------------------------------------------------
// Per-instance data — one AvsReader per Import/Eval call
// ---------------------------------------------------------------------------
const AvsReader = struct {
    env: *c_api.AVSR_Env,
    vi: vs.VideoInfo,
    viAVS: c_api.AVSR_VideoInfo,
    write_frame: WriteFrameFn,
    alloc: std.mem.Allocator,
};

const WriteFrameFn = *const fn (
    reader: *const AvsReader,
    dst: *vs.Frame,
    n: c_int,
    zapi: *const ZAPI,
) void;

// ---------------------------------------------------------------------------
// GetFrame callback
// ---------------------------------------------------------------------------
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
        // Source filter: no input nodes to request.  Allocate and return.
        const dst = zapi.newVideoFrame(
            &d.vi.format, d.vi.width, d.vi.height, null,
        ) orelse return null;

        // Set duration frame properties
        const frame_props = zapi.getFramePropertiesRW(dst);
        _ = zapi.mapSetInt(frame_props, "_DurationNum", d.vi.fpsDen, .Replace);
        _ = zapi.mapSetInt(frame_props, "_DurationDen", d.vi.fpsNum, .Replace);

        d.write_frame(d, dst, n, &zapi);
        return dst;
    }

    return null;
}

// ---------------------------------------------------------------------------
// Free callback
// ---------------------------------------------------------------------------
fn avsrFree(
    instance_data: ?*anyopaque,
    _: ?*vs.Core,
    _: ?*const vs.API,
) callconv(.c) void {
    const d: *AvsReader = @ptrCast(@alignCast(instance_data));
    c_api.avsr_close(d.env);
    d.alloc.destroy(d);
}

// ---------------------------------------------------------------------------
// Plane writers — convert AviSynth frame layout to VS
// ---------------------------------------------------------------------------

fn writeYUV(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    var planes: c_api.AVSR_FramePlanes = undefined;
    if (c_api.avsr_get_frame(reader.env, n, &planes) != 0) return;

    var p: u32 = 0;
    while (p < 3) : (p += 1) {
        const src = planes.read_ptr[p];
        if (src == null) break;
        const src_pitch = planes.pitch[p];
        const row_size = planes.row_size[p];
        const height = planes.height[p];
        const dst_ptr = zapi.getWritePtr(dst, @intCast(p));
        const dst_stride = zapi.getStride(dst, @intCast(p));

        var y: i32 = 0;
        while (y < height) : (y += 1) {
            const src_row = src + @as(usize, @intCast(y)) * @as(usize, @intCast(src_pitch));
            const dst_row = dst_ptr + @as(usize, @intCast(y)) * @as(usize, @intCast(dst_stride));
            @memcpy(dst_row[0..@intCast(row_size)], src_row[0..@intCast(row_size)]);
        }
    }
}

fn writeRGB(
    reader: *const AvsReader,
    dst: *vs.Frame,
    n: c_int,
    zapi: *const ZAPI,
    channels: i32,
) void {
    var planes: c_api.AVSR_FramePlanes = undefined;
    if (c_api.avsr_get_frame(reader.env, n, &planes) != 0) return;

    const src = planes.read_ptr[0];
    const spitch = planes.pitch[0];
    const row_bytes = planes.row_size[0];
    const height = planes.height[0];
    const width = @divExact(row_bytes, channels);

    const dstride = zapi.getStride(dst, 0);
    const dptr_r = zapi.getWritePtr(dst, 0);
    const dptr_g = zapi.getWritePtr(dst, 1);
    const dptr_b = zapi.getWritePtr(dst, 2);

    // AviSynth BGR is bottom-up; start from last row
    var src_row = src + @as(usize, @intCast(height - 1)) * @as(usize, @intCast(spitch));
    var y: i32 = 0;
    while (y < height) : (y += 1) {
        const off_y = @as(usize, @intCast(y)) * @as(usize, @intCast(dstride));
        var x: i32 = 0;
        while (x < width) : (x += 1) {
            const off = @as(usize, @intCast(x)) * @as(usize, @intCast(channels));
            dptr_b[off_y + @as(usize, @intCast(x))] = src_row[off + 0];
            dptr_g[off_y + @as(usize, @intCast(x))] = src_row[off + 1];
            dptr_r[off_y + @as(usize, @intCast(x))] = src_row[off + 2];
        }
        src_row -= @as(usize, @intCast(spitch));
    }
}

fn writeGray(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    var planes: c_api.AVSR_FramePlanes = undefined;
    if (c_api.avsr_get_frame(reader.env, n, &planes) != 0) return;

    const src = planes.read_ptr[0];
    const src_pitch = planes.pitch[0];
    const row_size = planes.row_size[0];
    const height = planes.height[0];
    const dst_ptr = zapi.getWritePtr(dst, 0);
    const dst_stride = zapi.getStride(dst, 0);

    var y: i32 = 0;
    while (y < height) : (y += 1) {
        const src_row = src + @as(usize, @intCast(y)) * @as(usize, @intCast(src_pitch));
        const dst_row = dst_ptr + @as(usize, @intCast(y)) * @as(usize, @intCast(dst_stride));
        @memcpy(dst_row[0..@intCast(row_size)], src_row[0..@intCast(row_size)]);
    }
}

fn writeRGB24(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    writeRGB(reader, dst, n, zapi, 3);
}

fn writeRGB32(reader: *const AvsReader, dst: *vs.Frame, n: c_int, zapi: *const ZAPI) void {
    writeRGB(reader, dst, n, zapi, 4);
}

// ---------------------------------------------------------------------------
// Resolve VapourSynth format from AviSynth pixel_type
// ---------------------------------------------------------------------------
fn resolveFormat(avs_pixel_type: i32, core: *vs.Core, vsapi: *const vs.API) ?vs.VideoFormat {
    var cf: c_int = 0;
    var sw: c_int = 0;
    var sh: c_int = 0;
    if (c_api.avsr_get_vs_format(avs_pixel_type, &cf, &sw, &sh) != 0) return null;
    const color_family: vs.ColorFamily = switch (cf) {
        1 => .Gray,
        2 => .RGB,
        3 => .YUV,
        else => return null,
    };
    var fmt: vs.VideoFormat = undefined;
    const rc = vsapi.queryVideoFormat.?(&fmt, color_family, .Integer, 8, sw, sh, core);
    if (rc != 0) return fmt;
    return null;
}

// ---------------------------------------------------------------------------
// Plugin entry point
// ---------------------------------------------------------------------------
export fn VapourSynthPluginInit2(
    plugin: *vs.Plugin,
    vspapi: *const vs.PLUGINAPI,
) void {
    ZAPI.Plugin.config(
        PLUGIN_ID,
        PLUGIN_NAMESPACE,
        PLUGIN_NAME,
        .{ .major = 3, .minor = 0, .patch = 0 },
        plugin,
        vspapi,
    );

    // Import: load an .avs file
    ZAPI.Plugin.function(
        "Import",
        "script:data;bitdepth:int:opt;alpha:int:opt;",
        "clip:vnode;",
        importCreate,
        plugin,
        vspapi,
    );

    // Eval: evaluate inline AviSynth code
    ZAPI.Plugin.function(
        "Eval",
        "lines:data;bitdepth:int:opt;alpha:int:opt;",
        "clip:vnode;",
        evalCreate,
        plugin,
        vspapi,
    );
}

fn importCreate(
    in: ?*const vs.Map,
    out: ?*vs.Map,
    _: ?*anyopaque,
    core: ?*vs.Core,
    vsapi: ?*const vs.API,
) callconv(.c) void {
    createFilter(in, out, "Import", core, vsapi);
}

fn evalCreate(
    in: ?*const vs.Map,
    out: ?*vs.Map,
    _: ?*anyopaque,
    core: ?*vs.Core,
    vsapi: ?*const vs.API,
) callconv(.c) void {
    createFilter(in, out, "Eval", core, vsapi);
}

fn createFilter(
    in: ?*const vs.Map,
    out: ?*vs.Map,
    mode: [:0]const u8,
    core: ?*vs.Core,
    vsapi: ?*const vs.API,
) void {
    const zapi = ZAPI.init(vsapi, core, null);
    const map_in = zapi.initZMap(in);
    const map_out = zapi.initZMap(out);

    // Parse arguments
    const bitdepth = map_in.getValue(i32, "bitdepth") orelse 8;
    const input = if (mode[0] == 'E')
        map_in.getData("lines", 0) orelse ""
    else
        map_in.getData("script", 0) orelse "";
    const alpha = map_in.getBool("alpha") orelse true;
    _ = alpha; // alpha extraction not yet implemented in Zig port

    // Validate
    if (bitdepth != 8 and bitdepth != 9 and bitdepth != 10 and bitdepth != 16) {
        map_out.setError("avsr: invalid bitdepth");
        return;
    }
    if (input.len < 1) {
        map_out.setError("avsr: empty script");
        return;
    }

    // Create AviSynth environment and evaluate script
    const input_z: [*c]const u8 = @ptrCast(input.ptr);
    const env: ?*c_api.AVSR_Env = if (mode[0] == 'E')
        c_api.avsr_eval(input_z) orelse blk: {
            const msg = c_api.avsr_last_error();
            map_out.setError(msg[0..std.mem.len(msg) :0]);
            break :blk null;
        }
    else
        c_api.avsr_import(input_z) orelse blk: {
            const msg = c_api.avsr_last_error();
            map_out.setError(msg[0..std.mem.len(msg) :0]);
            break :blk null;
        };

    const avsr_env = env orelse return;

    var avs_vi: c_api.AVSR_VideoInfo = undefined;
    if (c_api.avsr_get_info(avsr_env, &avs_vi) != 0) {
        map_out.setError("avsr: failed to get video info");
        c_api.avsr_close(avsr_env);
        return;
    }

    // Resolve VS format
    const fmt = resolveFormat(avs_vi.pixel_type, core.?, vsapi.?) orelse {
        map_out.setError("avsr: unsupported AviSynth pixel type");
        c_api.avsr_close(avsr_env);
        return;
    };

    // Allocate instance data
    const alloc = std.heap.c_allocator;
    const data = alloc.create(AvsReader) catch {
        map_out.setError("avsr: allocation failed");
        c_api.avsr_close(avsr_env);
        return;
    };

    // Build VS VideoInfo
    const vs_width: i32 = if (bitdepth > 8) @divTrunc(avs_vi.width, 2) else avs_vi.width;
    const vi = vs.VideoInfo{
        .format = fmt,
        .fpsNum = avs_vi.fps_num,
        .fpsDen = avs_vi.fps_den,
        .width = vs_width,
        .height = avs_vi.height,
        .numFrames = avs_vi.num_frames,
    };

    // Select plane writer based on pixel type
    // Use the C bridge for reliable format comparison
    var cf2: c_int = 0;
    var sw2: c_int = 0;
    var sh2: c_int = 0;
    _ = c_api.avsr_get_vs_format(avs_vi.pixel_type, &cf2, &sw2, &sh2);
    const is_rgb = cf2 == 2;
    const is_rgba = is_rgb and avs_vi.has_alpha != 0;
    const is_gray = cf2 == 1;

    const writer: WriteFrameFn = if (is_rgba)
        writeRGB32
    else if (is_rgb)
        writeRGB24
    else if (is_gray)
        writeGray
    else
        writeYUV;

    data.* = .{
        .env = avsr_env,
        .vi = vi,
        .viAVS = avs_vi,
        .write_frame = writer,
        .alloc = alloc,
    };

    const deps = [_]vs.FilterDependency{}; // source filter: no input clip

    zapi.createVideoFilter(
        out,
        mode,
        &data.vi,
        avsrGetFrame,
        avsrFree,
        .Unordered,
        &deps,
        data,
    );
}
