# Vendored AviSynth+ Scripts (.avsi)

These are popular AviSynth+ function libraries vendored for use with
VS_AvsReader.  Place them in your AviSynth+ autoload directory or
`Import()` them from your scripts.

## Scripts

| File | Source | Description |
|------|--------|-------------|
| `ExTools.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Extensive collection of filtering, masking, and adjustment tools. 700+ KB of utility functions. |
| `SMDegrain.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Motion-compensated temporal denoising wrapper around MVTools. Configurable prefilter, subpixel motion, and tritical refinements. |
| `ResizersPack.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | High-quality resizing wrappers (nnedi3, eedi3, spline, etc.) with format and bitdepth handling. |
| `TransformsPack.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Color space and transfer function conversions (matrix, primaries, gamma, PQ, HLG). |
| `GradFun3.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Gradient smoothing / banding removal (GradFun3+ port, works with Dither tools). |
| `FilmGrain.avsi` | [Dogway/Avisynth-Scripts](https://github.com/Dogway/Avisynth-Scripts) | Film grain generation and matching. |

## Requirements

Most scripts depend on additional AviSynth plugins loaded at runtime
(e.g. `mvtools.dll`, `nnedi3.dll`, `dither.dll`).  These are **not**
vendored here.  Refer to each script's header for its dependency list.

## License

Each script carries its own license.  Dogway's scripts are generally
GPL-2.0 or later.  See the header of each `.avsi` file for details.
