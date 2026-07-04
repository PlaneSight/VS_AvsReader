// avs_capi.zig — Pure Zig FFI for AviSynth+ C API
const std = @import("std");

pub const ScriptEnvironment = opaque {};
pub const Clip = opaque {};
pub const VideoFrame = opaque {};

// AviSynth plane constants are bitmasks, not sequential indices.
// avisynth_c.h: AVS_DEFAULT_PLANE=0, AVS_PLANAR_Y=1, AVS_PLANAR_U=2, AVS_PLANAR_V=4
pub const Plane = struct {
    pub const Y: c_int = 0; // AVS_DEFAULT_PLANE
    pub const U: c_int = 2; // AVS_PLANAR_U (1 << 1)
    pub const V: c_int = 4; // AVS_PLANAR_V (1 << 2)
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
const CS_VPlaneFirst: u32 = 1 << 3;
const CS_UPlaneFirst: u32 = 1 << 4;
const CS_Sub_Width_1: u32 = 3 << 0;
const CS_Sub_Width_2: u32 = 0 << 0;
const CS_Sub_Width_4: u32 = 1 << 0;
const CS_Sub_Height_1: u32 = 3 << 8;
const CS_Sub_Height_2: u32 = 0 << 8;
const CS_Generic_YUV444: u32 = CS_PLANAR | CS_YUV | CS_VPlaneFirst | CS_Sub_Width_1 | CS_Sub_Height_1;
const CS_Generic_YUV422: u32 = CS_PLANAR | CS_YUV | CS_VPlaneFirst | CS_Sub_Width_2 | CS_Sub_Height_1;
const CS_Generic_YUV420: u32 = CS_PLANAR | CS_YUV | CS_VPlaneFirst | CS_Sub_Width_2 | CS_Sub_Height_2;
const CS_RGB_Type: u32 = 1 << 0;
const CS_RGBA_Type: u32 = 1 << 1;

pub const PixelType = enum(u32) {
    YV12 = CS_Generic_YUV420 | 0,
    YV16 = CS_Generic_YUV422 | 0,
    YV24 = CS_Generic_YUV444 | 0,
    YV411 = CS_PLANAR | CS_YUV | CS_VPlaneFirst | CS_Sub_Width_4 | CS_Sub_Height_1 | 0,
    I420 = CS_PLANAR | CS_YUV | CS_UPlaneFirst | CS_Sub_Width_2 | CS_Sub_Height_2 | 0,
    Y8 = CS_PLANAR | CS_INTERLEAVED | CS_YUV | 0,
    RGB24 = CS_RGB_Type | CS_BGR | CS_INTERLEAVED,
    RGB32 = CS_RGBA_Type | CS_BGR | CS_INTERLEAVED,
    _,
};

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
extern fn avs_release_value(v: AVS_Value) void;

extern fn avs_invoke(env: ?*ScriptEnvironment, name: [*c]const u8, args: AVS_Value, arg_names: [*c]const [*c]const u8) AVS_Value;

extern fn avs_take_clip(v: AVS_Value, env: ?*ScriptEnvironment) ?*Clip;
extern fn avs_get_video_info(clip: ?*Clip) ?*const VideoInfo;

// AVS_Value type testers (inline in C header, reimplemented here).
// Type codes: 'c'=clip, 'e'=error, 'v'=void, 's'=string, etc.
fn avsIsClip(v: AVS_Value) bool { return v.type == 'c'; }
fn avsIsError(v: AVS_Value) bool { return v.type == 'e'; }
fn avsAsString(v: AVS_Value) ?[*:0]const u8 {
    if (v.type != 's') return null;
    return @ptrCast(v.d.string);
}

extern fn avs_get_frame(clip: ?*Clip, n: c_int) ?*VideoFrame;
extern fn avs_release_video_frame(frame: ?*VideoFrame) void;
extern fn avs_get_read_ptr_p(frame: ?*const VideoFrame, plane: c_int) ?[*]const u8;
extern fn avs_get_pitch_p(frame: ?*const VideoFrame, plane: c_int) c_int;
extern fn avs_get_row_size_p(frame: ?*const VideoFrame, plane: c_int) c_int;
extern fn avs_get_height_p(frame: ?*const VideoFrame, plane: c_int) c_int;

extern fn avs_bits_per_component(vi: ?*const VideoInfo) c_int;
extern fn avs_is_planar_rgb(vi: ?*const VideoInfo) c_int;
extern fn avs_is_planar_rgba(vi: ?*const VideoInfo) c_int;

// avs_new_value_string is inline in the header: sets type='s', d.string=s.
// avs_set_to_string is the exported equivalent.
fn avsNewValueString(s: [*c]const u8) AVS_Value {
    var val: AVS_Value = undefined;
    avs_set_to_string(&val, s);
    return val;
}

pub const Env = struct {
    raw: *ScriptEnvironment,
    clip: *Clip,
    vi: VideoInfo,

    pub fn init(script: []const u8) !Env {
        const env = avs_create_script_environment(8) orelse return error.CreateFailed;
        errdefer avs_delete_script_environment(env);

        const args = avsNewValueString(script.ptr);
        defer avs_release_value(args);
        const result = avs_invoke(env, "Eval", args, null);
        defer avs_release_value(result);

        // avs_take_clip on a non-clip value (error/void) crashes; check first.
        if (avsIsError(result)) return error.EvalError;
        if (!avsIsClip(result)) return error.NotAClip;

        const clip = avs_take_clip(result, env) orelse return error.NotAClip;
        const vi_ptr = avs_get_video_info(clip) orelse return error.NoVideo;
        if (vi_ptr.width == 0) return error.NoVideo;

        return Env{ .raw = env, .clip = clip, .vi = vi_ptr.* };
    }

    pub fn deinit(self: *Env) void {
        avs_delete_script_environment(self.raw);
    }

    pub fn getFrame(self: *const Env, n: c_int) ?*VideoFrame {
        return avs_get_frame(self.clip, n);
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

    pub fn colorFamily(self: *const Env) enum { Gray, RGB, YUV } {
        const pt: u32 = @bitCast(self.vi.pixel_type);
        if ((pt & CS_PLANAR) != 0) {
            if (pt == @intFromEnum(PixelType.Y8)) return .Gray;
            if ((pt & CS_YUV) != 0) return .YUV;
        }
        if ((pt & CS_BGR) != 0) return .RGB;
        return .YUV;
    }

    // Decodes log2 sub-sampling factors from pixel_type flags.
    // Only meaningful for planar YUV; Gray and interleaved formats return 0,0.
    // Shifts: sub-width at bit 0, sub-height at bit 8 (avisynth_c.h).
    pub fn subSampling(self: *const Env) struct { w: i32, h: i32 } {
        const pt: u32 = @bitCast(self.vi.pixel_type);
        // Gray (Y8) and interleaved (RGB, YUY2) have no chroma subsampling
        if (pt == @intFromEnum(PixelType.Y8)) return .{ .w = 0, .h = 0 };
        if ((pt & CS_PLANAR) == 0) return .{ .w = 0, .h = 0 };
        const sw = pt & 7;
        const sh = (pt >> 8) & 7;
        return .{
            .w = switch (sw) {
                0 => 1, // Sub_Width_2: 4:2:0, 4:2:2
                1 => 2, // Sub_Width_4: 4:1:1
                3 => 0, // Sub_Width_1: 4:4:4
                else => 0,
            },
            .h = switch (sh) {
                0 => 1, // Sub_Height_2: 4:2:0
                1 => 2, // Sub_Height_4: 4:1:0
                3 => 0, // Sub_Height_1: 4:2:2, 4:4:4, 4:1:1
                else => 0,
            },
        };
    }
};
