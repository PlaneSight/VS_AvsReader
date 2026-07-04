# VS_AvsReader

> **AviSynth Script Reader plugin for VapourSynth (API v4)**

Bridges AviSynth scripts into VapourSynth by loading `avisynth.dll` at
runtime and wrapping it inside a VapourSynth source filter. Use any
AviSynth filter that lacks a VapourSynth equivalent — `DirectShowSource`,
`ColorMatrix`, or entire AviSynth script pipelines.

**Author:** Oka Motofumi (chikuzen.mo at gmail dot com)  
**VS4 API port:** [PlaneSight](https://github.com/PlaneSight)

---

## Requirements

- [VapourSynth](https://www.vapoursynth.com/) R70+ (API v4)
- [AviSynth 2.6 / AviSynth+](http://avisynth.nl)
- C++17 compiler (MSVC 2022, GCC 11+, Clang 14+)
- CMake 3.16+

## Build

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The output is a shared library (`vsavsreader.dll` / `libvsavsreader.so` /
`vsavsreader.dylib`) loaded via `core.std.LoadPlugin()`.

## Usage

```python
import vapoursynth as vs
core = vs.core
core.std.LoadPlugin('/path/to/vsavsreader.so')

# Load an external AviSynth script
clip = core.avsr.Import('/path/to/script.avs')

# Evaluate inline AviSynth code
clip = core.avsr.Eval('ColorBars(320, 240, "YV12")')
```

### Parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `script` / `lines` | `data` | required | AviSynth script path or inline code |
| `bitdepth` | `int` | `8` | Output bitdepth (8, 9, 10, 16) |
| `alpha` | `bool` | `true` | Extract alpha channel from RGB32 |

### Dither tool interop

Convert Dither's interleaved MSB/LSB to native VapourSynth high bitdepth:

```python
clip = core.avsr.Import('/path/to/script.avs', bitdepth=16)
```

Where `script.avs` contains e.g.:

```avs
LoadPlugin("DGDecode.dll")
LoadPlugin("Dither.dll")
MPEG2Source("source.d2v")
Dither_convert_8_to_16()
Dither_resize16(1280, 720)
Dither_convey_yuv4xxp16_on_yvxx()
```

> **Note:** Only interleaved MSB/LSB (not stacked). YUV planar only.

### Alpha channel

When the input is RGB32 and `alpha=True`, two clip outputs are created:
- `Import` — base RGB clip
- `Import_Alpha` — alpha channel as Gray8

## Project structure

```
VS_AvsReader/
├── CMakeLists.txt          # Build system
├── LICENSE.LGPLv2.1        # LGPL 2.1
├── README.md               # This file
├── src/                    # Source code
│   ├── AvsReader.cpp
│   ├── AvsReader.h
│   ├── myvshelper.h
│   └── plugin.cpp
├── vendor/                 # Vendored SDK headers
│   ├── vapoursynth/
│   │   └── VapourSynth4.h
│   └── avisynth/
│       ├── avisynth.h
│       └── avs/...
└── build/                  # Build output (gitignored)
```

## Links

- [Source repository](https://github.com/PlaneSight/VS_AvsReader) (fork)
- [Original repository](https://github.com/chikuzen/VS_AvsReader) (chikuzen)
- [Doom9 discussion](https://forum.doom9.org/showthread.php?t=165957)
- [VapourSynth](https://www.vapoursynth.com/)
- [AviSynth+](https://github.com/AviSynth/AviSynthPlus)
