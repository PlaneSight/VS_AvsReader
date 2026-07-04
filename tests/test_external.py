"""
Tests that require external AviSynth+ plugins (not stdlib) loaded via
LoadPlugin().  Run with: pytest tests/test_external.py -v

Skipped on macOS where plugin DLLs are not loadable; intended for
Windows CI or cross-platform plugin availability.
"""

import subprocess
import sys
import textwrap
from pathlib import Path

import vapoursynth as vs
import pytest

PLUGIN_SO = Path(__file__).resolve().parent.parent / "build" / "vsavsreader.dylib"
PLUGINS_DIR = Path(__file__).resolve().parent.parent / "vendor" / "plugins"


def _platform_has_avisynth_plugins():
    """True when the runtime can load the vendored plugin DLLs (Windows only)."""
    return sys.platform == "win32"


def _dll(name):
    return str(PLUGINS_DIR / f"{name}.dll")


skip_no_plugins = pytest.mark.skipif(
    not _platform_has_avisynth_plugins(),
    reason="external AviSynth+ plugins are Windows-only DLLs",
)


@pytest.fixture(scope="session")
def core():
    if not _platform_has_avisynth_plugins():
        pytest.skip("no AviSynth+ plugin runtime")
    c = vs.core
    c.std.LoadPlugin(str(PLUGIN_SO))
    return c


def _eval_avs(core, script):
    r = core.avsr.Eval(lines=script)
    if isinstance(r, list):
        return r[0]
    return r


# ---------------------------------------------------------------------------
# AddGrainC
# ---------------------------------------------------------------------------

@skip_no_plugins
class TestAddGrainC:
    SRC = 'BlankClip(length=10, width=64, height=64, pixel_type="YV12")'

    def test_basic(self, core):
        c = _eval_avs(core, f'LoadPlugin("{_dll("AddGrainC")}")\n{self.SRC}\nAddGrainC(5)')
        assert c.format.id == vs.YUV420P8


# ---------------------------------------------------------------------------
# MVTools2
# ---------------------------------------------------------------------------

@skip_no_plugins
class TestMVTools2:
    SRC = 'BlankClip(length=10, width=64, height=64, pixel_type="YV12")'

    def test_super_analyse(self, core):
        script = (
            f'LoadPlugin("{_dll("mvtools2")}")\n'
            f'{self.SRC}\n'
            'super = MSuper()\n'
            'bv = MAnalyse(super, isb=true)\n'
            'fv = MAnalyse(super, isb=false)\n'
            'MDegrain1(super, bv, fv)\n'
        )
        c = _eval_avs(core, script)
        assert c.format.id == vs.YUV420P8


# ---------------------------------------------------------------------------
# masktools2
# ---------------------------------------------------------------------------

@skip_no_plugins
class TestMasktools2:
    SRC = 'BlankClip(length=10, width=64, height=64, pixel_type="YV12")'

    def test_mt_lut(self, core):
        c = _eval_avs(core, f'LoadPlugin("{_dll("masktools2")}")\n{self.SRC}\nmt_lut("x 2 /")')
        assert c.format.id == vs.YUV420P8


# ---------------------------------------------------------------------------
# TIVTC / TDeint
# ---------------------------------------------------------------------------

@skip_no_plugins
class TestTIVTC:
    SRC = 'BlankClip(length=10, width=64, height=64, pixel_type="YV12")'

    def test_tfm(self, core):
        c = _eval_avs(core, f'LoadPlugin("{_dll("TIVTC")}")\n{self.SRC}\nTFM()')
        assert c.format.id == vs.YUV420P8


# ---------------------------------------------------------------------------
# FFMS2 / LSMASHSource (source filters) — placeholder
# ---------------------------------------------------------------------------

@skip_no_plugins
class TestSourcePlugins:
    def test_ffms2_loads(self, core):
        script = f'LoadPlugin("{_dll("FFMS2")}")'
        # Just loading should not crash
        _eval_avs(core, script)


# ---------------------------------------------------------------------------
# avsi + plugin integration
# ---------------------------------------------------------------------------

@skip_no_plugins
class TestAvsiWithPlugins:
    """Verify vendored .avsi scripts can Import() + use external plugins."""

    def test_ex_tools_loads_with_plugins(self, core):
        avsi_dir = Path(__file__).resolve().parent.parent / "vendor" / "avsi"
        ex = avsi_dir / "ExTools.avsi"
        script = (
            f'LoadPlugin("{_dll("masktools2")}")\n'
            f'Import("{ex}")\n'
            'BlankClip(width=64, height=48, length=1, pixel_type="YV12")\n'
            'ex_invert()\n'
        )
        c = _eval_avs(core, script)
        assert c.format.id == vs.YUV420P8
