"""Numeric diagnostic: print per-plane min/max/avg of each stage
to pinpoint where the AviSynth-vs-VS divergence comes from.
Uses std.PlaneStats for frame-level stats. Output via Polars DataFrame.
"""

from pathlib import Path
import sys

import polars as pl
import vapoursynth as vs

_ROOT = Path(__file__).parent.parent
PLUGIN = _ROOT / "build" / "vsavsreader.dylib"
AVSI = _ROOT / "vendor" / "avsi" / "ExTools.avsi"

W, H, NFRAMES = 320, 240, 1

core = vs.core
core.std.LoadPlugin(str(PLUGIN))

rows = []


def stats(label, clip):
    # PlaneStats gives overall min/max/avg. Extract each plane via
    # ShufflePlanes to get per-plane stats.
    for i, name in enumerate(["Y", "U", "V"]):
        plane = core.std.ShufflePlanes(clip, planes=i, colorfamily=vs.GRAY)
        ps = core.std.PlaneStats(plane)
        f = ps.get_frame(0)
        p = f.props
        mn = float(p["PlaneStatsMin"])
        mx = float(p["PlaneStatsMax"])
        avg = float(p["PlaneStatsAverage"])
        rows.append({
            "label": label,
            "plane": name,
            "min": mn,
            "max": mx,
            "avg": avg,
        })


# Source: AviSynth ColorBars via avsr
avs_colorbars = (
    f'ColorBars(width={W}, height={H}, pixel_type="YV12")\n'
    f'Trim(0, {NFRAMES - 1})\n'
)
src_avs = core.avsr.Eval(lines=avs_colorbars)
if isinstance(src_avs, list):
    src_avs = src_avs[0]
stats("AviSynth ColorBars (src)", src_avs)

# VS BlankClip gray
vs_blank = core.std.BlankClip(width=W, height=H, format=vs.YUV420P8,
                              color=[128, 128, 128], length=NFRAMES)
stats("VS BlankClip gray", vs_blank)

# AviSynth BlankClip gray via avsr
avs_blank = core.avsr.Eval(
    lines=(
        f'BlankClip(width={W}, height={H}, pixel_type="YV12", '
        f'color=$808080, length={NFRAMES})\n'
    ),
)
if isinstance(avs_blank, list):
    avs_blank = avs_blank[0]
stats("AviSynth BlankClip gray", avs_blank)

# Diff: avs_blank vs vs_blank
diff_blank = core.std.Expr([avs_blank, vs_blank],
                           expr=["x y - abs", "", ""])
stats("|avs_blank - vs_blank|", diff_blank)

# Port: VS Expr invert of AviSynth source
port_invert = core.std.Expr(src_avs, expr=["255 x -", "", ""])
stats("VS Expr invert (port)", port_invert)

# Reference: AviSynth ex_invert of ColorBars
ref_invert = core.avsr.Eval(
    lines=(
        f'Import("{AVSI}")\n'
        f'{avs_colorbars}'
        'ex_invert()\n'
    ),
)
if isinstance(ref_invert, list):
    ref_invert = ref_invert[0]
stats("AviSynth ex_invert (ref)", ref_invert)

# Diff: port vs ref
diff_invert = core.std.Expr([port_invert, ref_invert],
                            expr=["x y - abs", "", ""])
stats("|port_invert - ref_invert|", diff_invert)

# Also: what does AviSynth Expr("255 x -") give directly (without ex_invert)?
avs_raw_invert = core.avsr.Eval(
    lines=(
        f'{avs_colorbars}'
        'Expr("255 x -", "", "")\n'
    ),
)
if isinstance(avs_raw_invert, list):
    avs_raw_invert = avs_raw_invert[0]
stats("AviSynth raw Expr 255 x -", avs_raw_invert)

# Diff: port vs avs_raw_invert
diff_raw = core.std.Expr([port_invert, avs_raw_invert],
                         expr=["x y - abs", "", ""])
stats("|port_invert - avs_raw_invert|", diff_raw)

# Build DataFrame
df = pl.DataFrame(rows)

# Output
results_dir = Path(__file__).parent / "results"
results_dir.mkdir(parents=True, exist_ok=True)

# CSV
df.write_csv(results_dir / "diagnose_stats.csv")

# Markdown
pivoted = df.pivot(on="plane", index="label", values=["min", "max", "avg"])

md_lines = [
    "# Diagnose Stats",
    "",
    "Per-plane min, max, and average pixel values for each processing stage.",
    f"Resolution: {W}x{H}, frames: {NFRAMES}.",
    "",
]
cols = pivoted.columns
md_lines.append("| " + " | ".join(cols) + " |")
md_lines.append("| " + " | ".join("---" for _ in cols) + " |")
for row in pivoted.iter_rows():
    formatted = []
    for val in row:
        if isinstance(val, float):
            formatted.append(f"{val:.2f}")
        else:
            formatted.append(str(val))
    md_lines.append("| " + " | ".join(formatted) + " |")

(results_dir / "diagnose_stats.md").write_text("\n".join(md_lines) + "\n")

print("Results written to tests/results/diagnose_stats.{md,csv}")
