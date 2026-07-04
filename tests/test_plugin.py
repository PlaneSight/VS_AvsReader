import vapoursynth as vs
import pytest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent / "build" / "vsavsreader.dylib"


@pytest.fixture(scope="session")
def core():
    c = vs.core
    assert PLUGIN.exists(), f"plugin not built at {PLUGIN}"
    c.std.LoadPlugin(str(PLUGIN))
    return c


def test_plugin_loaded(core):
    assert hasattr(core, "avsr"), "avsr namespace not registered"
    assert hasattr(core.avsr, "Import"), "avsr.Import not found"
    assert hasattr(core.avsr, "Eval"), "avsr.Eval not found"


def test_import_empty(core):
    with pytest.raises(vs.Error, match="Import:"):
        core.avsr.Import(script="")


def test_eval_empty(core):
    with pytest.raises(vs.Error, match="Eval:"):
        core.avsr.Eval(lines="")


def test_import_nonexistent_file(core):
    with pytest.raises(vs.Error):
        core.avsr.Import(script="/nonexistent/script.avs")


def test_invalid_bitdepth(core):
    with pytest.raises(vs.Error, match="invalid bitdepth"):
        core.avsr.Import(script="dummy.avs", bitdepth=12)


def test_accepts_valid_args(core):
    """Verify that valid-looking arguments don't crash the plugin loader
    itself (even if AviSynth isn't available at runtime on this host)."""
    with pytest.raises(vs.Error):
        # Will fail because avisynth.dll isn't available on macOS, but
        # should fail cleanly from the plugin, not a segfault or Python
        # level crash.
        core.avsr.Eval(lines="Version()")
