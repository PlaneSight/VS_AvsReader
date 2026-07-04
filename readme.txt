vsavsreader 2.0.0 -- AviSynth Script Reader plugin for VapourSynth (API v4)

 Author: Oka Motofumi (chikuzen.mo at gmail dot com)
 Ported to VapourSynth4 API by: PlaneSight

------------------------------------------------------------------------

Requirements:
  - VapourSynth R70+ (API v4, VapourSynth4.h)
  - AviSynth 2.6 / AviSynth+
  - C++17 compiler (MSVC 2022, GCC 11+, Clang 14+)
  - CMake 3.16+

Source code:
  https://github.com/PlaneSight/VS_AvsReader (fork)
  https://github.com/chikuzen/VS_AvsReader (original)

------------------------------------------------------------------------

Build:

  mkdir build && cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release
  cmake --build .

On Windows, make sure VapourSynth headers are discoverable, or pass:
  -DVAPOURSYNTH_INCLUDE_DIR="C:/Program Files/VapourSynth/include"

The plugin is a shared library (.dll/.so/.dylib) loaded via
core.std.LoadPlugin().

------------------------------------------------------------------------

How to use:

  # Preparation
  >>> import vapoursynth as vs
  >>> core = vs.core
  >>> core.std.LoadPlugin('./vsavsreader.so')

  # Case 'Import'
  >>> clip = core.avsr.Import('/path/to/script.avs')

  # Case 'Eval'
  >>> clip = core.avsr.Eval('ColorBars(320, 240, "YV12")')

  # Eval with inline script
  >>> lines = '''
  ... LoadPlugin("/path/to/RawSource.dll")
  ... v1 = RawSource("/path/to/video.y4m")
  ... v1.ConvertToYV24().Spline64Resize(1280, 720)
  ... v2 = AVISource("/path/to/video2.avi").ConvertToYV24()
  ... return v1 + v2
  ... '''
  >>> clip = core.avsr.Eval(lines=lines)

------------------------------------------------------------------------

Advanced usage — Dither tool interop:

  VS_AvsReader converts Dither's interleaved MSB/LSB format into a
  compatible VapourSynth YUV4xxP9/10/16 format.  Dither's MSB/LSB must
  be interleaved (stacked format is not supported).  Only YUV planar
  formats are allowed.

  Example:

  >>> clip = core.avsr.Import('/path/to/script.avs', bitdepth=16)

  Where script.avs contains e.g.:

    LoadPlugin("DGDecode.dll")
    LoadPlugin("Dither.dll")
    Import("Dither.avsi")
    MPEG2Source("source.d2v")
    Dither_convert_8_to_16()
    Dither_resize16(1280, 720)
    Dither_convey_yuv4xxp16_on_yvxx()

------------------------------------------------------------------------

Notes:

  - When input pixel type is RGB32, the filter can return a second
    clip containing the alpha channel (Gray8).  Enable with alpha=True.

  - YUY2 input is automatically converted to YV16 by the reader.

  - This version uses the VapourSynth v4 API (VapourSynth4.h).
    It will NOT work with VapourSynth R58 or earlier (v3 API).

  - Cross-platform support (macOS/Linux) is experimental — AviSynth+
    must be built and linked for the target platform.  On non-Windows
    systems, the AviSynth shared library must be pre-loaded.
