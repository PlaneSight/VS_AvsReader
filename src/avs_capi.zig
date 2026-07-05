// avs_capi.zig — Pure Zig FFI for AviSynth+ C API, loaded at runtime via dlopen.
//
// libavisynth is never link-time bound: the plugin must load into VapourSynth
// on machines without AviSynth+ and only error when avsr.* is actually invoked.
const std = @import("std");
const builtin = @import("builtin");

pub const ScriptEnvironment = opaque {};
pub const Clip = opaque {};
pub const VideoFrame = opaque {};
pub const Map = opaque {}; // AVS_Map — frame property map (interface V8+)

// image_type bits (avisynth_c.h AVS_IT_*)
pub const IT_BFF: u32 = 1 << 0;
pub const IT_TFF: u32 = 1 << 1;
pub const IT_FIELDBASED: u32 = 1 << 2;

// AVS_PROPTYPE_* — returned by avs_prop_get_type
pub const PropType = struct {
    pub const UNSET: u8 = 'u';
    pub const INT: u8 = 'i';
    pub const FLOAT: u8 = 'f';
    pub const DATA: u8 = 's';
    pub const CLIP: u8 = 'c';
    pub const FRAME: u8 = 'v';
};

// AviSynth plane constants are bitmasks, not sequential indices.
// avisynth_c.h: AVS_DEFAULT_PLANE=0, AVS_PLANAR_Y=1, AVS_PLANAR_U=2,
// AVS_PLANAR_V=4, AVS_PLANAR_A=16, AVS_PLANAR_R=32, AVS_PLANAR_G=64, AVS_PLANAR_B=128
pub const Plane = struct {
    pub const Y: c_int = 0; // AVS_DEFAULT_PLANE
    pub const U: c_int = 2; // AVS_PLANAR_U (1 << 1)
    pub const V: c_int = 4; // AVS_PLANAR_V (1 << 2)
    pub const A: c_int = 16; // AVS_PLANAR_A (1 << 4)
    pub const R: c_int = 32; // AVS_PLANAR_R (1 << 5)
    pub const G: c_int = 64; // AVS_PLANAR_G (1 << 6)
    pub const B: c_int = 128; // AVS_PLANAR_B (1 << 7)
};

// Layout-identical to AVS_VideoInfo in avisynth_c.h
pub const VideoInfo = extern struct {
    width: c_int,
    height: c_int,
    fps_numerator: c_uint,
    fps_denominator: c_uint,
    num_frames: c_int,
    pixel_type: c_int,
    audio_samples_per_second: c_int,
    sample_type: c_int,
    num_audio_samples: i64,
    nchannels: c_int,
    image_type: c_int,
};

// Pixel type flags from avisynth_c.h
const CS_BGR: u32 = 1 << 28;
const CS_YUV: u32 = 1 << 29;
const CS_INTERLEAVED: u32 = 1 << 30;
const CS_PLANAR: u32 = 1 << 31;
const CS_RGBA_TYPE: u32 = 1 << 1;
const CS_YUY2: u32 = 1 << 2 | CS_YUV | CS_INTERLEAVED;

// AVS_Value — layout-identical to C struct (16 bytes on 64-bit).
// The union is 8 bytes: largest member is a pointer/int64/double.
pub const AVS_Value = extern struct {
    type: c_short,
    array_size: c_short,
    d: extern union {
        clip: ?*Clip,
        string: [*c]const u8,
        int_num: c_int,
        float_num: f32,
        longlong: i64,
        double_pt: f64,
    },
};

comptime {
    std.debug.assert(@sizeOf(AVS_Value) == 16);
    std.debug.assert(@sizeOf(VideoInfo) == 48);
}

