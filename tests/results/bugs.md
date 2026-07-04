# Known Bugs — avsr + AviSynth ImageSource

Filters that crash the AviSynth environment when applied to clips
derived from `ImageSource` (GIF/PNG/JPEG sources loaded through AviSynth+).

Source: `ImageSource("path/to/image.gif", fps=24, end=N)`
Tested on: AviSynth+ bundled with avsr (macOS), GIF 670×589

---

## Crashes

| Filter | Test | Works on BlankClip? |
|---|---|---|
| `ConvertToYV12(clip)` | any ImageSource clip | yes |
| `ConvertToYV24(clip)` | any ImageSource clip | yes |
| `ConvertToYUY2(clip)` | any ImageSource clip | yes |
| `Tweak(...)` — any params | any ImageSource clip | yes |
| `ColorYUV(...)` — any params | any ImageSource clip | yes |
| `Limiter(...)` — any params | any ImageSource clip | yes |

Error: `avsr: failed to create AviSynth environment`

## Works

| Filter | Notes |
|---|---|
| `ConvertToRGB24()` | explicit conversion before further processing |
| `RGBAdjust(r,g,b,a)` | works in RGB24 |
| `Levels(...)` | works on any format |
| `GeneralConvolution(...)` | works on any format |
| `Layer(...)` | works on RGB24 |
| `BilinearResize(...)` | works (stays in source colorspace) |
| `Subtitle(...)` | works |
| `Info()` | works |
| `Crop(...)` | works |
| `BlankClip()` | works as a mixer |

## Workaround

Stay in **RGB24** space throughout the chain:

```avisynth
ImageSource("file.gif", fps=24, end=N)
ConvertToRGB24()
RGBAdjust(1.2, 1.0, 1.0, 1.0)   # instead of Tweak(sat=1.15)
GeneralConvolution(0, "...")      # sharpening works on any format
Layer(last_orig, last, "add", 77) # compositing works
Levels(16, 1.0, 235, 16, 235)     # instead of Limiter(16,235,16,240)
```

Let VapourSynth handle the final RGB→YUV conversion:

```python
clip = core.resize.Bicubic(avs_clip, format=vs.YUV420P8, matrix_s="709")
```

## Hypothesis

Filters that internally convert between RGB and YUV (`Tweak`, `ColorYUV`,
`ConvertToYV12`, `Limiter`) trigger a code path in AviSynth+ that crashes
when the input clip was originally loaded via `ImageSource`. The crash happens
during AviSynth environment creation, suggesting a static initialization
or filter-chain compilation issue rather than a runtime frame-processing bug.

Filters that operate purely in the current colorspace (`RGBAdjust`, `Levels`,
`GeneralConvolution`, `Layer`) work correctly regardless of source.

---

## Fuzz Results — 2026-07-05 (5000 scripts, seed 42)

Automated fuzzing via `tests/fuzz_stdlib.py` — randomized stdlib filter chains
with 37 filters, 14 dimension sets, 7 pixel formats, random parameters.

| Metric | Count | Rate |
|---|---|---|
| Total | 5000 | — |
| Success | 3034 | 60.7% |
| Error (non-crash) | 1965 | 39.3% |
| Crash (segfault) | 1 | 0.02% |

### Crash repro

```
Version() / ConvertToYUY2() / AssumeFrameBased().SeparateFields() /
BilinearResize(213, 9)
```

Manual repro attempt returns a non-crash error — subprocess exit code
may have been misclassified. No confirmed native crash.

### High-level takeaways

- **0 confirmed native segfaults in 5000 random chains** — avsr/AviSynth+
  integration is stable under fuzz
- 39% error rate is mostly format-incompatible filter chains (e.g., YUV-only
  filters applied to RGB32 sources like default `Blackness()`)
- `Blackness()` defaults to RGB32 — `ColorYUV`, `Tweak`, `Limiter` fail on
  it unless preceded by `ConvertToYV12()`
- `ConvertToYUY2()` fails on `Version()` output (RGB) and on some
  `Blackness()` chains
- `Histogram("classic")` + `FadeIn0(2)` fails on certain chain lengths

### Stability assessment

The fuzzer's subprocess isolation prevented any cascade failures.
AviSynth+ environment creation errors (`"failed to create AviSynth
environment"`) are the dominant failure mode — these are caught gracefully
by avsr and do not crash the VapourSynth host process.
