"""Compare avsr plugin output vs native VapourSynth for many filters.
Collects per-plane min/max/avg and max abs diff in a Polars DataFrame.
"""

from pathlib import Path

import polars as pl
import vapoursynth as vs

_ROOT = Path(__file__).parent.parent
PLUGIN = _ROOT / "build" / "vsavsreader.dylib"
AVSI = _ROOT / "vendor" / "avsi" / "ExTools.avsi"

W, H, N = 64, 48, 1

core = vs.core
core.std.LoadPlugin(str(PLUGIN))


def plane_stats(label, clip):
    """Return (Y_stats, U_stats, V_stats) as (min,max,avg) tuples."""
    out = []
    for i in range(clip.format.num_planes):
        plane = core.std.ShufflePlanes(clip, planes=i, colorfamily=vs.GRAY)
        ps = core.std.PlaneStats(plane)
        f = ps.get_frame(0)
        p = f.props
        out.append((float(p["PlaneStatsMin"]),
                    float(p["PlaneStatsMax"]),
                    float(p["PlaneStatsAverage"])))
    return out


def max_diff(clip_a, clip_b):
    """Max absolute per-pixel diff across all planes."""
    diff = core.std.Expr([clip_a, clip_b], expr=["x y - abs"])
    md = 0.0
    for i in range(diff.format.num_planes):
        plane = core.std.ShufflePlanes(diff, planes=i, colorfamily=vs.GRAY)
        ps = core.std.PlaneStats(plane)
        f = ps.get_frame(0)
        md = max(md, float(f.props["PlaneStatsMax"]))
    return md


# Source: use ColorBars for visually interesting content
SRC_AVS = f'ColorBars(width={W}, height={H}, pixel_type="YV12")\nTrim(0, {N-1})\n'
src = core.avsr.Eval(lines=SRC_AVS)
if isinstance(src, list):
    src = src[0]

# Also get a VS-native version of the source for VS-side filters.
# We'll just use the avsr source as input to VS filters (since avsr is the
# only way to get AviSynth ColorBars). This tests the filter, not the source.
vs_src = src

print(f"Source: AviSynth ColorBars {W}x{H} YUV420P8")
s = plane_stats("src", src)
print(f"  Y: min={s[0][0]:.0f} max={s[0][1]:.0f} avg={s[0][2]:.1f}  "
      f"U: min={s[1][0]:.0f} max={s[1][1]:.0f} avg={s[1][2]:.1f}  "
      f"V: min={s[2][0]:.0f} max={s[2][1]:.0f} avg={s[2][2]:.1f}")
print()

# Each test: (name, avs_lines_after_source, vs_filter_fn)
tests = []


def t(name, avs_extra, vs_fn):
    tests.append((name, avs_extra, vs_fn))


# --- Invert ---
t("Invert",
  "Invert()",
  lambda c: core.std.Expr(c, expr=["255 x -", "", ""]))

# --- Levels (brightness +5) ---
t("Tweak bright=5",
  "Tweak(bright=5)",
  lambda c: core.std.Expr(c, expr=["x 5 + 255 min 0 max", "", ""]))

# --- Tweak sat=0 (greyscale) ---
t("Tweak sat=0",
  "Tweak(sat=0)",
  lambda c: core.std.Expr(c, expr=["x", "128", "128"]))

# --- Tweak cont=1.1 ---
t("Tweak cont=1.1",
  "Tweak(cont=1.1)",
  lambda c: core.std.Expr(c, expr=["x 1.1 * 255 min 0 max", "", ""]))

# --- Levels ---
t("Levels(16,1.0,235,16,235)",
  "Levels(16, 1.0, 235, 16, 235)",
  lambda c: core.std.Levels(c, min_in=16, max_in=235, gamma=1.0,
                             min_out=16, max_out=235, planes=0))

# --- Limiter ---
t("Limiter(16,235,16,240)",
  "Limiter(16, 235, 16, 240)",
  lambda c: core.std.Limiter(c, min=16, max=235, planes=0))

# --- GreyScale ---
t("GreyScale",
  "GreyScale()",
  lambda c: core.std.Expr(c, expr=["x", "128", "128"]))

# --- FlipHorizontal ---
t("FlipHorizontal",
  "FlipHorizontal()",
  lambda c: core.std.Flip(c, horizontal=True) if hasattr(core.std, "Flip") else core.resize.Point(c, width=c.width, height=c.height))

# --- FlipVertical ---
t("FlipVertical",
  "FlipVertical()",
  lambda c: core.std.Flip(c, vertical=True) if hasattr(core.std, "Flip") else core.resize.Point(c, width=c.width, height=c.height))

# --- TurnLeft ---
t("TurnLeft",
  "TurnLeft()",
  lambda c: core.std.Turn(c, direction=0) if hasattr(core.std, "Turn") else core.resize.Point(c, width=c.height, height=c.width))

# --- TurnRight ---
t("TurnRight",
  "TurnRight()",
  lambda c: core.std.Turn(c, direction=1) if hasattr(core.std, "Turn") else core.resize.Point(c, width=c.height, height=c.width))

# --- Turn180 ---
t("Turn180",
  "Turn180()",
  lambda c: core.std.Turn(c, direction=2) if hasattr(core.std, "Turn") else core.resize.Point(c, width=c.width, height=c.height))

