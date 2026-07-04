"""Pixel-level diagnostic: read raw bytes from AviSynth frames via avsr
and compare to expected values. Checks for pitch/stride mismatches.
"""

from pathlib import Path
import ctypes

import vapoursynth as vs

_ROOT = Path(__file__).parent.parent
PLUGIN = _ROOT / "build" / "vsavsreader.dylib"

core = vs.core
core.std.LoadPlugin(str(PLUGIN))


def dump_first_rows(label, clip, plane=0, nrows=4):
    f = clip.get_frame(0)
    ptr = f.get_read_ptr(plane)
    stride = f.get_stride(plane)
    w = f.width if plane == 0 else f.width // 2
    h = f.height if plane == 0 else f.height // 2
    print(f"--- {label} plane {plane}: {w}x{h} stride={stride} ---")
    # ptr is c_void_p; use ctypes to read bytes
    addr = ctypes.addressof(ctypes.cast(ptr, ctypes.POINTER(ctypes.c_uint8)).contents)
    buf = (ctypes.c_uint8 * (stride * h)).from_address(addr)
    for y in range(min(nrows, h)):
        row = buf[y * stride : y * stride + w]
        vals = list(row[:min(w, 32)])
        print(f"  row {y}: {vals}")
    return f  # keep ref alive


# Test 1: AviSynth BlankClip with known YUV value
# $808080 = Y=128, U=128, V=128
print("=== Test 1: AviSynth BlankClip color=$808080 ===")
avs_clip = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$808080, length=1)\n'
)
if isinstance(avs_clip, list):
    avs_clip = avs_clip[0]
f1 = dump_first_rows("AviSynth BlankClip $808080", avs_clip, 0)

# Test 2: VS BlankClip with [128, 128, 128]
print("\n=== Test 2: VS BlankClip [128,128,128] ===")
vs_clip = core.std.BlankClip(width=16, height=16, format=vs.YUV420P8,
                             color=[128, 128, 128], length=1)
f2 = dump_first_rows("VS BlankClip [128,128,128]", vs_clip, 0)

# Test 3: AviSynth BlankClip with $FFFFFF (should be Y=255)
print("\n=== Test 3: AviSynth BlankClip color=$FFFFFF ===")
avs_white = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$FFFFFF, length=1)\n'
)
if isinstance(avs_white, list):
    avs_white = avs_white[0]
f3 = dump_first_rows("AviSynth BlankClip $FFFFFF", avs_white, 0)

# Test 4: AviSynth BlankClip with $000000 (should be Y=0)
print("\n=== Test 4: AviSynth BlankClip color=$000000 ===")
avs_black = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$000000, length=1)\n'
)
if isinstance(avs_black, list):
    avs_black = avs_black[0]
f4 = dump_first_rows("AviSynth BlankClip $000000", avs_black, 0)

# Test 5: Check U/V planes — AviSynth YV12 plane order is Y, V, U
# VapourSynth YUV420P8 plane order is Y, U, V
# If avsr copies plane 1 (AviSynth V) to plane 1 (VS U), colors swap.
print("\n=== Test 5: U/V plane check ===")
# Use color=$805080 — Y=128, U=80(=128), V=50(=80)
# Wait, AviSynth color format for YV12 is $VVUUYY (V high, U mid, Y low)
# Actually it's $VVUUYY in AviSynth. Let me check.
# $805080: V=0x80=128, U=0x50=80, Y=0x80=128
avs_color = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$805080, length=1)\n'
)
if isinstance(avs_color, list):
    avs_color = avs_color[0]
print("AviSynth $805080 (V=128, U=80, Y=128):")
f5a = dump_first_rows("  Y plane", avs_color, 0)
f5b = dump_first_rows("  plane 1 (AviSynth V=128, VS expects U)", avs_color, 1)
f5c = dump_first_rows("  plane 2 (AviSynth U=80, VS expects V)", avs_color, 2)

# Keep all frame refs alive
_ = [f1, f2, f3, f4, f5a, f5b, f5c]