/// Function pointers resolved from libavisynth. Every field name is the
/// exact export name; Lib.load resolves them by iterating the fields, so
/// adding a function is a one-line change. Only symbols exported since
/// AviSynth+ 3.6 (interface V8) belong here — V11-only setters like
/// avs_set_to_string are reimplemented inline instead.
pub const Fns = struct {
    avs_create_script_environment: *const fn (c_int) callconv(.c) ?*ScriptEnvironment,
    avs_delete_script_environment: *const fn (?*ScriptEnvironment) callconv(.c) void,
    avs_check_version: *const fn (?*ScriptEnvironment, c_int) callconv(.c) c_int,
    avs_invoke: *const fn (?*ScriptEnvironment, [*c]const u8, AVS_Value, [*c]const [*c]const u8) callconv(.c) AVS_Value,
    avs_release_value: *const fn (AVS_Value) callconv(.c) void,
    avs_set_to_clip: *const fn (*AVS_Value, ?*Clip) callconv(.c) void,
    avs_take_clip: *const fn (AVS_Value, ?*ScriptEnvironment) callconv(.c) ?*Clip,
    avs_release_clip: *const fn (?*Clip) callconv(.c) void,
    avs_get_video_info: *const fn (?*Clip) callconv(.c) ?*const VideoInfo,
    avs_clip_get_error: *const fn (?*Clip) callconv(.c) ?[*:0]const u8,
    avs_get_frame: *const fn (?*Clip, c_int) callconv(.c) ?*VideoFrame,
    avs_release_video_frame: *const fn (?*VideoFrame) callconv(.c) void,
    avs_get_read_ptr_p: *const fn (?*const VideoFrame, c_int) callconv(.c) ?[*]const u8,
    avs_get_pitch_p: *const fn (?*const VideoFrame, c_int) callconv(.c) c_int,
    avs_get_row_size_p: *const fn (?*const VideoFrame, c_int) callconv(.c) c_int,
    avs_get_height_p: *const fn (?*const VideoFrame, c_int) callconv(.c) c_int,
    // AVS+ format query exports — decode pixel_type structurally so every
    // current and future format maps without a lookup table.
    avs_bits_per_component: *const fn (?*const VideoInfo) callconv(.c) c_int,
    avs_component_size: *const fn (?*const VideoInfo) callconv(.c) c_int,
    avs_is_y: *const fn (?*const VideoInfo) callconv(.c) c_int,
    avs_is_yuva: *const fn (?*const VideoInfo) callconv(.c) c_int,
    avs_is_planar_rgb: *const fn (?*const VideoInfo) callconv(.c) c_int,
    avs_is_planar_rgba: *const fn (?*const VideoInfo) callconv(.c) c_int,
    avs_get_plane_width_subsampling: *const fn (?*const VideoInfo, c_int) callconv(.c) c_int,
    avs_get_plane_height_subsampling: *const fn (?*const VideoInfo, c_int) callconv(.c) c_int,
};

/// Frame property exports (interface V8+, AviSynth+ 3.6). Loaded separately
/// from Fns: if any is missing the plugin still works, it just skips prop
/// bridging. avs_prop_get_data_type_hint is V11-only, hence optional even here.
pub const PropFns = struct {
    avs_get_frame_props_ro: *const fn (?*ScriptEnvironment, ?*const VideoFrame) callconv(.c) ?*const Map,
    avs_prop_num_keys: *const fn (?*ScriptEnvironment, ?*const Map) callconv(.c) c_int,
    avs_prop_get_key: *const fn (?*ScriptEnvironment, ?*const Map, c_int) callconv(.c) ?[*:0]const u8,
    avs_prop_num_elements: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8) callconv(.c) c_int,
    avs_prop_get_type: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8) callconv(.c) u8,
    avs_prop_get_int: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, c_int, ?*c_int) callconv(.c) i64,
    avs_prop_get_float: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, c_int, ?*c_int) callconv(.c) f64,
    avs_prop_get_data: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, c_int, ?*c_int) callconv(.c) ?[*]const u8,
    avs_prop_get_data_size: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, c_int, ?*c_int) callconv(.c) c_int,
    avs_prop_get_int_array: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, ?*c_int) callconv(.c) ?[*]const i64,
    avs_prop_get_float_array: *const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, ?*c_int) callconv(.c) ?[*]const f64,
    avs_prop_get_data_type_hint: ?*const fn (?*ScriptEnvironment, ?*const Map, [*c]const u8, c_int, ?*c_int) callconv(.c) c_int,
};

pub const LoadError = error{ AvisynthNotFound, MissingSymbol };

pub const Lib = struct {
    dylib: std.DynLib,
    fns: Fns,
    prop_fns: ?PropFns,

    pub fn load() LoadError!Lib {
        // The unversioned name only exists with dev symlinks installed; the
        // soname (SOVERSION 11 = interface version) is always present.
        const names: []const []const u8 = switch (builtin.os.tag) {
            .macos => &.{
                "libavisynth.dylib",
                "libavisynth.11.dylib",
                "/usr/local/lib/libavisynth.dylib",
                "/usr/local/lib/libavisynth.11.dylib",
                "/opt/homebrew/lib/libavisynth.dylib",
                "/opt/homebrew/lib/libavisynth.11.dylib",
            },
            else => &.{ "libavisynth.so", "libavisynth.so.11" },
        };
        var dylib = for (names) |n| {
            break std.DynLib.open(n) catch continue;
        } else return error.AvisynthNotFound;
        errdefer dylib.close();

        var fns: Fns = undefined;
        inline for (@typeInfo(Fns).@"struct".fields) |f| {
            @field(fns, f.name) = dylib.lookup(f.type, f.name) orelse
                return error.MissingSymbol;
        }

        // Optional-typed fields may be absent; a missing required field
        // disables prop bridging entirely instead of failing the load.
        const prop_fns: ?PropFns = blk: {
            var pf: PropFns = undefined;
            inline for (@typeInfo(PropFns).@"struct".fields) |f| {
                if (@typeInfo(f.type) == .optional) {
                    @field(pf, f.name) = dylib.lookup(@typeInfo(f.type).optional.child, f.name);
                } else {
                    @field(pf, f.name) = dylib.lookup(f.type, f.name) orelse break :blk null;
                }
            }
            break :blk pf;
        };

        return .{ .dylib = dylib, .fns = fns, .prop_fns = prop_fns };
    }
};

