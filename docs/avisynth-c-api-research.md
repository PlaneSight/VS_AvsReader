# AviSynth+ API Research

Headers: `vendor/avisynth/{avisynth.h, avs/{config,capi,types}.h}` (C++ plugin API).
C ABI (`avisynth_c.h`) from upstream: `avs_core/include/avisynth_c.h`.
Original C++ plugin: `chikuzen/VS_AvsReader` (AvsReader.{h,cpp}, plugin.cpp, myvshelper.h).

---

## 1. Calling convention

| Platform | AVSC_CC | Zig |
|---|---|---|
| POSIX (macOS, Linux) | empty (cdecl) | `callconv(.c)` |
| Win64 | one convention | `callconv(.c)` |
| Win32 | `__cdecl` (default) or `__stdcall` opt-in | `callconv(.c)` |

`callconv(.c)` is correct for all.

---

## 2. Core C types

### AVS_Value (layout identical to C++ AVSValue, 16B x64 / 12B x86)

```c
typedef struct AVS_Value {
    short type;     // 'c','i','l','f','d','s','b','v','a','n','e'
    short array_size;
    union {
        void *clip;        char boolean;    int integer;
        float floating_pt; const char *string;  const AVS_Value *array;
        void *function;
#if UINTPTR_MAX >= 0xffffffffffffffff
        int64_t longlong;  // 8B
        double double_pt;  // 8B
#else
        int64_t *longlong_ptr;   double *double_pt_ptr;
#endif
    } d;
} AVS_Value;
```

**⚠ Zig must handle the 32/64 union differently.** Current binding uses `extern union` unconditionally — wrong for 32-bit.

### AVS_VideoInfo (extern struct)

```c
typedef struct { int width, height; unsigned fps_numerator, fps_denominator;
    int num_frames, pixel_type, audio_samples_per_second, sample_type;
    int64_t num_audio_samples; int nchannels, image_type; } AVS_VideoInfo;
```

### AVS_VideoFrame — opaque, access via `avs_get_pitch_p / read_ptr_p / row_size_p / height_p`

### AVS_Map — frame property map: `{ void* data; }`

### AVS_ScriptEnvironment, AVS_Clip — opaque

---

## 3. C API function catalog (V6-V12, 75+ exports)

### Environment lifecycle
| Func | Sig | Since |
|---|---|---|
| `avs_create_script_environment` | `(int) -> AVS_ScriptEnvironment*` | V6 |
| `avs_delete_script_environment` | `(AVS_ScriptEnvironment*)` | V6 |
| `avs_check_version` | `(env, int) -> int` | V6 |

### Script execution
`avs_invoke(env, name, args, arg_names) -> AVS_Value` • `avs_function_exists` • `avs_get_var/set_var/set_global_var` • `avs_get_var_try` (V8) • typed var getters `bool/int/double/string/long` (V8)

### Clip ops
`avs_take_clip(AVS_Value, env) -> AVS_Clip*` • `release_clip` • `copy_clip` • `get_frame(clip, n)` • `get_video_info` • `get_version` • `get_parity` • `get_audio` • `set_cache_hints` • `clip_get_error`

### Frame access
`avs_get_read_ptr_p / get_write_ptr_p / get_pitch_p / get_row_size_p / get_height_p` — all take `(frame, plane)` • `is_writable` • `release_video_frame` • `copy_video_frame` • `video_frame_get_pixel_type/amend_pixel_type` (V10) • `is_property_writable/make_property_writable` (V9)

### VideoInfo queries
`avs_is_yv24/yv16/yv12/yv411/y8` • `get_plane_width/height_subsampling` • `bits_per_pixel` • `bytes_from_pixels` • `row_size` • `bmp_size`

### AVS+ extended (AviSynth+ specific)
`avs_is_444/422/420/y/yuva/planar_rgb/planar_rgba` • `num_components` • `component_size` • `bits_per_component` • `is_channel_mask_known/set/get` (V10)

### AVS_Value API (V11)
**Setters:** `set_to_clip/error/bool/int/float/string/long/double/array/void`
**Getters:** `get_as_bool/clip/int/long/string/float/error/array` • `get_array_size/elt`
**Type checkers:** `val_defined/is_clip/is_bool/is_int/is_long_strict/is_float/is_floatf_strict/is_string/is_array/is_error`
**Lifecycle:** `copy_value(dest, src)`, `release_value(val)`

