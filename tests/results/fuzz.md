# AVSR Fuzz Results

**Date:** 2026-07-05 07:31:27  
**Seed:** 42  
**Scripts requested:** 5000  
**Elapsed:** 259.0s  

## Summary

| Metric  | Count | Rate    |
|---------|-------|---------|
| Total   | 5000 |         |
| Success | 3034 | 60.7% |
| Crash   | 1 | 0.0% |
| Error   | 1965 | 39.3% |

## Crashes by Filter

| Filter | Crashes |
|--------|---------|
| BilinearResize | 1 |
| ConvertToYUY2 | 1 |
| SeparateFields | 1 |

## Crashes by Source

| Source | Crashes |
|--------|---------|
| Version | 1 |

## Crashes by Dimensions

| Width | Height | Crashes |
|-------|--------|---------|
| 63 | 63 | 1 |

## Sample Errors (non-crash)

- **Error:** `avsr: failed to create AviSynth environment`
  Script: `BlankClip(width=64, height=64, pixel_type="RGB32", length=9) / PointResize(75,192) / ConvertToYUY2()`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `BlankClip(width=17, height=11, pixel_type="YV12", length=12) / PointResize(26,190) / UToY() / Levels(31.13`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `Blackness(width=128, height=128, length=27) / ColorYUV(gain_y=-13.0, cont_u=-29.0, cont_v=-23.3) / Conve`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `ColorBars(width=63, height=63, pixel_type="Y8") / LanczosResize(170,219) / ConvertToY8() / LanczosResize(2`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `Blackness(width=17, height=11, length=3) / Histogram("classic") / FadeIn0(2)`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `ColorBars(width=32, height=32, pixel_type="Y8") / Crop(0,0,0,0) / Reverse() / Crop(4,4,-4,-4) / Trim(0, 0)`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `BlankClip(width=3, height=3, pixel_type="YV12", length=5) / GreyScale() / ConvertToRGB24()`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `Blackness(width=7, height=7, length=6) / ConvertToYUY2() / Reverse() / AssumeFrameBased().SeparateFields()`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `ColorBars(width=7, height=7, pixel_type="YUY2") / ConvertToYV12() / FadeIn0(2) / GeneralConvolution(0,"0 -`
- **Error:** `avsr: failed to create AviSynth environment`
  Script: `BlankClip(width=65, height=65, pixel_type="YV12", length=29) / FadeOut0(2)`

