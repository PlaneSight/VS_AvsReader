#!/usr/bin/env python3
"""
Extensive programmatic fuzzer for the avsr plugin.

Generates randomized AviSynth stdlib filter chains, runs them through
avsr in isolated subprocesses (to survive crashes), and reports results
as Polars DataFrames.

Usage:
    uv run python fuzz_stdlib.py                    # 5000 scripts (default)
    uv run python fuzz_stdlib.py --count 10000      # custom count
    uv run python fuzz_stdlib.py --seed 123         # custom seed
"""

from __future__ import annotations

import argparse
import json
import os
import random
import subprocess
import sys
import textwrap
import time
from collections import Counter
from itertools import combinations
from pathlib import Path

import polars as pl

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PLUGIN = PROJECT_ROOT / "build" / "vsavsreader.dylib"
RESULTS_DIR = Path(__file__).resolve().parent / "results"

DEFAULT_COUNT = 5000
DEFAULT_SEED = 42
SUBPROCESS_TIMEOUT = 5  # seconds per script

# ---------------------------------------------------------------------------
# Generator data
# ---------------------------------------------------------------------------

SOURCES: list[dict] = [
    {
        "name": "BlankClip",
        "template": 'BlankClip(width={w}, height={h}, pixel_type="{fmt}", length={length})',
        "fmt_in_template": True,
    },
    {
        "name": "ColorBars",
        "template": 'ColorBars(width={w}, height={h}, pixel_type="{fmt}")',
        "fmt_in_template": True,
    },
    {
        "name": "Blackness",
        "template": "Blackness(width={w}, height={h}, length={length})",
        "fmt_in_template": False,
        "default_fmt": "YV12",
    },
    {
        "name": "Version",
        "template": "Version()",
        "fmt_in_template": False,
        "default_fmt": "RGB32",
    },
]

SIZES: list[tuple[int, int]] = [
    (64, 64), (1, 1), (63, 63), (65, 65), (64, 1), (1, 64),
    (17, 11), (128, 128), (7, 7), (16, 16), (32, 32),
    (100, 100), (2, 2), (3, 3),
]

FORMATS: list[str] = [
    "YV12", "YV24", "YV16", "Y8", "RGB24", "RGB32", "YUY2",
]