### Environment utilities
`get_error` • `get_cpu_flags` • `get_cpu_flags_ex` (V12) • `save_string/sprintf/vsprintf` • `add_function/add_function_r` (V11) • `at_exit` • `bit_blt` • `new_video_frame_a/new_video_frame_p/p_a` (V8) • `make_writable` • `subframe/subframe_planar/subframe_planar_a` (V8) • `set_memory_max/working_dir` • `get_env_property` (V8) • `pool_allocate/free` (V8)

### Frame properties (V8+)
`get_frame_props_ro/rw` • `copy_frame_props` • `prop_num_keys/get_key/num_elements/get_type` • `prop_get_int/float/data/data_size/clip/frame` • `prop_get_int_saturated/float_saturated` (V11) • `prop_get_data_type_hint` (V11) • `prop_delete_key` • `prop_set_int/float/data/data_h` (V11) • `prop_set_clip/frame` • `prop_get_int_array/float_array` • `prop_set_int_array/float_array` • `clear_map`

### Sync (V12)
`avs_acquire_global_lock(env, name) -> int` • `avs_release_global_lock(env, name)`

---

## 4. Pixel type constants (AVS_CS_*)

**Families (bits 31-27):** `PLANAR=1<<31` `INTERLEAVED=1<<30` `YUV=1<<29` `BGR=1<<28` `YUVA=1<<27`
**Sub-width (0-2):** `SUB_WIDTH_1=3<<0` (444) `SUB_WIDTH_2=0<<0` (422/420) `SUB_WIDTH_4=1<<0` (411)
**Sub-height (8-10):** `SUB_HEIGHT_1=3<<8` `SUB_HEIGHT_2=0<<8` `SUB_HEIGHT_4=1<<8`
**Plane order:** `VPLANEFIRST=1<<3` `UPLANEFIRST=1<<4`
**Sample bits (16-18):** `8=0<<16` `10=5<<16` `12=6<<16` `14=7<<16` `16=1<<16` `32=2<<16`
**RGB planar:** `RGB_TYPE=1<<0` `RGBA_TYPE=1<<1`

Generics: `GENERIC_YUV444/422/420 = PLANAR|YUV|VPLANEFIRST|SUB_*` • `GENERIC_Y = PLANAR|INTERLEAVED|YUV` • `GENERIC_RGBP = PLANAR|BGR|RGB_TYPE` • `GENERIC_RGBAP = PLANAR|BGR|RGBA_TYPE` • `GENERIC_YUVA444/422/420 = PLANAR|YUVA|VPLANEFIRST|SUB_*`

**Common types (8b):** `YV24=GENERIC_YUV444|B8` `YV16=GENERIC_YUV422|B8` `YV12=GENERIC_YUV420|B8` `Y8=GENERIC_Y|B8` `I420=PLANAR|YUV|B8|UPlaneFirst|W2|H2` `BGR24=RGB_TYPE|BGR|INTERLEAVED` `BGR32=RGBA_TYPE|BGR|INTERLEAVED`
**Higher bit depths:** `YUV444P10/12/14/16/PS` • `YUV422P10/12/14/16/PS` • `YUV420P10/12/14/16/PS` • `Y10/Y12/Y14/Y16/Y32`
**RGB planar:** `RGBP[8/10/12/14/16/PS]` • `RGBAP[8/10/12/14/16/PS]`
**YUVA:** `YUVA444/422/420[P10/P12/P14/P16/PS]`

---

## 5. Plane constants (bitmask, not index)

`DEFAULT=0` `Y=1<<0` `U=1<<1` `V=1<<2` `ALIGNED=1<<3` `A=1<<4` `R=1<<5` `G=1<<6` `B=1<<7`

Zig's `Plane.Y=0` is actually `DEFAULT_PLANE`, works for 8b YUV but semantically `AVS_PLANAR_Y=1`.

---

## 6. C++ Plugin API (IScriptEnvironment)

Vendored `avisynth.h` defines the C++ vtable interface.

