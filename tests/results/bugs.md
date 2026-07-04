# Known Limitations — avsr + AviSynth+ stdlib

Filters that reject certain input formats in the AviSynth+ build bundled
with avsr on macOS.

Tested on: AviSynth+ 3.7.5 via avsr

---

## YUV-Only Filters Reject RGB Input

`Tweak`, `ColorYUV`, and `Limiter` do not auto-convert RGB input to YUV.
They return a script error when applied to RGB clips.

| Filter | Error Message |
|---|---|
| `Tweak(sat=1.0)` on RGB | `Tweak: YUV data only (no RGB)` |
| `ColorYUV(gain_y=10)` on RGB | `ColorYUV: Only work with YUV colorspace.` |
| `Limiter()` on RGB | `Limiter: Source must be YUV or YUVA` |

This affects ANY RGB source (ImageSource, BlankClip(RGB24), Blackness, etc.).

### What works on RGB input

| Filter | Notes |
|---|---|
| `ConvertToYV12()` | Explicit YUV conversion works on RGB |
| `ConvertToYV16()` | works |
| `ConvertToYV24()` | works |
| `ConvertToYUY2()` | works |
| `ConvertToY8()` | works |
| `ConvertToRGB24()` | works |
| `ConvertToRGB32()` | works |
| `RGBAdjust(r,g,b,a)` | works |
| `Levels(...)` | works |
| `GeneralConvolution(...)` | works |
| `BilinearResize(...)` | works |
| `Subtitle(...)` | works |
| `Info()` | works |
| `Crop(...)` | works |

### Workaround A: Convert to YUV first

```avisynth
BlankClip(width=64, height=64, pixel_type="RGB24", length=1)
ConvertToYV12()
Tweak(sat=1.0)
ColorYUV(gain_y=10)
Limiter()
```

### Workaround B: Stay in RGB, use VS conversion

Use RGB-native AviSynth filters, let VapourSynth handle YUV conversion:

```avisynth
BlankClip(width=64, height=64, pixel_type="RGB24", length=1)
RGBAdjust(1.0, 1.0, 1.0, 1.0)
Levels(0, 1, 255, 0, 255)
```

```python
clip = core.resize.Bicubic(avs_clip, format=vs.YUV420P8, matrix_s="709")
```

---

## Error Reporting Fix (2026-07-05)

Previously all AviSynth script errors were swallowed and replaced with the
generic `"avsr: failed to create AviSynth environment"`. avsr now surfaces
AviSynth+'s actual error messages, e.g.:

- `Tweak: YUV data only (no RGB)`
- `Script error: There is no function named 'foobar'.`

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
- 39% error rate is mostly format-incompatible filter chains (YUV-only
  filters on RGB sources, Invalid function names, etc.)
- `Blackness()` defaults to RGB32 — `ColorYUV`, `Tweak`, `Limiter` fail on
  it unless preceded by `ConvertToYV12()`