FILTERS: list[dict] = [
    # ── Color conversion ────────────────────────────────────────────
    {"name": "ConvertToYV12",  "template": "ConvertToYV12()",  "allowed": None},
    {"name": "ConvertToYV24",  "template": "ConvertToYV24()",  "allowed": None},
    {"name": "ConvertToYV16",  "template": "ConvertToYV16()",  "allowed": None},
    {"name": "ConvertToY8",    "template": "ConvertToY8()",    "allowed": None},
    {"name": "ConvertToRGB24", "template": "ConvertToRGB24()", "allowed": None},
    {"name": "ConvertToRGB32", "template": "ConvertToRGB32()", "allowed": None},
    {"name": "ConvertToYUY2",  "template": "ConvertToYUY2()",  "allowed": None},
    # ── Levels / colour ─────────────────────────────────────────────
    {"name": "Levels",     "template": "Levels({a},{b},{c},{d},{e})", "allowed": None},
    {"name": "RGBAdjust",  "template": "RGBAdjust({ra},{ga},{ba},{aa})", "allowed": ["RGB24", "RGB32"]},
    {"name": "Tweak",      "template": "Tweak(sat={sat}, bright={b}, cont={c})", "allowed": ["YV12", "YV16", "YV24", "YUY2"]},
    {"name": "Limiter",    "template": "Limiter({lo},{hi},{lo},{hi})", "allowed": ["YV12", "YV16", "YV24", "YUY2"]},
    {"name": "ColorYUV",   "template": "ColorYUV(gain_y={gy}, cont_u={cu}, cont_v={cv})", "allowed": ["YV12", "YV16", "YV24", "YUY2"]},
    # ── Spatial ─────────────────────────────────────────────────────
    {"name": "Crop(4)",         "template": "Crop(4,4,-4,-4)",     "allowed": None},
    {"name": "Crop(0)",         "template": "Crop(0,0,0,0)",       "allowed": None},
    {"name": "AddBorders",      "template": "AddBorders(2,2,2,2)", "allowed": None},
    {"name": "BilinearResize",  "template": "BilinearResize({rw},{rh})",  "allowed": None},
    {"name": "BicubicResize",   "template": "BicubicResize({rw},{rh})",   "allowed": None},
    {"name": "PointResize",     "template": "PointResize({rw},{rh})",     "allowed": None},
    {"name": "LanczosResize",   "template": "LanczosResize({rw},{rh})",   "allowed": None},
    # ── Temporal ────────────────────────────────────────────────────
    {"name": "Trim(start)",  "template": "Trim(0, 0)",       "allowed": None},
    {"name": "Reverse",      "template": "Reverse()",        "allowed": None},
    {"name": "FadeIn(2)",    "template": "FadeIn0(2)",       "allowed": None},
    {"name": "FadeOut(2)",   "template": "FadeOut0(2)",      "allowed": None},
    # ── Transforms ──────────────────────────────────────────────────
    {"name": "TurnLeft",         "template": "TurnLeft()",         "allowed": None},
    {"name": "TurnRight",        "template": "TurnRight()",        "allowed": None},
    {"name": "Turn180",          "template": "Turn180()",          "allowed": None},
    {"name": "FlipHorizontal",   "template": "FlipHorizontal()",   "allowed": None},
    {"name": "FlipVertical",     "template": "FlipVertical()",     "allowed": None},
    # ── Chroma ─────────────────────────────────────────────────────
    {"name": "GreyScale",  "template": "GreyScale()",  "allowed": None},
    {"name": "SwapUV",     "template": "SwapUV()",     "allowed": ["YV12", "YV16", "YV24", "YUY2"]},
    {"name": "UToY",       "template": "UToY()",       "allowed": ["YV12", "YV16", "YV24", "YUY2"]},
    {"name": "VToY",       "template": "VToY()",       "allowed": ["YV12", "YV16", "YV24", "YUY2"]},
    # ── Convolution ─────────────────────────────────────────────────
    {"name": "GeneralConvolution", "template": 'GeneralConvolution(0,"0 -1 0 -1 6 -1 0 -1 0")', "allowed": None},
    # ── Field ──────────────────────────────────────────────────────
    {"name": "SeparateFields", "template": "AssumeFrameBased().SeparateFields()", "allowed": None},
    {"name": "Weave",          "template": "AssumeFrameBased().SeparateFields().Weave()", "allowed": None},
    # ── Overlay / text ──────────────────────────────────────────────
    {"name": "Subtitle",          "template": 'Subtitle("test")',          "allowed": None},
    {"name": "ShowFrameNumber",   "template": "ShowFrameNumber()",         "allowed": None},
    {"name": "Histogram(classic)","template": 'Histogram("classic")',      "allowed": None},
    # ── Audio ──────────────────────────────────────────────────────
    {"name": "KillAudio",  "template": "KillAudio()",  "allowed": None},
]

# Maps filter name → new format for filters that change the pixel format.
FORMAT_CHANGES: dict[str, str] = {
    "ConvertToYV12":  "YV12",
    "ConvertToYV24":  "YV24",
    "ConvertToYV16":  "YV16",
    "ConvertToY8":    "Y8",
    "ConvertToRGB24": "RGB24",
    "ConvertToRGB32": "RGB32",
    "ConvertToYUY2":  "YUY2",
    "UToY":           "Y8",
    "VToY":           "Y8",
}

# ---------------------------------------------------------------------------
# Generator helpers
# ---------------------------------------------------------------------------