### IClip (filter base class)
```cpp
class IClip {
    virtual int GetVersion() = 0;
    virtual PVideoFrame GetFrame(int n, IScriptEnvironment* env) = 0;
    virtual bool GetParity(int n) = 0;
    virtual void GetAudio(void* buf, int64_t start, int64_t count, IScriptEnvironment* env) = 0;
    virtual int SetCacheHints(int cachehints, int frame_range) = 0;
    virtual const VideoInfo& GetVideoInfo() = 0;
};
```

### GenericVideoFilter (convenience base)
`PClip child` + `VideoInfo vi` → forwards all calls to child.

### IScriptEnvironment (core API surface, ~50 virtual methods)
Key methods used by chikuzen's plugin:
- `CreateScriptEnvironment(int version)` — DLL export, C-linkage
- `Invoke(name, args, arg_names) -> AVSValue` — evaluate script/function
- `GetAVSLinkage() -> const AVS_Linkage*` — get member function pointers
- `DeleteScriptEnvironment()` — cleanup
- `GetVar/SetVar/SetGlobalVar` — variable access
- `NewVideoFrame(vi, align)` / `NewVideoFrameP(vi, prop_src, align)` (V8)
- `MakeWritable` / `BitBlt` / `Subframe/Planar/A` • `SaveString` • `ThrowError`
- `GetCPUFlags` • `CheckVersion` • `FunctionExists`

AVS+ extensions (V8+): `copyFrameProps`, `getFramePropsRO/RW`, `propGet/Set*` • `Allocate/Free` • `GetEnvProperty` • `AcquireGlobalLock` (V12)

### IScriptEnvironment2 (extends IScriptEnvironment)
Adds: `LoadPlugin`, `AutoloadPlugins`, `SetFilterMTMode`, `ParallelJob`, `NewCompletion`

### INeoEnv (alt interface)
Same instance, extended for GPU/CUDA: Device support, `NewVideoFrame` with `PDevice`, overloaded `SetMemoryMax`.

### AVS_Linkage (vtable for member function pointers)
A struct of member function pointers used by the `AVS_BakedCode` macros. Plugins retrieve it via `env->GetAVSLinkage()`. Provides the `AVS_Linkage` pointer for call forwarding — **this is what `AVS_linkage` global is for in C++ plugins.**

---

## 7. Original C++ plugin architecture (chikuzen)

### Project structure
```
AvsReader.h        — class AvsReader (filter state)
AvsReader.cpp      — create(), getFrame(), write_yuv/rgb
plugin.cpp         — VapourSynth init/createFilter/get_frame/free_filter
myvshelper.h       — template get_prop/get_arg, bitblt
```

### Flow
1. **`VapourSynthPluginInit`** — registers `Import`/`Eval` functions
2. **`create_avsr`** — reads args (script/lines, bitdepth, alpha) → calls `AvsReader::create()`
3. **`AvsReader::create(input, bd, alpha, mode, core, api)`**:
   - `LoadLibrary("avisynth")` → `GetProcAddress("CreateScriptEnvironment")` → create env
   - `env->Invoke(mode, AVSValue(input))` → get `PClip`
   - `AVS_linkage = env->GetAVSLinkage()` — needed for AVS_BakedCode member calls
   - Converts YUY2 to YV16 automatically: `env->Invoke("ConvertToYV16", clip)`
   - Maps pixel types via lookup table: `get_vs_format(pixel_type, bitdepth)` → VS preset format
   - For >8b: halves width (Dither interleaved MSB/LSB)
   - For RGB32+alpha: 2 outputs
4. **`getFrame(n)`**: allocates VS frame, sets `_DurationNum/Den` props, calls `clip->GetFrame(n, env)`, copies via `write_yuv/rgb` template
5. **`write_yuv`**: iterates `PLANAR_Y/U/V` with `bitblt(api->getWritePtr, stride, src->GetReadPtr(plane), pitch, row_size, height)`
6. **`write_rgb<CHANNELS, ALPHA>`**: BGR → planar RGB (bottom-up flip), optional alpha
7. **Cleanup**: `~AvsReader` → `env->DeleteScriptEnvironment()` → `FreeLibrary(dll)`

### Key differences from Zig port

