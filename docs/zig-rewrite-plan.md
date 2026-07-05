# VS_AvsReader Zig Rewrite — Implementation Plan

Audience: implementation agents. Each phase is self-contained, has a definition of
done, and should land as one commit (or a small series). Read this whole document
before starting any phase.

## Goal

Replace the C++ plugin (`src/*.cpp`, built by CMake) with a Zig implementation that
provides a *complete* AviSynth+ environment inside VapourSynth:

- All modern AVS+ pixel formats mapped natively (8–16 bit, 32-bit float, planar
  RGB(A), YUVA) — no more Dither-style MSB/LSB width-halving hack.
- Frame property bridging (AVS V8+ props → VS frame props).
- Alpha as a proper second output node.
- Audio via VapourSynth audio nodes (new capability).
- AVS+ plugin loading works (script `LoadPlugin()` / autoload).
- macOS + Linux first; Windows is a later, optional phase.

## Non-goals

- 32-bit targets. `AVS_Value` uses the 64-bit union layout unconditionally.
- The legacy `bitdepth` parameter (MSB/LSB interleave). AVS+ has native high bit
  depth; the parameter is dropped. Document this in README as a breaking change.
- Supporting classic AviSynth 2.6. Require interface V8+ at runtime (AVS+ 3.6+),
  use V10/V11 features conditionally.

## Architecture decision (do not relitigate)

Use the **AviSynth+ C ABI** (`vendor/avisynth/avisynth_c.h`, interface V12), not the
C++ `IScriptEnvironment` interface. The C API covers everything a host needs; the
`AVS_Linkage` machinery is a C++-plugin artifact and disappears entirely. FFmpeg's
AviSynth demuxer is the reference proof that a full host works on this API.

Load `libavisynth` at runtime with `dlopen`/`dlsym` (via `std.DynLib`), never link
it. The plugin must load into VapourSynth even when AviSynth+ is absent and produce
a clean error only when `avsr.*` is actually invoked.

**Normalize formats inside the AVS domain before frames cross the boundary.** At
clip-creation time, `avs_invoke` conversion filters so that every clip handed to
the frame path is planar:

| AVS source format | Normalization |
|---|---|
| YUY2 | `ConvertToYV16` |
| RGB24/RGB48 (interleaved) | `ConvertToPlanarRGB` |
| RGB32/RGB64 (interleaved) | `ConvertToPlanarRGBA` |
| everything else (already planar) | none |

This deletes the bottom-up BGR flip code and the per-format write functions: the
frame path is a single planar blit loop for every format. Alpha (from RGBA/YUVA)
is just plane index 3.

## Toolchain and dependencies

- Zig **0.16.0** (`zig version` confirms). Follow the 0.16 idioms listed under
  *Style guidelines* below — several 0.15 APIs are gone.
- VapourSynth binding: `dnjulek/vapoursynth-zig`, already fetched at
  `zig-pkg/vapoursynth-4.0.0-…`. Depend on it in `build.zig.zon`:

  ```zig
  .vapoursynth = .{
      .url = "git+https://github.com/dnjulek/vapoursynth-zig.git#deb29092bab5a9ef4ea736533a9fef8c7ab85228",
      .hash = "vapoursynth-4.0.0-jLYMQ7GXAgDVp4MV4ruLzaL_cV-5d_OqTcbOSId5uPB8",
  },
  ```

- AviSynth+ headers: `vendor/avisynth/avisynth_c.h` is the **source of truth** for
  every extern signature and constant. Before writing or reviewing a binding, grep
  the header (`grep -n "avs_take_clip" vendor/avisynth/avisynth_c.h`) and match it
  exactly. Do not trust memory or this document over the header.
- Integration tests: `tests/` (pytest, uv-managed VapourSynth). Run with
  `cd tests && uv run pytest`.
- AviSynth+ runtime for tests: `libavisynth.dylib` must be installed (brew or
  manual). Tests that need it must skip cleanly with a clear message when missing.

## Target layout