def _random_params(name: str) -> dict[str, float]:
    """Return randomised keyword-arg dict for a filter with numeric params."""
    match name:
        case "Levels":
            return {
                "a": random.uniform(0, 32),
                "b": random.uniform(0.5, 2.0),
                "c": random.uniform(200, 255),
                "d": random.uniform(0, 32),
                "e": random.uniform(200, 255),
            }
        case "RGBAdjust":
            return {
                "ra": round(random.uniform(0.1, 2.0), 2),
                "ga": round(random.uniform(0.1, 2.0), 2),
                "ba": round(random.uniform(0.1, 2.0), 2),
                "aa": round(random.uniform(0.1, 2.0), 2),
            }
        case "Tweak":
            return {
                "sat": round(random.uniform(0.5, 2.0), 2),
                "b": round(random.uniform(-50, 50), 1),
                "c": round(random.uniform(0.5, 2.0), 2),
            }
        case "Limiter":
            return {
                "lo": random.randint(0, 32),
                "hi": random.randint(200, 255),
            }
        case "ColorYUV":
            return {
                "gy": round(random.uniform(-50, 50), 1),
                "cu": round(random.uniform(-50, 50), 1),
                "cv": round(random.uniform(-50, 50), 1),
            }
        case "BilinearResize" | "BicubicResize" | "PointResize" | "LanczosResize":
            return {
                "rw": random.randint(4, 320),
                "rh": random.randint(4, 240),
            }
        case _:
            return {}


def _compatible_filters(current_fmt: str) -> list[dict]:
    """Return FILTERS entries whose `allowed` set includes *current_fmt* (or is None)."""
    return [
        f
        for f in FILTERS
        if f["allowed"] is None or current_fmt in f["allowed"]
    ]


# ---------------------------------------------------------------------------
# Generator – produces one randomised AviSynth script + metadata
# ---------------------------------------------------------------------------


def generate_script() -> tuple[str, dict]:
    """Return (avisynth_script_text, metadata_dict)."""
    # 1. Pick source
    src = random.choice(SOURCES)
    w, h = random.choice(SIZES)
    fmt = random.choice(FORMATS)
    length = random.randint(1, 30)

    if src["fmt_in_template"]:
        start_format = fmt
        src_line = src["template"].format(w=w, h=h, fmt=fmt, length=length)
    else:
        start_format = src.get("default_fmt", "YV12")
        src_line = src["template"].format(w=w, h=h, length=length)

    lines = [src_line]
    current_fmt = start_format
    filters_applied: list[str] = []

    # 2. Append 1–5 random compatible filters
    chain_len = random.randint(1, 5)
    for _ in range(chain_len):
        candidates = _compatible_filters(current_fmt)
        if not candidates:
            break
        chosen = random.choice(candidates)
        params = _random_params(chosen["name"])
        filter_line = chosen["template"].format(**params)
        lines.append(filter_line)
        filters_applied.append(chosen["name"])

        # Track format change
        if chosen["name"] in FORMAT_CHANGES:
            current_fmt = FORMAT_CHANGES[chosen["name"]]

    script = "\n".join(lines)

    meta = {
        "source": src["name"],
        "width": w,
        "height": h,
        "start_format": start_format,
        "filters": filters_applied,
        "chain_length": len(filters_applied),
    }
    return script, meta


# ---------------------------------------------------------------------------
# Runner – subprocess isolation
# ---------------------------------------------------------------------------