| Aspect | C++ original | Zig port |
|---|---|---|
| Avisynth entry | `LoadLibrary` + `GetProcAddress` dynamic | `linkSystemLibrary` static link |
| API level | C++ `IScriptEnvironment` (vtable) | C API (`avs_create_script_environment`) |
| Plugin init | VapourSynth API v3 (`VapourSynthPluginInit`) | VapourSynth API v4 (`VapourSynthPluginInit2`) |
| Filter creation | `api->createFilter()` + `api->setVideoInfo()` (old API) | `zapi.createVideoFilter()` (Zig ZAPI wrapper) |
| `AVS_linkage` | `env->GetAVSLinkage()` → global ptr | Not needed (pure C API) |
| Frame props | `api->propSetInt(props, "_DurationNum/Den", ...)` | `zapi.mapSetInt(props, "_DurationNum/Den", ...)` |
| Pixel mapping | hand-written table → `api->getFormatPreset(id)` | `vsapi.queryVideoFormat()` |
| Error handling | try/catch `std::string`/`AvisynthError` | Zig error union |
| YUY2 conversion | `env->Invoke("ConvertToYV16", clip)` | Not implemented |
| RGB24/32 | template `write_rgb<3,false>`/`write_rgb<4,false>` | separate `writeRGB24`/`writeRGB32` fns |
| Alpha output | 2 outputs (`cloneFrameRef`) | Not implemented |
| Memory mgmt | `new`/`delete` | `c_allocator.create/destroy` |
| UTF-8→ANSI | Win32 `MultiByteToWideChar` chain | Not needed (POSIX) |

### Current gaps in Zig port vs C++ original
- Alpha channel extraction (RGB32 → 2 outputs)
- YUY2 auto-conversion
- `bitdepth=9` support (C++ supports 8/9/10/16; Zig currently checks but allows 9 but doesn't validate width constraints)
- `avs_release_clip` not called in Zig
- More robust error path (C++ has nested try/catch for AvisynthError)

---

## 8. AviSynth+ on macOS

Since 3.5, native POSIX build. Library: `libavisynth.dylib`.
- `AVS_POSIX` defined, no `__stdcall`
- Dynamic loading: `dlopen`/`dlsym` (NOT `LoadLibrary`)
- `avs_load_library` in `avisynth_c.h` is Windows-only

Current `build.zig` uses `linkSystemLibrary("avisynth")` — works if brew/manual install provides it.

---

## 9. Version history

| Ver | Key additions |
|---|---|
| V6 | Classic Avisynth 2.6 baseline |
| V8 | Frame properties, `NewVideoFrameP`, subframe with alpha, `GetEnvProperty`, buffer pool |
| V9 | `MakePropertyWritable`, `IsPropertyWritable` |
| V10 | Frame pixel_type, channel mask, `AVS_DEFAULT_PLANE=0` |
| V11 | 64-bit `AVSValue` (`long`/`double`), API type checkers, `set_to_*/get_as_*` for all types, saturated prop getters, `add_function_r` |
| V12 | `AcquireGlobalLock`, `ReleaseGlobalLock`, `GetCPUFlagsEx`, `ApplyMessageEx`, `CACHE_INFORM_NUM_THREADS` |

Check version: `avs_get_version(clip)` or `avs_check_version(env, 8)`.

---

## 10. Zig gap analysis

| Area | Current | Missing |
|---|---|---|
| AVS_Value | `extern union { clip, string, int, float, longlong, double_pt }` | 32-bit union variant (`longlong_ptr`, `double_pt_ptr`) |
| Clip mgmt | only `take_clip` | `release_clip`, `copy_clip`, `get_version` |
| Env errors | inline `Eval` error capture | `avs_get_error`, `avs_check_version` |
| Frame props | none | full AVS_Map API for frame property passthrough |
| Pixel types | 7 types (YV12/YV16/YV24/YV411/I420/Y8/RGB24/32) | all AVS+ types (10-12-14-16-32b, RGBP, YUVA) |
| VideoInfo queries | `bits_per_component`, `is_planar_rgb/rgba` | `num_components`, `is_444/422/420/y`, `component_size` |
| Platform | x86_64 assumed | handle 32-bit union layout |
| Alpha | none | RGB32 alpha extraction |
| YUY2 | none | auto-convert to YV16 |

---

## References
- https://github.com/AviSynth/AviSynthPlus
- https://github.com/chikuzen/VS_AvsReader
- https://github.com/PlaneSight/VS_AvsReader (fork, VS4 port)
- http://avisynth.nl
