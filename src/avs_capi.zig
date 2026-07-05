// avs_capi.zig — Pure Zig FFI for AviSynth+ C API
const std = @import("std");

pub const ScriptEnvironment = opaque {};
pub const Clip = opaque {};
pub const VideoFrame = opaque {};

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

extern fn avs_create_script_environment(version: c_int) ?*ScriptEnvironment;
extern fn avs_delete_script_environment(env: ?*ScriptEnvironment) void;

extern fn avs_set_to_string(val: *AVS_Value, s: [*c]const u8) void;
extern fn avs_set_to_clip(val: *AVS_Value, clip: ?*Clip) void;
extern fn avs_release_value(v: AVS_Value) void;

extern fn avs_invoke(env: ?*ScriptEnvironment, name: [*c]const u8, args: AVS_Value, arg_names: [*c]const [*c]const u8) AVS_Value;

extern fn avs_take_clip(v: AVS_Value, env: ?*ScriptEnvironment) ?*Clip;
extern fn avs_release_clip(clip: ?*Clip) void;
extern fn avs_get_video_info(clip: ?*Clip) ?*const VideoInfo;
extern fn avs_clip_get_error(clip: ?*Clip) ?[*:0]const u8;

// AVS_Value type testers (inline in C header, reimplemented here).
// Type codes: 'c'=clip, 'e'=error, 'v'=void, 's'=string, etc.
fn avsIsClip(v: AVS_Value) bool { return v.type == 'c'; }
fn avsIsError(v: AVS_Value) bool { return v.type == 'e'; }
fn avsAsString(v: AVS_Value) ?[*:0]const u8 {
    if (v.type != 's' and v.type != 'e') return null;
    return @ptrCast(v.d.string);
}

extern fn avs_get_frame(clip: ?*Clip, n: c_int) ?*VideoFrame;
extern fn avs_release_video_frame(frame: ?*VideoFrame) void;
extern fn avs_get_read_ptr_p(frame: ?*const VideoFrame, plane: c_int) ?[*]const u8;
extern fn avs_get_pitch_p(frame: ?*const VideoFrame, plane: c_int) c_int;
extern fn avs_get_row_size_p(frame: ?*const VideoFrame, plane: c_int) c_int;
extern fn avs_get_height_p(frame: ?*const VideoFrame, plane: c_int) c_int;

// AVS+ format query exports — these decode pixel_type structurally so every
// current and future format maps without a lookup table.
extern fn avs_bits_per_component(vi: ?*const VideoInfo) c_int;
extern fn avs_component_size(vi: ?*const VideoInfo) c_int;
extern fn avs_is_y(vi: ?*const VideoInfo) c_int;
extern fn avs_is_yuva(vi: ?*const VideoInfo) c_int;
extern fn avs_is_planar_rgb(vi: ?*const VideoInfo) c_int;
extern fn avs_is_planar_rgba(vi: ?*const VideoInfo) c_int;
extern fn avs_get_plane_width_subsampling(vi: ?*const VideoInfo, plane: c_int) c_int;
extern fn avs_get_plane_height_subsampling(vi: ?*const VideoInfo, plane: c_int) c_int;

