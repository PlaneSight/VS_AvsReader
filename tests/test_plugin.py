import vapoursynth as vs
import pytest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent / "build" / "vsavsreader.dylib"
AVSI = Path(__file__).resolve().parent.parent / "avsi"


@pytest.fixture(scope="session")
def core():
    c = vs.core
    assert PLUGIN.exists(), f"plugin not built at {PLUGIN}"
    c.std.LoadPlugin(str(PLUGIN))
    return c


def _e(core, script, alpha=False):
    """Eval helper: always specify pixel_type for cross-platform consistency."""
    r = core.avsr.Eval(lines=script, alpha=alpha)
    if isinstance(r, list):
        return r[0], r[1] if len(r) > 1 else None
    return r, None


def _clip(core, script):
    """Returns the base clip, raising if a list comes back unexpectedly."""
    r, _ = _e(core, script)
    return r


# -- Built-in filter tests -------------------------------------------

class TestBuiltinEval:
    def test_blankclip(self, core):
        clip = _clip(core,
            'BlankClip(width=320, height=240, pixel_type="YV12")')
        assert clip.width == 320
        assert clip.height == 240
        assert clip.format.id == vs.YUV420P8
        assert clip.num_frames == 240

    def test_colorbars(self, core):
        clip = _clip(core,
            'ColorBars(width=640, height=480, pixel_type="YV24")')
        assert clip.width == 640
        assert clip.height == 480
        assert clip.format.id == vs.YUV444P8

    def test_version(self, core):
        clip = _clip(core, 'Version()')
        assert clip.width > 0

    def test_import_avs(self, core):
        avs = AVSI / "_test_blankclip.avs"
        avs.write_text('BlankClip(width=100, height=200, pixel_type="YV12")')
        try:
            clip = core.avsr.Import(script=str(avs))
            assert clip.width == 100
            assert clip.height == 200
        finally:
            avs.unlink()

    def test_multi_step_script(self, core):
        avs = AVSI / "_test_source.avs"
        avs.write_text(
            'v = BlankClip(width=128, height=64, pixel_type="YV12")\n'
            'return v')
        try:
            clip = core.avsr.Import(script=str(avs))
            assert clip.width == 128
            assert clip.height == 64
        finally:
            avs.unlink()

    def test_high_bitdepth(self, core):
        avs = AVSI / "_test_hbd.avs"
        avs.write_text('BlankClip(width=64, height=48, pixel_type="YV12")')
        try:
            clip = core.avsr.Import(script=str(avs), bitdepth=16)
            assert clip.width == 32
            assert clip.height == 48
            assert clip.format.bits_per_sample == 16
        finally:
            avs.unlink()

    def test_rgb_alpha_output(self, core):
        """RGB32 with alpha=True produces two clips as a list."""
        r = core.avsr.Eval(
            lines='BlankClip(width=40, height=30, pixel_type="RGB32")')
        assert isinstance(r, list)
        assert len(r) == 2
        assert r[0].width == 40
        assert r[0].height == 30

    def test_gray_output(self, core):
        clip = _clip(core,
            'BlankClip(width=50, height=50, pixel_type="Y8")')
        assert clip.format.color_family == vs.GRAY
        assert clip.format.bits_per_sample == 8

    def test_resample(self, core):
        clip = _clip(core,
            'BlankClip(width=16, height=16, length=10, pixel_type="YV12")\n'
            'a = last\n'
            'b = BlankClip(width=16, height=16, length=5, color=255, pixel_type="YV12")\n'
            'return a + b')
        assert clip.num_frames == 15

    def test_splice_list(self, core):
        clip = _clip(core,
            'a = BlankClip(width=32, height=32, length=3, pixel_type="YV12")\n'
            'b = BlankClip(width=32, height=32, length=7, pixel_type="YV12")\n'
            'return a + b')
        assert clip.num_frames == 10

    def test_trim(self, core):
        clip = _clip(core,
            'BlankClip(width=64, height=64, length=50, pixel_type="YV12")\n'
            'Trim(10, 19)')
        assert clip.num_frames == 10

    def test_crop(self, core):
        clip = _clip(core,
            'BlankClip(width=320, height=240, pixel_type="YV12")\n'
            'Crop(8, 8, -8, -8)')
        assert clip.width == 304
        assert clip.height == 224

    def test_convert_to_yuv444(self, core):
        clip = _clip(core,
            'BlankClip(width=64, height=64, pixel_type="YV12")\n'
            'ConvertToYV24()')
        assert clip.format.id == vs.YUV444P8


# -- Error handling --------------------------------------------------

class TestErrors:
    def test_empty_script(self, core):
        with pytest.raises(vs.Error, match="Import:"):
            core.avsr.Import(script="")

    def test_empty_eval(self, core):
        with pytest.raises(vs.Error, match="Eval:"):
            core.avsr.Eval(lines="")

    def test_invalid_bitdepth(self, core):
        with pytest.raises(vs.Error, match="invalid bitdepth"):
            core.avsr.Import(script="dummy.avs", bitdepth=12)