def run_script(avs_script: str) -> dict:
    """Execute *avs_script* in an isolated subprocess.  Returns a flat result dict."""
    plugin_repr = repr(str(PLUGIN))
    script_repr = repr(avs_script)

    sub_code = textwrap.dedent(f"""\
    import json
    import vapoursynth as vs
    try:
        core = vs.core
        core.std.LoadPlugin({plugin_repr})
        result = core.avsr.Eval(lines={script_repr})
        if isinstance(result, list):
            result = result[0]
        f = result.get_frame(0)
        info = dict(
            success=True,
            width=result.width,
            height=result.height,
            num_frames=result.num_frames,
            format_name=result.format.name if result.format else None,
        )
    except vs.Error as e:
        info = dict(success=False, error=str(e))
    except Exception as e:
        info = dict(success=False, error=type(e).__name__ + ": " + str(e))
    print(json.dumps(info, default=str))
    """)

    try:
        p = subprocess.run(
            [sys.executable, "-c", sub_code],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT,
            env={**os.environ, "PYTHONUNBUFFERED": "1"},
        )
    except subprocess.TimeoutExpired:
        return {"success": False, "crash": True, "error": "Timeout (5s)"}

    # Subprocess crashed (non-zero exit)
    if p.returncode != 0:
        err = p.stderr.strip()[:500] if p.stderr else f"Exit code {p.returncode}"
        return {"success": False, "crash": True, "error": err}

    # Subprocess ran – parse JSON
    stdout = p.stdout.strip()
    if not stdout:
        return {"success": False, "crash": False, "error": "Empty stdout"}

    try:
        info = json.loads(stdout)
    except json.JSONDecodeError:
        return {"success": False, "crash": False, "error": f"Invalid JSON: {stdout[:200]}"}

    info.setdefault("crash", False)
    if not info.get("success"):
        info.setdefault("crash", False)
        info.setdefault("error", None)
        info.setdefault("width", None)
        info.setdefault("height", None)
        info.setdefault("num_frames", None)
        info.setdefault("format_name", None)

    # Flatten output: prefix output fields
    result: dict[str, object] = {
        "success": info["success"],
        "crash": info.get("crash", False),
        "error": info.get("error"),
        "out_width": info.get("width"),
        "out_height": info.get("height"),
        "out_num_frames": info.get("num_frames"),
        "out_format_name": info.get("format_name"),
    }
    return result  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Reporter – DataFrame + Markdown
# ---------------------------------------------------------------------------