```
build.zig
build.zig.zon
src/
  main.zig            — plugin entry: VapourSynthPluginInit2, function registration
  filter.zig          — VS filter callbacks (video, alpha, audio), Reader lifetime
  reader.zig          — Reader: owns Env + Clip, normalization, VS VideoInfo/AudioInfo
  format.zig          — AVS VideoInfo → VS format mapping
  props.zig           — AVS frame-prop map → VS map bridging
  avs/
    c.zig             — ABI types + constants (AVS_Value, AVS_VideoInfo, CS_*, planes)
    lib.zig           — dlopen loader: struct of avs_* function pointers
    env.zig           — Env wrapper: create/destroy, invoke, eval, error capture
    clip.zig          — Clip wrapper: video info, getFrame, getAudio, release
src/AvsReader.cpp …   — C++ original stays until Phase 8 removes it
```

## Style guidelines

**Zig 0.16 specifics**
- No `@cImport` and no `translate-c`: bindings are hand-written `extern`-layout
  types plus `dlsym`-loaded function pointers. This is deliberate — the header's
  `AVSC_API` macro expands to typedef'd pointers for dynamic loading anyway, and
  hand-writing keeps only the ~45 functions we use.
- `std.DynLib` is POSIX-only in 0.16 (Windows support was removed). The Windows
  phase adds a small `LoadLibraryExW`/`GetProcAddress` shim behind the same
  interface; do not abstract for it before then.
- Containers: unmanaged style, allocator passed per call
  (`std.ArrayList(T).initCapacity(gpa, n)`, `list.append(gpa, x)`).
- `build.zig.zon` needs `.name = .vsavsreader` (enum literal) and a `.fingerprint`
  — run `zig build` once and copy the fingerprint from the error message.

**ABI rules**
- Every type crossing the C boundary is `extern struct` / `extern union` with a
  comptime size assertion:

  ```zig
  comptime {
      std.debug.assert(@sizeOf(Value) == 16); // matches C AVS_Value on 64-bit
  }
  ```