# --- Crop ---
t("Crop(8,8,-8,-8)",
  "Crop(8, 8, -8, -8)",
  lambda c: core.std.Crop(c, left=8, top=8, right=8, bottom=8))

# --- AddBorders ---
t("AddBorders(4,4,4,4)",
  "AddBorders(4, 4, 4, 4)",
  lambda c: core.std.AddBorders(c, left=4, top=4, right=4, bottom=4))

# --- BilinearResize ---
t("BilinearResize(128,96)",
  "BilinearResize(128, 96)",
  lambda c: core.resize.Bilinear(c, width=128, height=96))

# --- BicubicResize ---
t("BicubicResize(128,96)",
  "BicubicResize(128, 96)",
  lambda c: core.resize.Bicubic(c, width=128, height=96))

# --- PointResize ---
t("PointResize(128,96)",
  "PointResize(128, 96)",
  lambda c: core.resize.Point(c, width=128, height=96))

# --- SwapUV ---
t("SwapUV",
  "SwapUV()",
  lambda c: core.std.ShufflePlanes(c, planes=[0, 2, 1], colorfamily=vs.YUV))

# --- UToY ---
t("UToY",
  "UToY()",
  lambda c: core.std.ShufflePlanes(c, planes=1, colorfamily=vs.GRAY))

# --- ex_invert (from ExTools) ---
t("ex_invert",
  f'Import("{AVSI}")\nex_invert()',
  lambda c: core.std.Expr(c, expr=["255 x -", "", ""]))

# --- ex_lut x 2 / (scale 0-255 to 0-1 and back) ---
t("ex_lut 'x 2 /'",
  f'Import("{AVSI}")\nex_lut("x 2 /")',
  lambda c: core.std.Expr(c, expr=["x 2 /", "", ""]))

# --- ex_blur (boxblur) ---
t("ex_boxblur",
  f'Import("{AVSI}")\nex_boxblur(1)',
  lambda c: core.std.BoxBlur(c, planes=0, hradius=1, vradius=1))

# --- ex_expand (morphological) ---
t("ex_expand",
  f'Import("{AVSI}")\nex_expand()',
  lambda c: core.std.Maximum(c, planes=0))

# --- ex_inpand (morphological) ---
t("ex_inpand",
  f'Import("{AVSI}")\nex_inpand()',
  lambda c: core.std.Minimum(c, planes=0))


# ---------------------------------------------------------------------------
# Collect all test results as dicts, then build DataFrames
# ---------------------------------------------------------------------------
results = []

for name, avs_extra, vs_fn in tests:
    try:
        avs_clip = core.avsr.Eval(lines=SRC_AVS + avs_extra + "\n")
        if isinstance(avs_clip, list):
            avs_clip = avs_clip[0]
    except Exception as e:
        print(f"{name:<28} AviSynth ERROR: {e}")
        continue

    try:
        vs_clip = vs_fn(vs_src)
    except Exception as e:
        print(f"{name:<28} VS ERROR: {e}")
        continue

    # If dimensions differ (crop/resize/turn), we can't diff directly.
    same_dims = (avs_clip.width == vs_clip.width
                 and avs_clip.height == vs_clip.height
                 and avs_clip.format.id == vs_clip.format.id)

    avs_s = plane_stats("avs", avs_clip)
    vs_s = plane_stats("vs", vs_clip)

    if same_dims:
        md = max_diff(avs_clip, vs_clip)
    else:
        md = None  # dimension mismatch — no pixel diff possible

    results.append({
        "filter": name,
        "avs_Y_min": avs_s[0][0],
        "avs_Y_max": avs_s[0][1],
        "avs_Y_avg": avs_s[0][2],
        "avs_U_min": avs_s[1][0],
        "avs_U_max": avs_s[1][1],
        "avs_U_avg": avs_s[1][2],
        "avs_V_min": avs_s[2][0],
        "avs_V_max": avs_s[2][1],
        "avs_V_avg": avs_s[2][2],
        "vs_Y_min": vs_s[0][0],
        "vs_Y_max": vs_s[0][1],
        "vs_Y_avg": vs_s[0][2],
        "vs_U_min": vs_s[1][0],
        "vs_U_max": vs_s[1][1],
        "vs_U_avg": vs_s[1][2],
        "vs_V_min": vs_s[2][0],
        "vs_V_max": vs_s[2][1],
        "vs_V_avg": vs_s[2][2],
        "max_diff": md,
    })

if not results:
    print("No results collected.")
else:
    df = pl.DataFrame(results)

    print("=" * 40)
    print("Full Results")
    print("=" * 40)
    print(df)

    # -----------------------------------------------------------------------
    # Summary
    # -----------------------------------------------------------------------
    exact = df.filter(pl.col("max_diff") == 0.0)
    with_diff = df.filter(pl.col("max_diff") > 0.0)
    no_diff = df.filter(pl.col("max_diff").is_null())

    print()
    print("=" * 40)
    print("Summary")
    print("=" * 40)
    print(f"bit-exact (max_diff == 0): {len(exact)}")
    if len(exact) > 0:
        print(exact.select("filter"))
    print(f"\nnon-bit-exact (max_diff > 0): {len(with_diff)}")
    if len(with_diff) > 0:
        print(with_diff.select("filter", "max_diff"))
    print(f"\ndim mismatch (no diff computed): {len(no_diff)}")
    if len(no_diff) > 0:
        print(no_diff.select("filter"))