def build_report(results: list[dict], count: int, elapsed: float) -> None:
    """Write fuzz.csv and fuzz.md to RESULTS_DIR."""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    df = pl.DataFrame(results)

    # ── CSV ─────────────────────────────────────────────────────────
    # Convert list columns to JSON strings for tidy CSV output
    write_df = df.with_columns(
        pl.col("filters").list.join(", ").alias("filters")
    )
    csv_path = RESULTS_DIR / "fuzz.csv"
    write_df.write_csv(csv_path)
    print(f"  CSV  → {csv_path}")

    # ── Key statistics ──────────────────────────────────────────────
    total = len(df)
    n_success = df.filter(pl.col("success")).height
    n_crash = df.filter(pl.col("crash")).height
    n_error = df.filter(~pl.col("success") & ~pl.col("crash")).height

    md_lines: list[str] = [
        "# AVSR Fuzz Results",
        "",
        f"**Date:** {time.strftime('%Y-%m-%d %H:%M:%S')}  ",
        f"**Seed:** {DEFAULT_SEED}  ",
        f"**Scripts requested:** {count}  ",
        f"**Elapsed:** {elapsed:.1f}s  ",
        "",
        "## Summary",
        "",
        "| Metric  | Count | Rate    |",
        "|---------|-------|---------|",
        f"| Total   | {total} |         |",
        f"| Success | {n_success} | {n_success / total * 100:.1f}% |",
        f"| Crash   | {n_crash} | {n_crash / total * 100:.1f}% |",
        f"| Error   | {n_error} | {n_error / total * 100:.1f}% |",
        "",
    ]

    # ── Breakdown by filter ─────────────────────────────────────────
    crash_df = df.filter(pl.col("crash"))
    if crash_df.height > 0:
        filter_blame = (
            crash_df.explode("filters")
            .group_by("filters")
            .len()
            .sort("len", descending=True)
            .head(30)
        )
        md_lines.extend([
            "## Crashes by Filter",
            "",
            "| Filter | Crashes |",
            "|--------|---------|",
        ])
        for row in filter_blame.iter_rows():
            md_lines.append(f"| {row[0]} | {row[1]} |")
        md_lines.append("")
    else:
        md_lines.extend(["## Crashes by Filter", "", "*No crashes recorded.*", ""])

    # ── Breakdown by source ─────────────────────────────────────────
    if crash_df.height > 0:
        source_blame = (
            crash_df.group_by("source")
            .len()
            .sort("len", descending=True)
        )
        md_lines.extend([
            "## Crashes by Source",
            "",
            "| Source | Crashes |",
            "|--------|---------|",
        ])
        for row in source_blame.iter_rows():
            md_lines.append(f"| {row[0]} | {row[1]} |")
        md_lines.append("")
    else:
        md_lines.extend(["## Crashes by Source", "", "*No crashes recorded.*", ""])

    # ── Top crash filter pairs ──────────────────────────────────────
    if crash_df.height >= 2:
        pair_counter: Counter[str] = Counter()
        for flist in crash_df["filters"].to_list():
            for a, b in combinations(sorted(flist), 2):
                pair_counter[f"{a} + {b}"] += 1
        top_pairs = pair_counter.most_common(20)
        if top_pairs:
            md_lines.extend([
                "## Top Crash Filter Pairs",
                "",
                "| Pair | Count |",
                "|------|-------|",
            ])
            for p, c in top_pairs:
                md_lines.append(f"| {p} | {c} |")
            md_lines.append("")

    # ── Crash by dimension ──────────────────────────────────────────
    if crash_df.height > 0:
        dim_blame = (
            crash_df.group_by(["width", "height"])
            .len()
            .sort("len", descending=True)
            .head(20)
        )
        md_lines.extend([
            "## Crashes by Dimensions",
            "",
            "| Width | Height | Crashes |",
            "|-------|--------|---------|",
        ])
        for row in dim_blame.iter_rows():
            md_lines.append(f"| {row[0]} | {row[1]} | {row[2]} |")
        md_lines.append("")

    # ── Top errors (non-crash) ──────────────────────────────────────
    error_df = df.filter(~pl.col("success") & ~pl.col("crash"))
    if error_df.height > 0:
        err_sample = error_df.select(["error", "script"]).head(10)
        md_lines.extend([
            "## Sample Errors (non-crash)",
            "",
        ])
        for row in err_sample.iter_rows():
            err_msg = (row[0] or "")[:120]
            script_preview = (row[1] or "")[:100].replace("\n", " / ")
            md_lines.append(f"- **Error:** `{err_msg}`")
            md_lines.append(f"  Script: `{script_preview}`")
        md_lines.append("")

    # ── Write markdown ──────────────────────────────────────────────
    md_path = RESULTS_DIR / "fuzz.md"
    md_path.write_text("\n".join(md_lines) + "\n")
    print(f"  MD   → {md_path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description="Fuzz avsr AviSynth filter chains")
    parser.add_argument("--count", "-n", type=int, default=DEFAULT_COUNT,
                        help=f"Number of scripts to generate (default: {DEFAULT_COUNT})")
    parser.add_argument("--seed", "-s", type=int, default=DEFAULT_SEED,
                        help=f"Random seed (default: {DEFAULT_SEED})")
    args = parser.parse_args()

    count: int = args.count
    seed: int = args.seed
    random.seed(seed)

    if not PLUGIN.exists():
        print(f"ERROR: plugin not found at {PLUGIN}", file=sys.stderr)
        print("Build with: zig build", file=sys.stderr)
        sys.exit(1)

    print(f"Fuzzing {count} scripts (seed={seed}) ...")
    print(f"  Plugin: {PLUGIN}")
    print(f"  Timeout: {SUBPROCESS_TIMEOUT}s per script")
    print()

    results: list[dict] = []
    ok = crash = err = 0
    t_start = time.monotonic()

    for i in range(1, count + 1):
        script, meta = generate_script()
        run_result = run_script(script)

        record = {
            "run_id": i,
            "script": script,
            **meta,
            **run_result,
        }
        results.append(record)

        if run_result["success"]:
            ok += 1
        elif run_result.get("crash"):
            crash += 1
        else:
            err += 1

        if i % 100 == 0 or i == count:
            elapsed = time.monotonic() - t_start
            rate = i / elapsed if elapsed > 0 else 0
            print(f"  [{i:>{len(str(count))}}/{count}]  "
                  f"OK:{ok}  Crash:{crash}  Error:{err}  "
                  f"({rate:.0f}/s, {elapsed:.0f}s)")

    elapsed = time.monotonic() - t_start
    print(f"\nDone in {elapsed:.1f}s.  Success:{ok}  Crash:{crash}  Error:{err}")
    print()

    build_report(results, count, elapsed)


if __name__ == "__main__":
    main()
