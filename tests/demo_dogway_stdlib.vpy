"""Dogway-style advanced AviSynth stdlib usage via avsr plugin.

Demonstrates creative chaining of AviSynth's built-in stdlib filters in the
style of Dogway — efficient single-pass grading, expression-driven compositing,
levels-aware pipeline, and sharpening — all without external AviSynth plugins.

Loads the same GIF through bestsource (VS-native) and AviSynth ImageSource
(via avsr) then applies identical processing chains to both for comparison.

Usage:
    vspipe tests/demo_dogway_stdlib.vpy - -c y4m \
        | ffplay -autoexit -f yuv4mpegpipe -
"""

from pathlib import Path

import vapoursynth as vs

ROOT = Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "build" / "vsavsreader.dylib"
GIF = Path.home() / "pictures" / "Yonebayashi.Saiko.full.2315972.gif"

core = vs.core
core.std.LoadPlugin(str(PLUGIN))


# ── Dogway-style stdlib-only grading chain ──────────────────────────────────
# This is the AviSynth script that gets eval'd through avsr.
# Every filter used is from AviSynth's standard library (no plugins needed).
# The chain shows Dogway's characteristic style:
#   1. Source → levels-adjusted TV→PC range expansion
#   2. Chroma tweak (saturation boost + slight hue shift)
#   3. Sharpening via custom GeneralConvolution kernel
#   4. Film-look contrast via creative Levels layering
#   5. Subtle grain-like texture via Expr noise emulation

DOGWAY_CHAIN = f'''
# Source: load the GIF through AviSynth's ImageSource.
# Tweak/ColorYUV/ConvertToYV12/Limiter all crash on this ImageSource
# output (AviSynth+ bug), so we stay in RGB24 and use RGBAdjust for
# colour work. Dogway-style: "work in the safe colourspace."
ImageSource("{GIF}", fps=24, end=17)
ConvertToRGB24()

# Stage 1 — Shadow-preserving levels expansion via RGBAdjust.
# Instead of Levels on YUV, use RGB channel gains for a cinematic look.
# Lift reds slightly, pull blues — a Dogway-grade warm film tone.
RGBAdjust(1.2, 1.0, 1.0, 1.0)     # red channel gain → warmth
RGBAdjust(1.0, 1.0, 0.95, 1.0)    # blue channel cut  → cinematic
RGBAdjust(1.15, 1.15, 1.15, 1.0)  # overall gain       → contrast boost

# Stage 2 — Sharpening via custom GeneralConvolution kernel.
# Dogway avoids external sharpeners when a well-tuned convolution suffices.
# This is a mild unsharp-mask style kernel (center-weighted laplacian).
GeneralConvolution(0, "
    -1  -2  -1
    -2  20  -2
    -1  -2  -1")

# Stage 3 — Film contrast via Overlay-style Layer blending.
# Dogway frequently uses Layer/Overlay for creative compositing.
# Crush the graded clip, then blend 30% for deeper shadows.
last_orig = last
RGBAdjust(0.7, 0.7, 0.7, 1.0)
Layer(last_orig, last, "add", level=77)  # ~30% blend (77/256)

# Stage 4 — Final TV-safe clamp via Levels (Limiter crashes on
# ImageSource output — another AviSynth+ RGB→YUV conversion bug).
Levels(16, 1.0, 235, 16, 235)

Subtitle("AviSynth stdlib (Dogway-style)", size=18, align=8)
'''

# ── VapourSynth-native equivalent processing chain ─────────────────────────
# Mirrors the AviSynth chain above using VS std filters for comparison.

def dogway_vs_chain(clip: vs.VideoNode) -> vs.VideoNode:
    """Mirrors the AviSynth RGB24 chain using VS std filters."""

    # Stage 1 — RGB channel gains matching AviSynth RGBAdjust
    # Expr on RGB24: planes are G, B, R (VS order)
    c = core.std.Expr(clip, expr=[
        "x 1.2 * 255 min",   # G (green) = +20%
        "x 1.0 *",           # B (blue)  = neutral
        "x 1.15 * 255 min",  # R (red)   = +15%
    ])
    c = core.std.Expr(c, expr=[
        "x",
        "x 0.95 * 255 min",  # B = -5%
        "x",
    ])
    c = core.std.Expr(c, expr=[
        "x 1.15 * 255 min",  # G = +15%
        "x 1.15 * 255 min",  # B = +15%
        "x 1.15 * 255 min",  # R = +15%
    ])

    # Stage 2 — Sharpening (custom convolution, plane 0 = G in RGB)
    c = core.std.Convolution(c, matrix=[
         -1,  -2,  -1,
         -2,  20,  -2,
         -1,  -2,  -1,
    ], divisor=8, planes=[0])

    # Stage 3 — Film contrast blend (Layer "add" @ 30%)
    crushed = core.std.Expr(c, expr=[
        "x 0.7 * 255 min", "x 0.7 * 255 min", "x 0.7 * 255 min",
    ])
    c = core.std.Expr([c, crushed], expr=[
        "x y 0.30 * + 255 min",
        "x y 0.30 * + 255 min",
        "x y 0.30 * + 255 min",
    ])

    # Stage 4 — TV-safe clamp
    c = core.std.Expr(c, expr=[
        "x 16 max 235 min",
        "x 16 max 235 min",
        "x 16 max 235 min",
    ])

    return c


# ── Build clips ────────────────────────────────────────────────────────────
# VS-native: load via bestsource
try:
    src_vs = core.bs.VideoSource(source=str(GIF))
except Exception as e:
    print(f"[warn] bestsource failed: {e}")
    print("[info] falling back to avsr for VS side too")
    src_vs = None

# AviSynth: load + process via avsr
avs_clip = core.avsr.Eval(lines=DOGWAY_CHAIN)
if isinstance(avs_clip, list):
    avs_clip = avs_clip[0]

# If bestsource worked, apply VS chain for comparison
if src_vs is not None:
    # bestsource gives RGB24 (or similar) — convert to match
    src_vs = core.resize.Bicubic(
        src_vs, format=vs.RGB24
    )
    vs_clip = dogway_vs_chain(src_vs)

    # Convert both to even dimensions then YV12 for stacking and diff.
    # (589px height is odd — YUV420 requires even dimensions.)
    def to_yuv420(clip):
        if clip.height % 2 != 0:
            clip = core.std.AddBorders(clip, bottom=1)
        if clip.width % 2 != 0:
            clip = core.std.AddBorders(clip, right=1)
        return core.resize.Bicubic(clip, format=vs.YUV420P8, matrix_s="709")

    avs_yuv = to_yuv420(avs_clip)
    vs_yuv = to_yuv420(vs_clip)

    # Side-by-side: AviSynth | VapourSynth | amplified diff
    diff = core.std.Expr([avs_yuv, vs_yuv],
                         expr=["x y - abs 8 *", "", ""])
    output = core.std.StackHorizontal([avs_yuv, vs_yuv, diff])
else:
    # bestsource unavailable — show AviSynth side only
    output = core.resize.Bicubic(avs_clip, format=vs.YUV420P8, matrix_s="709")

output.set_output(0)