// libavisynth is loaded once and kept for the process lifetime: filter
// instances share the symbols and an unload/reload cycle buys nothing.
var g_lib: ?Lib = null;
var g_lib_mutex: std.atomic.Mutex = .unlocked;

fn acquireFns() LoadError!*const Fns {
    // Spinning is fine here: this only runs at filter creation, and the
    // critical section is one dlopen plus symbol lookups.
    while (!g_lib_mutex.tryLock()) std.Thread.yield() catch {};
    defer g_lib_mutex.unlock();
    if (g_lib == null) g_lib = try Lib.load();
    return &g_lib.?.fns;
}

// Only meaningful after acquireFns succeeded (i.e. while an Env exists).
fn loadedPropFns() ?*const PropFns {
    if (g_lib) |*lib| {
        if (lib.prop_fns) |*pf| return pf;
    }
    return null;
}

// AVS_Value type testers (inline in C header, reimplemented here).
// Type codes: 'c'=clip, 'e'=error, 'v'=void, 's'=string, etc.
fn avsIsClip(v: AVS_Value) bool { return v.type == 'c'; }
fn avsIsError(v: AVS_Value) bool { return v.type == 'e'; }
fn avsAsString(v: AVS_Value) ?[*:0]const u8 {
    if (v.type != 's' and v.type != 'e') return null;
    return @ptrCast(v.d.string);
}

// Baked inline setter from the header ("does not require avs_release_value").
fn avsNewValueString(s: [*c]const u8) AVS_Value {
    return .{ .type = 's', .array_size = 1, .d = .{ .string = s } };
}

/// Thread-local buffer for the last AviSynth error message.
/// Written by Env.init on EvalError, read by getEvalError.
threadlocal var last_eval_error: [512]u8 = [_]u8{0} ** 512;
threadlocal var last_eval_error_len: usize = 0;

/// Returns the error message from the most recent failed avs_invoke on this thread.
pub fn getEvalError() [:0]const u8 {
    return last_eval_error[0..last_eval_error_len :0];
}

fn captureError(msg: ?[*:0]const u8) void {
    if (msg) |m| {
        const src_len = std.mem.len(m);
        last_eval_error_len = @min(src_len, 511);
        @memcpy(last_eval_error[0..last_eval_error_len], m[0..last_eval_error_len]);
        last_eval_error[last_eval_error_len] = 0;
    } else {
        last_eval_error_len = 0;
        last_eval_error[0] = 0;
    }
}

/// Format description mapped to VapourSynth terms, including the AVS plane
/// request order for VS plane indices 0..num_planes-1.
pub const MappedFormat = struct {
    family: enum { Gray, RGB, YUV },
    is_float: bool,
    bits: c_int,
    sub_w: c_int,
    sub_h: c_int,
    num_planes: u8,
    planes: [3]c_int,
};