// avs_new_value_string is inline in the header: sets type='s', d.string=s.
// avs_set_to_string is the exported equivalent.
fn avsNewValueString(s: [*c]const u8) AVS_Value {
    var val: AVS_Value = undefined;
    avs_set_to_string(&val, s);
    return val;
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
    raw: *ScriptEnvironment,
    clip: *Clip,
    vi: VideoInfo,

    /// `mode` is "Import" or "Eval"; `input` a file path or script body.
    /// After evaluation, packed formats are normalized to planar inside the
    /// AVS domain (YUY2 → YV16, interleaved RGB → planar RGB/RGBA) so the
    /// frame path is a single planar blit.
    pub fn init(mode: [:0]const u8, input: []const u8) !Env {
        const env = avs_create_script_environment(8) orelse return error.CreateFailed;
        errdefer avs_delete_script_environment(env);

        const args = avsNewValueString(input.ptr);
        defer avs_release_value(args);
        const result = avs_invoke(env, mode.ptr, args, null);
        defer avs_release_value(result);

        // avs_take_clip on a non-clip value (error/void) crashes; check first.
        if (avsIsError(result)) {
            captureError(avsAsString(result));
            return error.EvalError;
        }
        if (!avsIsClip(result)) return error.NotAClip;

        const clip = avs_take_clip(result, env) orelse return error.NotAClip;
        errdefer avs_release_clip(clip);
        const vi_ptr = avs_get_video_info(clip) orelse return error.NoVideo;
        if (vi_ptr.width == 0) return error.NoVideo;

        var self = Env{ .raw = env, .clip = clip, .vi = vi_ptr.* };

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
        var cval: AVS_Value = undefined;
        avs_set_to_clip(&cval, self.clip);
        defer avs_release_value(cval);

        const result = avs_invoke(self.raw, name.ptr, cval, null);
        defer avs_release_value(result);

        if (avsIsError(result)) {
            captureError(avsAsString(result));
            return error.EvalError;
        }
        if (!avsIsClip(result)) return error.NotAClip;

        const new_clip = avs_take_clip(result, self.raw) orelse return error.NotAClip;
        const vi_ptr = avs_get_video_info(new_clip) orelse {
            avs_release_clip(new_clip);
            return error.NoVideo;
        };
        avs_release_clip(self.clip);
        self.clip = new_clip;
        self.vi = vi_ptr.*;
    }

    pub fn deinit(self: *Env) void {
        avs_release_clip(self.clip);
        avs_delete_script_environment(self.raw);
    }

    pub fn getFrame(self: *const Env, n: c_int) ?*VideoFrame {
        return avs_get_frame(self.clip, n);
    }

    /// Returns the pending error on the clip, if any. Must be checked after
    /// getFrame: AviSynth reports frame errors here, not by returning null.
    pub fn getClipError(self: *const Env) ?[*:0]const u8 {
        return avs_clip_get_error(self.clip);
    }

    pub fn releaseFrame(self: *const Env, frame: ?*VideoFrame) void {
        _ = self;
        avs_release_video_frame(frame);
    }

    pub fn getReadPtr(self: *const Env, frame: *const VideoFrame, plane: c_int) ?[*]const u8 {
        _ = self;
        return avs_get_read_ptr_p(frame, plane);
    }

    pub fn getPitch(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        _ = self;
        return avs_get_pitch_p(frame, plane);
    }

    pub fn getRowSize(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        _ = self;
        return avs_get_row_size_p(frame, plane);
    }

    pub fn getHeight(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        _ = self;
        return avs_get_height_p(frame, plane);
    }

    /// Maps the (post-normalization, therefore planar) clip format to
    /// VapourSynth terms using the AVS+ structural query exports.
    pub fn mapFormat(self: *const Env) error{Unsupported}!MappedFormat {
        const vi = &self.vi;
        const pt: u32 = @bitCast(vi.pixel_type);
        const bits = avs_bits_per_component(vi);
        const is_float = avs_component_size(vi) == 4;

        if (avs_is_planar_rgb(vi) != 0 or avs_is_planar_rgba(vi) != 0) return .{
            .family = .RGB,
            .is_float = is_float,
            .bits = bits,
            .sub_w = 0,
            .sub_h = 0,
            .num_planes = 3, // alpha plane of RGBAP is dropped (not yet implemented)
            .planes = .{ Plane.R, Plane.G, Plane.B },
        };
        if (avs_is_y(vi) != 0) return .{
            .family = .Gray,
            .is_float = is_float,
            .bits = bits,
            .sub_w = 0,
            .sub_h = 0,
            .num_planes = 1,
            .planes = .{ Plane.Y, 0, 0 },
        };
        if ((pt & CS_PLANAR) != 0 and ((pt & CS_YUV) != 0 or avs_is_yuva(vi) != 0)) return .{
            .family = .YUV,
            .is_float = is_float,
            .bits = bits,
            .sub_w = avs_get_plane_width_subsampling(vi, Plane.U),
            .sub_h = avs_get_plane_height_subsampling(vi, Plane.U),
            .num_planes = 3, // alpha plane of YUVA is dropped (not yet implemented)
            .planes = .{ Plane.Y, Plane.U, Plane.V },
        };
        // Packed formats must have been normalized in init; anything left is
        // genuinely unknown.
        return error.Unsupported;
    }
};
