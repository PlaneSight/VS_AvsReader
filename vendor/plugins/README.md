# Vendored AviSynth+ Plugin Binaries

161 Windows x64 plugin DLLs from the
[uvz collection](https://gitlab.com/uvz/AviSynthPlus-Plugins-Scripts1)
bundled for use with VS_AvsReader on Windows targets. On macOS/Linux
these are not directly loadable but serve as the canonical reference
set; platform-specific builds must be substituted at runtime.

## Contents (excerpt)

| Category | Plugins |
|----------|---------|
| Sources | `BestSource.dll`, `FFMS2.dll`, `DGDecodeNV.dll`, `LSMASHSource.dll` |
| Denoising | `BM3DCPU_AVS.dll`, `dfttest.dll`, `FFT3DFilter.dll`, `KNLMeansCL.dll` |
| Motion | `mvtools2.dll`, `SVPflow1.dll`, `SVPflow2.dll` |
| Resizing | `nnedi3.dll`, `eedi3.dll`, `avsresize.dll` |
| Sharpening | `aWarpsharpMT.dll`, `CAS.dll`, `FineSharp.dll` |
| Debanding | `flash3kyuu_deband.dll`, `neo_f3kdb.dll` |
| Grain | `AddGrainC.dll` |
| Masking | `masktools2.dll` |
| Color | `vsTCanny.dll`, `TColorMask.dll` |
| Deinterlacing | `TIVTC.dll`, `QTGMC.avsi` (in avsi/) |
| Utility | `AvsInPaint.dll`, `GRunT.dll`, `Zs_RF_Shared.dll` |

## macOS/Linux note

These are Windows PE DLLs. On POSIX targets AviSynth+ loads `.so`/`.dylib`
equivalents. The `.dll` files are vendored as the canonical reference;
cross-compiled or Homebrew-provided equivalents are expected at runtime.

## Source

[AviSynthPlus-Plugins-Scripts1](https://gitlab.com/uvz/AviSynthPlus-Plugins-Scripts1)
— community-curated plugin pack. Each plugin carries its own license.