- All callbacks and loaded function pointers use `callconv(.c)`. Correct on every
  supported platform (the header's `AVSC_CC` is empty/cdecl on POSIX and Win64).
- Strings crossing the boundary are `[*:0]const u8` / `[:0]const u8`. Internal
  code uses slices.
- `AVS_Value` is returned **by value** from `avs_invoke` — declare the pointer
  type accordingly; extern-struct-by-value is fine on x86_64 and aarch64.

**Naming**
- Files: `snake_case.zig`. Types: `PascalCase`. Functions/fields: `camelCase`
  (match the ZAPI wrapper's style). Locals: `snake_case` per zig fmt culture.
- C constants keep their header spelling minus the `AVS_` prefix, grouped in
  namespace structs inside `avs/c.zig` (e.g. `c.cs.YV12`, `c.plane.Y`), so they
  stay greppable against the header.
- Loaded function pointer fields keep the full exported symbol name
  (`avs_create_script_environment`) so the loader can look them up by field name.

**Errors and memory**
- Zig error sets everywhere internally. Convert to VapourSynth errors only at the
  filter boundary: `map_out.setError("Import: <message>")` — keep the
  `"Import: "`/`"Eval: "` prefix, the pytest suite matches on it.
- When an AVS call fails, fetch the real message via `avs_get_error(env)` (returns
  null if none) or `avs_as_error` on an error `AVS_Value`, and carry it in the
  Reader so the boundary can report it. Never report a bare "failed".
- Allocator: `std.heap.c_allocator` for anything owned by filter instances (its
  lifetime crosses the C boundary). No global mutable state — the C++ version's
  global `g_readerRefCount` is a bug (two concurrent `Import` calls race); replace
  it with a per-Reader atomic refcount (see Phase 6).
- Every resource has a single owner with `deinit`; `errdefer` on every acquisition
  in create paths. AVS objects to release: `avs_release_value` for invoke results,
  `avs_release_clip`, `avs_release_video_frame`, `avs_delete_script_environment`
  last.

**Comments** — this repo uses a concise comment style (see recent commits): only
state constraints the code can't (`// env is not thread-safe; serialize GetFrame`),
never narrate what the next line does.

**Formatting** — `zig fmt` clean, no exceptions. Run `zig build` and the pytest
suite before declaring any phase done.

---

## Phase 0 — Build scaffolding

Create `build.zig` + `build.zig.zon` producing a dynamic library, alongside the
existing CMake build (do not touch CMake yet).

```zig
// build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vs_dep = b.dependency("vapoursynth", .{});

    const lib = b.addLibrary(.{
        .name = "vsavsreader",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vapoursynth", .module = vs_dep.module("vapoursynth") },
            },
        }),
    });
    lib.linkLibC();
    b.installArtifact(lib);

    const tests = b.addTest(.{ .root_module = lib.root_module });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
```

`src/main.zig` starts as a walking skeleton: register `Import`/`Eval` with the
same signatures as the C++ plugin minus `bitdepth`, both returning a map error
"not implemented yet".

```zig
export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vspapi: *const vs.PLUGINAPI) void {
    ZAPI.Plugin.config(
        "com.planesight.avsr", "avsr",
        "AviSynth Script Reader for VapourSynth v3.0.0",
        ZAPI.Plugin.makeVersion(3, 0), plugin, vspapi);
    ZAPI.Plugin.function("Import", "script:data;alpha:int:opt;", "clip:vnode;", createImport, plugin, vspapi);
    ZAPI.Plugin.function("Eval", "lines:data;alpha:int:opt;", "clip:vnode;", createEval, plugin, vspapi);
}
```

(Check the exact `ZAPI.Plugin.config`/`function` signatures in
`zig-pkg/…/src/zigapi/ZAPI.zig` and the invert example; adjust to what exists.
Keep the plugin namespace `avsr`. The identifier changes to `com.planesight.avsr`
— note it in README.)

**Done when:** `zig build` produces `zig-out/lib/libvsavsreader.dylib`;
`core.std.LoadPlugin(...)` in a `uv run python` one-liner shows the `avsr`
namespace; `zig build test` passes (empty).

## Phase 1 — ABI types and constants (`src/avs/c.zig`)

Hand-port from `vendor/avisynth/avisynth_c.h`. Everything verified against the
header, not the research doc.

```zig
const std = @import("std");

pub const ScriptEnvironment = opaque {};
pub const Clip = opaque {};
pub const VideoFrame = opaque {};

pub const Map = extern struct { data: ?*anyopaque };

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

/// 64-bit layout only; 32-bit targets are unsupported (see plan non-goals).
pub const Value = extern struct {
    type: i16, // 'c','i','l','f','d','s','b','v','a','n','e'
    array_size: i16,
    d: extern union {
        clip: ?*anyopaque,
        boolean: u8,
        integer: c_int,
        longlong: i64,
        floating_pt: f32,
        double_pt: f64,
        string: ?[*:0]const u8,
        array: ?[*]const Value,
        function: ?*anyopaque,
    },

    pub const void_value: Value = .{ .type = 'v', .array_size = 0, .d = .{ .integer = 0 } };

    // The avs_new_value_* / avs_is_* helpers are AVSC_INLINE in the header
    // (not exported symbols) — reimplement them here.
    pub fn fromString(s: [*:0]const u8) Value {
        return .{ .type = 's', .array_size = 0, .d = .{ .string = s } };
    }
    pub fn isClip(v: Value) bool { return v.type == 'c'; }
    pub fn isError(v: Value) bool { return v.type == 'e'; }
    pub fn asError(v: Value) ?[*:0]const u8 { return if (v.isError()) v.d.string else null; }
};

comptime {
    std.debug.assert(@sizeOf(Value) == 16);
    std.debug.assert(@sizeOf(VideoInfo) == 40);
}
```

Also port, as namespaced constants verified line-by-line against the header:
- `cs` — the `AVS_CS_*` bit constants and the generic/family masks (§4 of
  `docs/avisynth-c-api-research.md` is a good index into the header).
- `plane` — `AVS_PLANAR_Y/U/V/A/R/G/B` (bitmask values, not indices; `Y=1`).
- `sample` — `AVS_SAMPLE_INT8/16/24/32/FLOAT`.
- `it` — `AVS_IT_BFF/TFF/FIELDBASED` (image_type bits).
- `AVS_INTERFACE_VERSION = 12`, prop-type chars (`'u','i','f','s','c','v'` — check
  `AVS_PROPTYPE_*` in the header), and `AVS_GETFRAME_*` cache constants if needed.

**Done when:** `zig build test` passes with comptime size asserts plus unit tests
for a few constants against literal values from the header (e.g. `cs.YV12`,
`plane.U == 2`).

## Phase 2 — Dynamic loader (`src/avs/lib.zig`)

A struct-of-function-pointers loaded via `std.DynLib`, iterated at comptime so
adding a function is a one-line change:

```zig
const std = @import("std");
const c = @import("c.zig");

pub const Fns = struct {
    avs_create_script_environment: *const fn (c_int) callconv(.c) ?*c.ScriptEnvironment,
    avs_delete_script_environment: *const fn (?*c.ScriptEnvironment) callconv(.c) void,
    avs_check_version: *const fn (?*c.ScriptEnvironment, c_int) callconv(.c) c_int,
    avs_get_error: *const fn (?*c.ScriptEnvironment) callconv(.c) ?[*:0]const u8,
    avs_invoke: *const fn (?*c.ScriptEnvironment, [*:0]const u8, c.Value, ?[*]const ?[*:0]const u8) callconv(.c) c.Value,
    avs_release_value: *const fn (c.Value) callconv(.c) void,
    avs_take_clip: *const fn (c.Value, ?*c.ScriptEnvironment) callconv(.c) ?*c.Clip,
    avs_release_clip: *const fn (?*c.Clip) callconv(.c) void,
    avs_get_video_info: *const fn (?*c.Clip) callconv(.c) *const c.VideoInfo,
    avs_get_frame: *const fn (?*c.Clip, c_int) callconv(.c) ?*c.VideoFrame,
    avs_release_video_frame: *const fn (?*c.VideoFrame) callconv(.c) void,
    avs_clip_get_error: *const fn (?*c.Clip) callconv(.c) ?[*:0]const u8,
    avs_get_pitch_p: *const fn (?*const c.VideoFrame, c_int) callconv(.c) c_int,
    avs_get_row_size_p: *const fn (?*const c.VideoFrame, c_int) callconv(.c) c_int,
    avs_get_height_p: *const fn (?*const c.VideoFrame, c_int) callconv(.c) c_int,
    avs_get_read_ptr_p: *const fn (?*const c.VideoFrame, c_int) callconv(.c) ?[*]const u8,
    // …format queries, frame props, audio: added per phase as needed.
};

pub const Lib = struct {
    dylib: std.DynLib,
    fns: Fns,

    pub fn load() !Lib {
        const names = switch (@import("builtin").os.tag) {
            .macos => [_][]const u8{ "libavisynth.dylib", "/usr/local/lib/libavisynth.dylib", "/opt/homebrew/lib/libavisynth.dylib" },
            else => [_][]const u8{"libavisynth.so"},
        };
        var dylib = for (names) |n| {
            break std.DynLib.open(n) catch continue;
        } else return error.AvisynthNotFound;
        errdefer dylib.close();

        var fns: Fns = undefined;
        inline for (@typeInfo(Fns).@"struct".fields) |f| {
            @field(fns, f.name) = dylib.lookup(f.type, f.name ++ "\x00") orelse
                return error.MissingSymbol;
        }
        return .{ .dylib = dylib, .fns = fns };
    }
};
```

Check `std.DynLib.lookup`'s exact signature in the 0.16 std source
(`zig env` → `.std_dir`, then `dynamic_library.zig`) — it may want a
comptime-known sentinel string; adjust.

Every signature must be transcribed from the header's `AVSC_API(ret, name)(args)`
lines. Note `avs_get_pitch_p` returns `int` (not pointer-sized) — pitch fits.

**Done when:** a unit test (`zig build test`) that, when `libavisynth` is
installed, loads the lib, creates and destroys a script environment, and asserts
`avs_check_version(env, 8) == 0`; test skips (`error.SkipZigTest`) when
`Lib.load()` fails with `AvisynthNotFound`.

## Phase 3 — Env + Clip wrappers (`src/avs/env.zig`, `src/avs/clip.zig`)

`Env` owns the environment; `Clip` owns an `AVS_Clip*`. Both are thin.

```zig
pub const Env = struct {
    lib: *const Lib,
    env: *c.ScriptEnvironment,
    err_buf: [1024]u8, // last error message, copied out of AVS-owned memory

    pub const Error = error{ CreateFailed, TooOld, InvokeFailed, NotAClip };

    pub fn init(lib: *const Lib) Error!Env { ... } // create + check_version(8)
    pub fn deinit(self: *Env) void { ... }         // delete_script_environment

    /// `mode` is "Import" or "Eval"; `input` a path or script body.
    /// On error, message is captured into err_buf before the value is released.
    pub fn evalToClip(self: *Env, mode: [:0]const u8, input: [:0]const u8) Error!*c.Clip {
        const res = self.lib.fns.avs_invoke(self.env, mode, c.Value.fromString(input), null);
        defer self.lib.fns.avs_release_value(res);
        if (res.asError()) |msg| { self.setError(msg); return error.InvokeFailed; }
        if (!res.isClip()) return error.NotAClip;
        return self.lib.fns.avs_take_clip(res, self.env) orelse error.NotAClip;
    }

    /// Invoke a conversion filter on a clip, e.g. "ConvertToPlanarRGBA".
    /// Wraps clip in a Value ('c'), invokes, takes the new clip, releases the old.
    pub fn convert(self: *Env, name: [:0]const u8, clip: *c.Clip) Error!*c.Clip { ... }
};
```

For `convert`: building a clip `Value` requires `avs_set_to_clip` (exported,
V11) or the inline pattern — check the header for how a clip Value is
constructed in C (`avs_new_value_clip` is inline and calls the exported
`avs_set_to_clip`). Add `avs_set_to_clip` / `avs_copy_value` to `Fns`.

Ordering constraint to encode in `deinit`: release frames → release clip →
delete environment → `dylib.close()`. The Reader (Phase 5) enforces this.

**Done when:** unit test evaluates `BlankClip(width=640, height=480, pixel_type="YV12")`
via `Eval` mode, asserts VideoInfo fields, releases everything; a second test
asserts a bad script produces `error.InvokeFailed` with a non-empty captured
message. Both skip without libavisynth.

## Phase 4 — Format mapping (`src/format.zig`)

No lookup table. Use the AVS+ query exports so every current and future format
maps structurally (add `avs_is_y`, `avs_is_yuva`, `avs_is_planar_rgb`,
`avs_is_planar_rgba`, `avs_bits_per_component`, `avs_component_size`,
`avs_num_components`, `avs_get_plane_width_subsampling`,
`avs_get_plane_height_subsampling`, `avs_is_color_space` to `Fns`):

```zig
pub const MappedFormat = struct {
    color_family: vs.ColorFamily,
    sample_type: vs.SampleType,
    bits: i32,
    sub_w: i32,
    sub_h: i32,
    has_alpha: bool,
};

pub fn map(fns: *const Fns, vi: *const c.VideoInfo) error{Unsupported}!MappedFormat {
    const bits = fns.avs_bits_per_component(vi);
    const st: vs.SampleType = if (fns.avs_component_size(vi) == 4) .Float else .Integer;

    if (fns.avs_is_planar_rgb(vi) != 0 or fns.avs_is_planar_rgba(vi) != 0) return .{
        .color_family = .RGB, .sample_type = st, .bits = bits, .sub_w = 0, .sub_h = 0,
        .has_alpha = fns.avs_is_planar_rgba(vi) != 0,
    };
    if (fns.avs_is_y(vi) != 0) return .{ .color_family = .Gray, ... };
    if (fns.avs_is_yuv(vi) != 0 or fns.avs_is_yuva(vi) != 0) return .{
        .color_family = .YUV, .sample_type = st, .bits = bits,
        .sub_w = fns.avs_get_plane_width_subsampling(vi, c.plane.U),
        .sub_h = fns.avs_get_plane_height_subsampling(vi, c.plane.U),
        .has_alpha = fns.avs_is_yuva(vi) != 0,
    };
    return error.Unsupported; // packed formats must be normalized before this point
}
```

(`avs_is_yuv` — verify the exact export name in the header; classic name may be
`avs_is_yuv` as an inline over `avs_is_color_space`. Use whatever the header
actually exports; inline helpers get reimplemented in `c.zig`.)

The plane order difference matters for the blit loop: VS plane index 0/1/2 maps
to AVS plane constants per family — YUV: `{plane.Y, plane.U, plane.V}`, RGB:
`{plane.R, plane.G, plane.B}` (AVS planar RGB is G,B,R in memory but the plane
constants abstract that), Gray: `{plane.Y}`. Alpha is `plane.A` for both.
Encode this as a function returning a fixed array.

**Done when:** unit tests cover the full matrix using `BlankClip(pixel_type=...)`
through the Phase 3 wrapper: YV12/YV16/YV24/YV411/Y8, YUV420P10/P16,
YUV444PS, Y16, RGBP8/RGBP16/RGBAP8, YUVA420P8 — each asserting the mapped
family/bits/subsampling and that `queryVideoFormat` accepts it. Skips without
libavisynth.

## Phase 5 — Reader and the video path (`src/reader.zig`, `src/filter.zig`, `src/main.zig`)

`Reader` is created once per `Import`/`Eval` call and shared by all output nodes:

```zig
pub const Reader = struct {
    gpa: std.mem.Allocator,
    lib: Lib,
    env: Env,
    clip: *c.Clip,
    avs_vi: c.VideoInfo,        // copied, post-normalization
    vs_vi: vs.VideoInfo,        // base video output
    alpha_vi: ?vs.VideoInfo,    // Gray, same depth, when clip has alpha and alpha=1
    planes: [3]c_int,           // AVS plane constants in VS plane order
    refs: std.atomic.Value(u32),
    mutex: std.Thread.Mutex,    // env/clip are not thread-safe
    err_msg: [1024]u8,
};
```

Creation flow (`Reader.create`):
1. `Lib.load()` → `Env.init` → `evalToClip(mode, input)`.
2. Normalize per the table in *Architecture decision* (`avs_is_yuy2` etc. → the
   `Env.convert` calls). Re-read VideoInfo after conversion.
3. `format.map` → `zapi.queryVideoFormat` → fill `vs_vi`
   (`fpsNum/fpsDen` from `fps_numerator/denominator` — reduce with
   `vsh.muldivRational` or `std.math.gcd`; `numFrames`; width/height verbatim).
4. If `has_alpha` and user passed `alpha=1` (default 1): fill `alpha_vi` as
   Gray with the same bits/sample type.

Frame path (`filter.zig`), one `getFrame` callback shared by base and alpha
outputs, distinguished by instance data:

```zig
const Output = struct { reader: *Reader, kind: enum { video, alpha } };

fn getFrame(n: c_int, reason: vs.ActivationReason, data: ?*anyopaque, ...) callconv(.c) ?*const vs.Frame {
    if (reason != .Initial) return null;
    const out: *Output = @ptrCast(@alignCast(data));
    const r = out.reader;
    const nc = std.math.clamp(n, 0, r.avs_vi.num_frames - 1);

    r.mutex.lock();
    defer r.mutex.unlock();
    const src = r.lib.fns.avs_get_frame(r.clip, nc) orelse { ...setFilterError...; return null; };
    defer r.lib.fns.avs_release_video_frame(src);
    if (r.lib.fns.avs_clip_get_error(r.clip)) |msg| { ...setFilterError(msg)...; return null; }

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const dst = zapi.newVideoFrame(&vi.format, vi.width, vi.height, null);

    // planar blit: rows are contiguous; AVS pitch and VS stride both in bytes
    for (0..num_planes) |p| {
        const avs_plane = if (out.kind == .alpha) c.plane.A else r.planes[p];
        const srcp = r.lib.fns.avs_get_read_ptr_p(src, avs_plane).?;
        const pitch: usize = @intCast(r.lib.fns.avs_get_pitch_p(src, avs_plane));
        const row_size: usize = @intCast(r.lib.fns.avs_get_row_size_p(src, avs_plane));
        const h: usize = @intCast(r.lib.fns.avs_get_height_p(src, avs_plane));
        var dstp = zapi.getWritePtr(dst, @intCast(p));
        const stride: usize = @intCast(zapi.getStride(dst, @intCast(p)));
        for (0..h) |y| {
            @memcpy(dstp[y * stride ..][0..row_size], srcp[y * pitch ..][0..row_size]);
        }
    }
    // props: Phase 6 fills this in; _DurationNum/Den from day one:
    //   num = fps_denominator, den = fps_numerator (yes, inverted — duration is 1/fps)
    return dst.?;
}
```

Use `.Unordered` filter mode. The mutex is still required: the base and alpha
nodes are *separate filters* and VapourSynth may run their getFrames
concurrently (the C++ original has this race — do not copy it).

`free_filter` decrements `reader.refs`; the thread that hits zero runs
`reader.deinit` (frames already released → `avs_release_clip` → `env.deinit()`
→ `lib.dylib.close()`) and destroys it. Register the alpha node as function
output key `"alpha"` — with VS4, return two keys from one function call
(`clip:vnode;alpha:vnode:opt;` return signature) rather than the old
Import/Import_Alpha two-filter registration; check how ZAPI's
`createVideoFilter2` returns a node so both can be set on the out map
(`mapConsumeNode`).

**Done when:** existing pytest suite passes against the Zig plugin (update
`PLUGIN` path in `tests/test_plugin.py` to `zig-out/lib/libvsavsreader.dylib`),
plus new tests: frame content checksum for a `ColorBars` script vs. known
values, 10-bit and float formats, RGB round-trip (`ConvertToPlanarRGB` output
equals VS `RGBP8` planes), alpha node presence and content for RGB32 input,
YUY2 input auto-converts to YUV422P8.

## Phase 6 — Frame property bridging (`src/props.zig`)

Add to `Fns`: `avs_get_frame_props_ro`, `avs_prop_num_keys`, `avs_prop_get_key`,
`avs_prop_get_type`, `avs_prop_num_elements`, `avs_prop_get_int`,
`avs_prop_get_float`, `avs_prop_get_data`, `avs_prop_get_data_size`,
`avs_prop_get_int_array`, `avs_prop_get_float_array` (all `(env, map, ...)` —
transcribe exact signatures from the header; most take `int* error` out-params).

Bridge in `getFrame`, inside the mutex, after blitting:

- Iterate keys on `avs_get_frame_props_ro(env, src)`; for each, switch on
  `avs_prop_get_type`: int(-array) → `mapSetInt(Array)`, float(-array) →
  `mapSetFloat(Array)`, data → `mapSetData` (use
  `avs_prop_get_data_type_hint` when interface ≥ V11 to preserve
  binary-vs-utf8). Skip clip/frame-typed props.
- AVS and VS share the reserved prop vocabulary (`_Matrix`, `_ColorRange`,
  `_SARNum`, …) so a straight copy is correct; write `_DurationNum/Den` *after*
  the copy so the clip's own values win only if absent — actually set them
  first and let copied props replace (`maReplace`).
- Derive `_FieldBased` from `image_type` bits (`IT_FIELDBASED` +
  `IT_BFF`/`IT_TFF` → 1/2, else 0) only when the AVS frame didn't carry one.

Gate the whole bridge on `avs_check_version(env, 8) == 0` (stored as a bool on
Reader at create time).

**Done when:** pytest: an AVS script using `propSet` (AVS+ `propSet(clip,
"my_prop", 42)`) surfaces `my_prop=42` on the VS frame; `_DurationNum/Den`
correct for a 24000/1001 clip; a V8-props-carrying source (ColorBars sets
`_ColorRange`) round-trips.

## Phase 7 — Audio (`src/reader.zig` + `src/filter.zig`)

Add to `Fns`: `avs_get_audio` (`(clip, void*, i64 start, i64 count)`),
plus the channel-mask exports (`avs_is_channel_mask_known`,
`avs_get_channel_mask`, V10).

- New registered function `ImportAudio(script:data;)` / `EvalAudio(lines:data;)`
  returning `clip:anode;` (keep it a separate function — a video `Import` of an
  audio-only script should keep erroring with "no video").
- Normalize sample type in the AVS domain: VS audio supports int16/int32/float32.
  Invoke `ConvertAudioTo16bit`/`ConvertAudioTo32bit`/`ConvertAudioToFloat` for
  8/24-bit sources (24-bit → 32-bit int).
- Fill `vs.AudioInfo`: `sampleRate = audio_samples_per_second`, `numSamples =
  num_audio_samples`, format via `queryAudioFormat(st, bps, channel_layout)`.
  Channel layout: AVS's channel mask (V10) and VS's `acFrontLeft…` layout are
  both WAVEFORMATEXTENSIBLE-style bitmasks — **verify bit-for-bit against
  `vsconstants.zig` and the AVS header before assuming identity**; fall back to
  a default mask from `nchannels` when `avs_is_channel_mask_known` is false.
- getFrame: VS audio frames are fixed `VS_AUDIO_FRAME_SAMPLES` (3072) samples;
  compute `start = n * 3072`, `count = min(3072, numSamples - start)`, call
  `avs_get_audio` into a scratch buffer under the Reader mutex, then deinterleave:
  AVS audio is interleaved, VS audio frames are planar per channel.

**Done when:** pytest: `Eval` of `Tone(length=1.0, frequency=440)` through
`EvalAudio` yields an audio node with the right sample rate/length, and
`get_frame(0)` samples match a locally computed sine (tolerance for int16).

## Phase 8 — Cleanup and parity switchover

- Delete `src/*.cpp`, `src/*.h`, `CMakeLists.txt`, and the `build/` output dir
  reference; `tests/test_plugin.py` PLUGIN path already moved in Phase 5.
- README rewrite: build instructions (`zig build -Doptimize=ReleaseFast`),
  breaking changes (bitdepth removed, alpha now an `alpha` output key,
  identifier change), new features (native HBD, props, audio), macOS/Linux
  install notes for libavisynth.
- Add `avsr.Version()` (no args, returns `version:data;`): invokes AVS
  `VersionString()` and returns it — cheap and makes "is my AVS+ found" 
  debuggable for users.
- Keep `docs/avisynth-c-api-research.md`; update its "Zig port" columns to
  reflect reality.

**Done when:** `zig build && cd tests && uv run pytest` green from a clean
checkout with only Zig + uv + AviSynth+ installed; `rg -i "cmake|\.cpp"` finds
nothing outside vendor/ and docs/.

## Phase 9 (optional, separate effort) — Windows

- Loader shim: `LoadLibraryExW("avisynth.dll")` + `GetProcAddress` behind the
  same `Lib.load()` interface (std.DynLib has no Windows support in 0.16).
- Paths: AviSynth expects ANSI on Windows; port the UTF-8→ACP conversion from
  the C++ original (`MultiByteToWideChar`/`WideCharToMultiByte` via
  `std.os.windows`), applied to the `script` path only (not `lines`).
- CI cross-compile check: `zig build -Dtarget=x86_64-windows-gnu` at minimum.

---

## Gotchas appendix (read before touching the boundary)

1. **`avs_invoke` arg-by-value**: `AVS_Value` crosses by value both ways. Never
   pass a pointer where the header says value.
2. **Release discipline**: every `avs_invoke` result needs `avs_release_value`
   even on success — `avs_take_clip` takes its own reference first.
3. **`arg_names`**: `avs_invoke`'s last param is `const char** arg_names`
   parallel to an array Value of args; for single-arg invokes pass `null`.
   Multi-arg invokes (e.g. `ConvertAudioTo16bit` variants with options) build an
   array Value: `type='a'`, `array_size=n`, `d.array` pointing at a stack array —
   the array memory only needs to outlive the call.
4. **Pitch vs row_size**: blit `row_size` bytes per row, advance by
   pitch/stride. Never `@memcpy` the whole plane in one call.
5. **AVS plane constants are bitmasks** (`Y=1,U=2,V=4,A=16,R=32,G=64,B=128`),
   not indices. `0` is `DEFAULT_PLANE` and only works for the first plane.
6. **Duration props are inverted fps**: `_DurationNum = fps_denominator`,
   `_DurationDen = fps_numerator`. Reduce the fraction.
7. **Interface gating**: store the highest verified interface at create time
   (`avs_check_version(env, v) == 0` means "at least v"); gate props (V8),
   channel mask (V10), data-type-hint (V11) on it.
8. **Error strings are AVS-owned**: copy into Reader-owned storage before
   releasing the value/environment that owns them.
9. **The env is single-threaded**: every `avs_*` call taking env or clip happens
   under the Reader mutex. `Lib.load`'s dlopen is also not reentrant-safe with
   AVS autoloading; keep creation single-threaded per Reader (VS guarantees the
   create callback itself is fine).
10. **Zig 0.16**: no `@cImport`; `std.DynLib` POSIX-only; `build.zig.zon` needs
    enum-literal name + fingerprint; unmanaged containers take the allocator per
    call. When in doubt read the local std source (`zig env` → `.std_dir`).
