// avs_capi.zig — Pure Zig FFI for AviSynth+ C API
// Every CPU cycle matters. Memory is a resource.
const std = @import("std");

// ---------------------------------------------------------------------------
// Opaque handles
// ---------------------------------------------------------------------------
pub const ScriptEnvironment = opaque {};
pub const Clip = opaque {};
pub const VideoFrame = opaque {};

// ---------------------------------------------------------------------------
// AVS_VideoInfo — mirrors C struct, layout-identical to VideoInfo
// ---------------------------------------------------------------------------
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
    // image_type, reserved padding follows — we only need the fields above
};

// ---------------------------------------------------------------------------
// Pixel type constants (from avisynth_c.h)
// ---------------------------------------------------------------------------
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
    YV12  = CS_Generic_YUV420 | 0, // CS_Sample_Bits_8 = 0
    YV16  = CS_Generic_YUV422 | 0,
    YV24  = CS_Generic_YUV444 | 0,
    YV411 = CS_PLANAR | CS_YUV | CS_VPlaneFirst | CS_Sub_Width_4 | CS_Sub_Height_1 | 0,
    I420  = CS_PLANAR | CS_YUV | CS_UPlaneFirst | CS_Sub_Width_2 | CS_Sub_Height_2 | 0,
    Y8    = CS_PLANAR | CS_INTERLEAVED | CS_YUV | 0,
    RGB24 = CS_RGB_Type | CS_BGR | CS_INTERLEAVED,
    RGB32 = CS_RGBA_Type | CS_BGR | CS_INTERLEAVED,
    _,
};

// ---------------------------------------------------------------------------
// C API function declarations (imported from libavisynth)
// ---------------------------------------------------------------------------
extern fn avs_create_script_environment(version: c_int) ?*ScriptEnvironment;
extern fn avs_delete_script_environment(env: ?*ScriptEnvironment) void;

// Argument building
extern fn avs_set_to_string(val: *AVS_Value, s: [*c]const u8) void;
extern fn avs_release_value(v: AVS_Value) void;

// Invoke: call an AviSynth function by name
extern fn avs_invoke(env: ?*ScriptEnvironment, name: [*c]const u8, args: AVS_Value, arg_names: [*c]const [*c]const u8) AVS_Value;

// Clip extraction + info
extern fn avs_take_clip(v: AVS_Value, env: ?*ScriptEnvironment) ?*Clip;
extern fn avs_get_video_info(clip: ?*Clip) ?*const VideoInfo;

// Frame access (_p = API entry point, not inline)
extern fn avs_get_frame(clip: ?*Clip, n: c_int) ?*VideoFrame;
extern fn avs_get_read_ptr_p(env: ?*ScriptEnvironment, frame: ?*const VideoFrame, plane: c_int) ?[*]const u8;
extern fn avs_get_pitch_p(env: ?*ScriptEnvironment, frame: ?*const VideoFrame, plane: c_int) c_int;
extern fn avs_get_row_size_p(env: ?*ScriptEnvironment, frame: ?*const VideoFrame, plane: c_int) c_int;
extern fn avs_get_height_p(env: ?*ScriptEnvironment, frame: ?*const VideoFrame, plane: c_int) c_int;

// Format queries (exported)
extern fn avs_bits_per_component(vi: ?*const VideoInfo) c_int;
extern fn avs_is_planar_rgb(vi: ?*const VideoInfo) c_int;
extern fn avs_is_planar_rgba(vi: ?*const VideoInfo) c_int;

// Inline-equivalent helpers
fn avsNewValueString(s: [*c]const u8) AVS_Value {
    // avs_new_value_string is implemented as inline in avisynth_c.h.
    // We replicate it using the exported functions.
    // The pattern: avs NewValue array, then set array element to string.
    // For simplicity, we'll build a 1-element string array.
    var val: AVS_Value = undefined;
    avs_set_to_string(&val, s);
    return val;
}

// ---------------------------------------------------------------------------
// AVS_Value — opaque value type passed to/from AviSynth
// ---------------------------------------------------------------------------
pub const AVS_Value = extern struct {
    type: u8,
    array_size: i16,
    d: extern union {
        clip: ?*Clip,
        string: [*c]const u8,
        int_num: c_int,
        float_num: f32,
        _pad: [16]u8 align(8),
    },
};

// ---------------------------------------------------------------------------
// Zig-friendly wrapper
// ---------------------------------------------------------------------------
pub const Env = struct {
    raw: *ScriptEnvironment,
    clip: *Clip,
    vi: VideoInfo,

    pub fn init(script: []const u8) !Env {
        const env = avs_create_script_environment(8) orelse return error.CreateFailed;
        errdefer avs_delete_script_environment(env);

        const args = avsNewValueString(script.ptr);
        defer avs_release_value(args);
        const result = avs_invoke(env, "Eval", args, @ptrFromInt(0));
        defer avs_release_value(result);

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

    pub fn getReadPtr(self: *const Env, frame: *const VideoFrame, plane: c_int) ?[*]const u8 {
        return avs_get_read_ptr_p(self.raw, frame, plane);
    }

    pub fn getPitch(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        return avs_get_pitch_p(self.raw, frame, plane);
    }

    pub fn getRowSize(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        return avs_get_row_size_p(self.raw, frame, plane);
    }

    pub fn getHeight(self: *const Env, frame: *const VideoFrame, plane: c_int) c_int {
        return avs_get_height_p(self.raw, frame, plane);
    }

    pub fn colorFamily(self: *const Env) enum { Gray, RGB, YUV } {
        const pt: u32 = @bitCast(self.vi.pixel_type);
        // Check CS_PLANAR bit (1<<31)
        if ((pt & CS_PLANAR) != 0) {
            if (pt == @intFromEnum(PixelType.Y8)) return .Gray;
            if ((pt & CS_YUV) != 0) return .YUV;
        }
        if ((pt & CS_BGR) != 0) return .RGB;
        return .YUV;
    }

    pub fn subSampling(self: *const Env) struct { w: i32, h: i32 } {
        const pt: u32 = @bitCast(self.vi.pixel_type);
        const sw = (pt >> 0) & 7;
        const sh = (pt >> 8) & 7;
        return .{
            .w = switch (sw) {
                0 => 1, // Sub_Width_2 (YV12/I420/YV16)
                1 => 2, // Sub_Width_4 (YV411)
                3 => 0, // Sub_Width_1 (YV24)
                else => 0,
            },
            .h = switch (sh) {
                0 => 1, // Sub_Height_2 (YV12/I420)
                1 => 2, // Sub_Height_4
                3 => 0, // Sub_Height_1 (YV24/YV16/YV411)
                else => 0,
            },
        };
    }
};
