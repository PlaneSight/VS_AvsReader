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

## Porting `.avsi` to VapourSynth with `avsr` as a reference oracle

The plugin is useful as a porting aid: keep the original AviSynth script
running through `core.avsr.Import` / `core.avsr.Eval` as a **reference
clip**, re-implement the same filter in native VapourSynth, and diff the
two frame-by-frame. When the diff goes to zero you have a faithful port.

This is especially handy for the many `.avsi` helper packs in
`vendor/avsi/` (ExTools, ResizersPack, TransformsPack, GradFun3, …)
which are mostly thin wrappers around AviSynth's `Expr()`. The
VapourSynth equivalent is `std.Expr`, and
[`vsexprtools.inline_expr`](https://jaded-encoding-thaumaturgy.github.io/vs-jetpack/api/vsexprtools/inline/manager/)
lets you write those RPN expressions in readable Python syntax.

### Workflow

1. **Run the original `.avsi` through AviSynth** to obtain the reference
   clip. Use `Import` for a script file, or `Eval` for an inline snippet.
2. **Port the filter to VapourSynth** using native filters and
   `inline_expr` for any per-pixel expression the `.avsi` feeds to
   `Expr()`.
3. **Compare** the reference and ported clips with `std.PlaneStats` (or
   `akarin.Expr` / `vs.core.std.Diff`); assert max abs diff is below
   your tolerance (0 for bit-exact, 1 for rounding-leeway).

### Example: porting `ex_invert` from ExTools.avsi

`ex_invert` in `vendor/avsi/ExTools.avsi` reduces to
`Expr(a, "range_max x -")` for the luma plane (full-range case). Here is
a side-by-side port using `inline_expr`:

```python
import vapoursynth as vs
from vsexprtools import inline_expr

core = vs.core
core.std.LoadPlugin("/path/to/vsavsreader.dylib")

AVSI = "/path/to/vendor/avsi/ExTools.avsi"
SRC  = 'BlankClip(width=64, height=48, pixel_type="YV12", color=$808080)'

# 1) Reference: original AviSynth ex_invert() via the avsr plugin.
ref = core.avsr.Eval(
    lines=(
        f'Import("{AVSI}")\n'
        f'{SRC}\n'
        'ex_invert()\n'
    ),
)
if isinstance(ref, list):
    ref = ref[0]

# 2) Port: native VapourSynth re-implementation with inline_expr.
src = core.std.BlankClip(width=64, height=48, format=vs.YUV420P8, color=[128, 128, 128])

with inline_expr(src) as ie:
    # ie.vars[0].RangeMax resolves to the Expr `range_max` token for this clip.
    ie.out = ie.vars[0].RangeMax - ie.vars[0]
port = ie.clip

# 3) Compare. ex_invert is bit-exact, so max diff must be 0.
diff = core.std.PlaneStats(ref, port)
stats = diff.get_frame(0).props
assert stats["PlaneStatsMax"] == 0, stats["PlaneStatsMax"]
```

### Example: porting an `ex_lutxy`-style diff expression

Many ExTools helpers are `ex_lutxy(a, b, "x y -")` — a per-pixel diff.
The same in VapourSynth:

```python
from vsexprtools import inline_expr

a = core.std.BlankClip(width=64, height=48, format=vs.YUV420P8, color=[120, 128, 128])
b = core.std.BlankClip(width=64, height=48, format=vs.YUV420P8, color=[100, 128, 128])

with inline_expr([a, b]) as ie:
    ie.out = ie.vars[0] - ie.vars[1]
diff = ie.clip
```

Reference side, for comparison:

```python
ref = core.avsr.Eval(
    lines=(
        f'Import("{AVSI}")\n'
        'a = BlankClip(width=64, height=48, pixel_type="YV12", color=$787878)\n'
        'b = BlankClip(width=64, height=48, pixel_type="YV12", color=$646464)\n'
        'ex_lutxy(a, b, "x y -")\n'
    ),
)
```

### Tips

- **Bitdepth**: `avsr` outputs 8-bit by default. Match the ported clip's
  format with `bitdepth=16` (Dither MSB/LSB) or convert in VS with
  `core.fmtc.bitdepth` / `core.resize.Bicubic` to compare apples-to-apples.
- **Color range**: AviSynth clips do not carry `_ColorRange` frame
  properties. Set them on the ported clip (`core.std.SetFrameProp`) or
  strip them before diffing so `std.PlaneStats` does not miscompare.
- **UV handling**: ExTools' `UV=` parameter (1=garbage, 2=copy first,
  3=process, …) maps to which planes you pass to `inline_expr`. For
  `UV=1` only express the Y plane and `core.std.ShufflePlanes`-copy U/V
  from the source.
- **Tolerance**: rounding in scaler/convolution kernels often produces a
  max abs diff of 1–2 even for "faithful" ports. Use
  `core.std.PlaneStats`'s `PlaneStatsMax` and pick a threshold that
  matches your definition of correctness.
- **Reproducible input**: feed both sides the same `BlankClip` seed
  (`color=...`) so the diff is deterministic. For noise-dependent
  filters, render the AviSynth side once and `core.std.Cache` it.

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
├── vendor/                 # Vendored dependencies
│   ├── vapoursynth/
│   │   └── VapourSynth4.h
│   ├── avisynth/
│   │   ├── avisynth.h
│   │   └── avs/...
│   ├── avsi/               # Vendored AviSynth+ scripts
│   │   ├── ExTools.avsi
│   │   ├── FilmGrain.avsi
│   │   ├── GradFun3.avsi
│   │   ├── ResizersPack.avsi
│   │   ├── SMDegrain.avsi
│   │   └── TransformsPack.avsi
│   └── plugins/            # Vendored AviSynth+ plugin binaries
│       ├── libconvertstacked.dylib
│       ├── libimageseq.dylib
│       ├── libshibatch.dylib
│       └── libtimestretch.dylib
├── tests/                  # Test suite
│   └── test_plugin.py
└── build/                  # Build output (gitignored)
```

## Links

- [Source repository](https://github.com/PlaneSight/VS_AvsReader) (fork)
- [Original repository](https://github.com/chikuzen/VS_AvsReader) (chikuzen)
- [Doom9 discussion](https://forum.doom9.org/showthread.php?t=165957)
- [VapourSynth](https://www.vapoursynth.com/)
- [AviSynth+](https://github.com/AviSynth/AviSynthPlus)
