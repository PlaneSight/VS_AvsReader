"""Diagnostic: compare AviSynth source (via avsr) vs native VS source
to isolate where the difference comes from.

Stages:
  0. AviSynth ColorBars via avsr           (reference source)
  1. VS BlankClip (gray)                   (sanity: should be uniform)
  2. VS Expr invert of stage 0             (port of ex_invert)
  3. AviSynth ex_invert of ColorBars       (reference invert)
  4. |stage 2 - stage 3| amplified 16x     (the diff we want to debug)
  5. |stage 0 - stage 0|                   (sanity: should be 0)
  6. AviSynth BlankClip via avsr           (compare to VS BlankClip)
  7. |stage 6 - stage 1|                   (AviSynth vs VS blank diff)

Run:
    vspipe tests/diagnose_avsr.vpy - -c y4m | ffplay -window_title diagnose -
"""

from pathlib import Path

import vapoursynth as vs

_ROOT = Path(__file__).parent.parent
PLUGIN = _ROOT / "build" / "vsavsreader.dylib"
AVSI = _ROOT / "vendor" / "avsi" / "ExTools.avsi"

W, H, NFRAMES = 320, 240, 240

core = vs.core
core.std.LoadPlugin(str(PLUGIN))

# Stage 0: AviSynth ColorBars via avsr (the source we'll invert both ways)
avs_colorbars = (
    f'ColorBars(width={W}, height={H}, pixel_type="YV12")\n'
    f'Trim(0, {NFRAMES - 1})\n'
)
src_avs = core.avsr.Eval(lines=avs_colorbars)
if isinstance(src_avs, list):
    src_avs = src_avs[0]

# Stage 1: VS BlankClip (gray, sanity check)
vs_blank = core.std.BlankClip(width=W, height=H, format=vs.YUV420P8,
                              color=[128, 128, 128], length=NFRAMES)

# Stage 2: VS Expr invert of the AviSynth source (port of ex_invert)
port_invert = core.std.Expr(src_avs, expr=["255 x -", "", ""])

# Stage 3: AviSynth ex_invert of ColorBars (reference)
ref_invert = core.avsr.Eval(
    lines=(
        f'Import("{AVSI}")\n'
        f'{avs_colorbars}'
        'ex_invert()\n'
    ),
)
if isinstance(ref_invert, list):
    ref_invert = ref_invert[0]

# Stage 4: |port - ref| amplified 16x (the diff we're debugging)
diff_invert = core.std.Expr([port_invert, ref_invert],
                            expr=["x y - abs 16 *", "", ""])

# Stage 5: |src - src| sanity (should be all 0)
diff_self = core.std.Expr([src_avs, src_avs],
                          expr=["x y - abs 16 *", "", ""])

# Stage 6: AviSynth BlankClip via avsr (compare to VS BlankClip)
avs_blank = core.avsr.Eval(
    lines=(
        f'BlankClip(width={W}, height={H}, pixel_type="YV12", '
        f'color=$808080, length={NFRAMES})\n'
    ),
)
if isinstance(avs_blank, list):
    avs_blank = avs_blank[0]

# Stage 7: |avs_blank - vs_blank| (AviSynth vs VS blank diff)
diff_blank = core.std.Expr([avs_blank, vs_blank],
                           expr=["x y - abs 16 *", "", ""])

# Stack vertically in two rows of 4 panels each.
# Row 1: src_avs | vs_blank | port_invert | ref_invert
# Row 2: diff_self | diff_blank | diff_invert | (label placeholder)
placeholder = core.std.BlankClip(width=W, height=H, format=vs.YUV420P8,
                                color=[16, 128, 128], length=NFRAMES)

row1 = core.std.StackHorizontal([src_avs, vs_blank, port_invert, ref_invert])
row2 = core.std.StackHorizontal([diff_self, diff_blank, diff_invert, placeholder])
output = core.std.StackVertical([row1, row2])
output.set_output(0)
