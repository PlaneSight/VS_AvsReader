"""Side-by-side preview: AviSynth ex_invert (reference) vs VS std.Expr port
plus an amplified diff panel.

Run:
    vspipe tests/preview_avsr.vpy - | ffplay -autoexit - \
        -f rawvideo -pixel_format yuv420p \
        -video_size 960x240 -framerate 30000/1001 -
"""

from pathlib import Path

import vapoursynth as vs

_ROOT = Path(__file__).parent.parent
PLUGIN = _ROOT / "build" / "vsavsreader.dylib"
AVSI = _ROOT / "vendor" / "avsi" / "ExTools.avsi"

W, H, NFRAMES = 320, 240, 240

core = vs.core
core.std.LoadPlugin(str(PLUGIN))

# Source: AviSynth ColorBars via the avsr plugin. Both reference and port
# invert THIS clip, so the A/B compares the inversion logic only.
src_avs = (
    f'ColorBars(width={W}, height={H}, pixel_type="YV12")\n'
    f'Trim(0, {NFRAMES - 1})\n'
)
original = core.avsr.Eval(lines=src_avs)
if isinstance(original, list):
    original = original[0]

# Reference: AviSynth ex_invert() — reduces to Expr(a, "range_max x -") on Y,
# UV untouched (UV=1). Subtitle labels it in the preview.
ref = core.avsr.Eval(
    lines=(
        f'Import("{AVSI}")\n'
        f'{src_avs}'
        'ex_invert()\n'
        'Subtitle("AviSynth ex_invert (ref)")\n'
    ),
)
if isinstance(ref, list):
    ref = ref[0]

# Port: native VapourSynth. std.Expr has no `range_max` token, so use the
# literal 255 for 8-bit. Empty strings copy U/V from the first clip,
# matching ex_invert's UV=1 (untouched chroma).
port = core.std.Expr(original, expr=["255 x -", "", ""])

# Diff: |ref - port| amplified 8x so any mismatch is visible.
# Single expr applies to ALL planes (no empty strings that would copy
# instead of diffing chroma).
diff = core.std.Expr([ref, port], expr=["x y - abs 8 *"])

# Side-by-side: reference | port | amplified diff (should be black).
output = core.std.StackHorizontal([ref, port, diff])
output.set_output(0)
