"""Pixel-level diagnostic: read raw bytes from AviSynth frames via avsr
and compare to expected values. Checks for pitch/stride mismatches.
Uses Polars DataFrames for structured data collection and comparison.
"""

from pathlib import Path
import ctypes

import polars as pl
import vapoursynth as vs

_ROOT = Path(__file__).parent.parent
PLUGIN = _ROOT / "build" / "vsavsreader.dylib"

core = vs.core
core.std.LoadPlugin(str(PLUGIN))


def dump_first_rows(label, clip, plane=0, nrows=4):
    """Read raw bytes from a frame plane, return a dict with metadata and
    a Polars DataFrame of (row, col, value) records plus a pivoted view."""
    f = clip.get_frame(0)
    ptr = f.get_read_ptr(plane)
    stride = f.get_stride(plane)
    w = f.width if plane == 0 else f.width // 2
    h = f.height if plane == 0 else f.height // 2

    print(f"--- {label} plane {plane}: {w}x{h} stride={stride} ---")

    # Same ctypes raw-byte-reading logic as before
    addr = ctypes.addressof(
        ctypes.cast(ptr, ctypes.POINTER(ctypes.c_uint8)).contents
    )
    buf = (ctypes.c_uint8 * (stride * h)).from_address(addr)

    # Collect pixel values into structured records (long format)
    records = []
    for y in range(min(nrows, h)):
        row_slice = buf[y * stride : y * stride + w]
        for x in range(min(w, 32)):
            records.append({"row": y, "col": x, "value": int(row_slice[x])})

    df_long = pl.DataFrame(records)
    print(df_long)
    print()

    # Also build and print a pivoted (wide) view for compact visual scanning
    df_wide = df_long.pivot(
        index="col", columns="row", values="value", aggregate_function="first"
    ).sort("col")
    # Rename columns from integer row numbers to "R0", "R1", etc.
    rename_map = {c: f"R{c}" for c in df_wide.columns if c != "col"}
    df_wide = df_wide.rename(rename_map)
    print(df_wide)
    print()

    return {
        "label": f"{label} plane {plane}",
        "plane": plane,
        "width": w,
        "height": h,
        "stride": stride,
        "df": df_long,
        "frame": f,  # keep ref alive
    }


# ---------------------------------------------------------------------------
# Collect results from each test into a list for the final summary
results = []

# Test 1: AviSynth BlankClip with known YUV value
# $808080 = Y=128, U=128, V=128
print("=== Test 1: AviSynth BlankClip color=$808080 ===")
avs_clip = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$808080, length=1)\n'
)
if isinstance(avs_clip, list):
    avs_clip = avs_clip[0]
r1 = dump_first_rows("AviSynth BlankClip $808080", avs_clip, 0)
r1["expected"] = 128
results.append(r1)

# Test 2: VS BlankClip with [128, 128, 128]
print("\n=== Test 2: VS BlankClip [128,128,128] ===")
vs_clip = core.std.BlankClip(
    width=16, height=16, format=vs.YUV420P8, color=[128, 128, 128], length=1
)
r2 = dump_first_rows("VS BlankClip [128,128,128]", vs_clip, 0)
r2["expected"] = 128
results.append(r2)

# Test 3: AviSynth BlankClip with $FFFFFF (should be Y=255)
print("\n=== Test 3: AviSynth BlankClip color=$FFFFFF ===")
avs_white = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$FFFFFF, length=1)\n'
)
if isinstance(avs_white, list):
    avs_white = avs_white[0]
r3 = dump_first_rows("AviSynth BlankClip $FFFFFF", avs_white, 0)
r3["expected"] = 255
results.append(r3)

# Test 4: AviSynth BlankClip with $000000 (should be Y=0)
print("\n=== Test 4: AviSynth BlankClip color=$000000 ===")
avs_black = core.avsr.Eval(
    lines='BlankClip(width=16, height=16, pixel_type="YV12", color=$000000, length=1)\n'
)
if isinstance(avs_black, list):
    avs_black = avs_black[0]
r4 = dump_first_rows("AviSynth BlankClip $000000", avs_black, 0)
r4["expected"] = 0
results.append(r4)

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
r5a = dump_first_rows("  Y plane", avs_color, 0)
r5a["expected"] = 128
results.append(r5a)

r5b = dump_first_rows("  plane 1 (AviSynth V=128, VS expects U)", avs_color, 1)
r5b["expected"] = 128  # AviSynth V plane (= plane 1 in AVS, becomes VS plane 1)
results.append(r5b)

r5c = dump_first_rows("  plane 2 (AviSynth U=80, VS expects V)", avs_color, 2)
r5c["expected"] = 80  # AviSynth U plane (= plane 2 in AVS, becomes VS plane 2)
results.append(r5c)

# Keep all frame refs alive
all_frames = [r["frame"] for r in results]
_ = all_frames

# ---------------------------------------------------------------------------
# Final summary DataFrame: compare actual vs expected per test
print("=" * 72)
print("SUMMARY: expected vs actual pixel values")
print("=" * 72)

summary_records = []
for r in results:
    actual_mean = r["df"].get_column("value").mean()
    actual_min = r["df"].get_column("value").min()
    actual_max = r["df"].get_column("value").max()
    all_match = r["df"].get_column("value").eq(r["expected"]).all()
    summary_records.append(
        {
            "test": r["label"],
            "plane": r["plane"],
            "expected": r["expected"],
            "actual_mean": round(actual_mean, 1),
            "actual_min": actual_min,
            "actual_max": actual_max,
            "all_match": all_match,
        }
    )

summary_df = pl.DataFrame(summary_records)
print(summary_df)
