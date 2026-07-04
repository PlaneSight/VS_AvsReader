# Vendored AviSynth+ Scripts (.avsi)

Two-tier collection of AviSynth+ function libraries vendored for use
with VS_AvsReader.  Import them with `Import()` or place in your
AviSynth+ autoload directory.

## Top-level (core Dogway scripts)

| File | Source | Description |
|------|--------|-------------|
| `ExTools.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Filtering, masking, adjustment tools (700+ KB). Stdlib `Expr()`-based. |
| `SMDegrain.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | MVTools MDegrain wrapper. Temporal denoising. |
| `ResizersPack.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Resizing (nnedi3, eedi3, spline, etc.). |
| `TransformsPack.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Color / transfer function conversions. |
| `GradFun3.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Banding removal (Dither-based). |
| `FilmGrain.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Film grain generation. |

## `dogway/` — extended Dogway pack

| File | Description |
|------|-------------|
| `FilmGrain+.avsi` | Enhanced film grain |
| `GradePack.avsi` | Color grading tools |
| `MasksPack.avsi` | Masking utilities |
| `ScenesPack.avsi` | Scene detection |
| `Logo.avsi` | Logo removal |
| `yugefunc.avsi` | YUV utilities |
| `TransformsPack - Main.avsi` | Transforms core |
| `TransformsPack - Models.avsi` | Camera models |
| `TransformsPack - Transfers.avsi` | Transfer functions |
| `Stabilization Tools Pack.avsi` | Stabilization |
| `ex_SMDegrain/` | Extended SMDegrain variants |
| `EX mods/` | Expr-based modifications |
| `MIX mods/` | Mixed modifications |
| `External_deps/` | External dependency wrappers |

## `scripts/` — uvz community collection (170+ scripts)

From [AviSynthPlus-Plugins-Scripts1](https://gitlab.com/uvz/AviSynthPlus-Plugins-Scripts1).
Includes QTGMC, dither tools, LSFmod, AnimeIVTC, FineDehalo, MCTD,
eedi3_resize16, InpaintDelogo, and many more.

## Requirements

Most scripts need AviSynth+ plugins loaded at runtime (e.g. MVTools2,
nnedi3, dither, AddGrainC).  Refer to each script's header for deps.
Core plugins are vendored in `../plugins/`.

## License

Each script carries its own license.  Dogway scripts: GPL-2.0+.
uvz collection: per-script.  See file headers.