pub const Env = struct {
    fns: *const Fns,
    prop_fns: ?*const PropFns,
    raw: *ScriptEnvironment,
    clip: *Clip,
    vi: VideoInfo,

    /// `mode` is "Import" or "Eval"; `input` a file path or script body.
    /// After evaluation, packed formats are normalized to planar inside the
    /// AVS domain (YUY2 → YV16, interleaved RGB → planar RGB/RGBA) so the
    /// frame path is a single planar blit.
    pub fn init(mode: [:0]const u8, input: []const u8) !Env {
        const f = try acquireFns();

        const env = f.avs_create_script_environment(8) orelse return error.CreateFailed;
        errdefer f.avs_delete_script_environment(env);
        if (f.avs_check_version(env, 8) != 0) return error.TooOld;

        const args = avsNewValueString(input.ptr);
        const result = f.avs_invoke(env, mode.ptr, args, null);
        defer f.avs_release_value(result);

        // avs_take_clip on a non-clip value (error/void) crashes; check first.
        if (avsIsError(result)) {
            captureError(avsAsString(result));
            return error.EvalError;
        }
        if (!avsIsClip(result)) return error.NotAClip;

        const clip = f.avs_take_clip(result, env) orelse return error.NotAClip;
        errdefer f.avs_release_clip(clip);
        const vi_ptr = f.avs_get_video_info(clip) orelse return error.NoVideo;
        if (vi_ptr.width == 0) return error.NoVideo;

        var self = Env{
            .fns = f,
            .prop_fns = loadedPropFns(),
            .raw = env,
            .clip = clip,
            .vi = vi_ptr.*,
        };

        const pt: u32 = @bitCast(self.vi.pixel_type);
        if ((pt & CS_YUY2) == CS_YUY2) {
            try self.convert("ConvertToYV16");
        } else if ((pt & CS_BGR) != 0 and (pt & CS_PLANAR) == 0) {
            // Interleaved RGB is bottom-up BGR; planar RGB is top-down like YUV.
            if ((pt & CS_RGBA_TYPE) != 0)
                try self.convert("ConvertToPlanarRGBA")
            else
                try self.convert("ConvertToPlanarRGB");
        }

        return self;
    }

    /// Invoke a conversion filter (e.g. "ConvertToYV16") on the held clip,
    /// replacing clip and vi.
    fn convert(self: *Env, name: [:0]const u8) !void {
        const f = self.fns;
        var cval: AVS_Value = undefined;
        f.avs_set_to_clip(&cval, self.clip);
        defer f.avs_release_value(cval);

        const result = f.avs_invoke(self.raw, name.ptr, cval, null);
        defer f.avs_release_value(result);

        if (avsIsError(result)) {
            captureError(avsAsString(result));
            return error.EvalError;
        }
        if (!avsIsClip(result)) return error.NotAClip;

        const new_clip = f.avs_take_clip(result, self.raw) orelse return error.NotAClip;
        const vi_ptr = f.avs_get_video_info(new_clip) orelse {
            f.avs_release_clip(new_clip);
            return error.NoVideo;
        };
        f.avs_release_clip(self.clip);
        self.clip = new_clip;
        self.vi = vi_ptr.*;
    }

    pub fn deinit(self: *Env) void {
        self.fns.avs_release_clip(self.clip);
        self.fns.avs_delete_script_environment(self.raw);
    }

    pub fn getFrame(self: *const Env, n: c_int) ?*VideoFrame {
        return self.fns.avs_get_frame(self.clip, n);
    }

    /// Returns the pending error on the clip, if any. Must be checked after
    /// getFrame: AviSynth reports frame errors here, not by returning null.
    pub fn getClipError(self: *const Env) ?[*:0]const u8 {
        return self.fns.avs_clip_get_error(self.clip);
    }

    pub fn releaseFrame(self: *const Env, frame: ?*VideoFrame) void {
        self.fns.avs_release_video_frame(frame);
    }

    pub fn getReadPtr(self: *const Env, frame: *const VideoFrame, plane: c_int) ?[*]const u8 {
        return self.fns.avs_get_read_ptr_p(frame, plane);
    }

    pub fn getPitch(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        return self.fns.avs_get_pitch_p(frame, plane);
    }

    pub fn getRowSize(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        return self.fns.avs_get_row_size_p(frame, plane);
    }

    pub fn getHeight(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        return self.fns.avs_get_height_p(frame, plane);
    }

    /// Maps the (post-normalization, therefore planar) clip format to
    /// VapourSynth terms using the AVS+ structural query exports.
    pub fn mapFormat(self: *const Env) error{Unsupported}!MappedFormat {
        const f = self.fns;
        const vi = &self.vi;
        const pt: u32 = @bitCast(vi.pixel_type);
        const bits = f.avs_bits_per_component(vi);
        const is_float = f.avs_component_size(vi) == 4;

        if (f.avs_is_planar_rgb(vi) != 0 or f.avs_is_planar_rgba(vi) != 0) return .{
            .family = .RGB,
            .is_float = is_float,
            .bits = bits,
            .sub_w = 0,
            .sub_h = 0,
            .num_planes = 3, // alpha plane of RGBAP is dropped (not yet implemented)
            .planes = .{ Plane.R, Plane.G, Plane.B },
        };
        if (f.avs_is_y(vi) != 0) return .{
            .family = .Gray,
            .is_float = is_float,
            .bits = bits,
            .sub_w = 0,
            .sub_h = 0,
            .num_planes = 1,
            .planes = .{ Plane.Y, 0, 0 },
        };
        if ((pt & CS_PLANAR) != 0 and ((pt & CS_YUV) != 0 or f.avs_is_yuva(vi) != 0)) return .{
            .family = .YUV,
            .is_float = is_float,
            .bits = bits,
            .sub_w = f.avs_get_plane_width_subsampling(vi, Plane.U),
            .sub_h = f.avs_get_plane_height_subsampling(vi, Plane.U),
            .num_planes = 3, // alpha plane of YUVA is dropped (not yet implemented)
            .planes = .{ Plane.Y, Plane.U, Plane.V },
        };
        // Packed formats must have been normalized in init; anything left is
        // genuinely unknown.
        return error.Unsupported;
    }
};
