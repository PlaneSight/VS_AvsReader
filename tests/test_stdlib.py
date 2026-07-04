"""
Comprehensive test suite for VS_AvsReader exercising the AviSynth+
built-in filter library through VapourSynth.
"""

import subprocess
import sys
import textwrap
from pathlib import Path

import vapoursynth as vs
import pytest

PLUGIN = Path(__file__).resolve().parent.parent / "build" / "vsavsreader.dylib"
AVSI = Path(__file__).resolve().parent.parent / "vendor" / "avsi"


@pytest.fixture(scope="session")
def core():
    c = vs.core
    assert PLUGIN.exists(), f"plugin not built at {PLUGIN}"
    c.std.LoadPlugin(str(PLUGIN))
    return c


def clip(c, script):
    r = c.avsr.Eval(lines=script)
    if isinstance(r, list):
        return r[0]
    return r


def multi(c, script):
    return c.avsr.Eval(lines=script)


def run_isolated(script, *, frame=True):
    code = f"""
import vapoursynth as vs
core = vs.core
core.std.LoadPlugin({str(PLUGIN)!r})
try:
    r = core.avsr.Eval(lines={script!r})
    if isinstance(r, list):
        r = r[0]
    if {frame!r}:
        r.get_frame(0)
except vs.Error:
    pass
"""
    return subprocess.run(
        [sys.executable, "-c", textwrap.dedent(code)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


YV12  = 'pixel_type="YV12"'
YV24  = 'pixel_type="YV24"'
YV16  = 'pixel_type="YV16"'
Y8    = 'pixel_type="Y8"'
RGB24 = 'pixel_type="RGB24"'
RGB32 = 'pixel_type="RGB32"'


class TestSource:
    def test_blankclip(self, core):
        c = clip(core, f'BlankClip(width=64, height=48, {YV12})')
        assert c.width == 64 and c.height == 48
        assert c.format.id == vs.YUV420P8
        assert c.num_frames == 240

    def test_blankclip_length(self, core):
        c = clip(core, f'BlankClip(length=12, width=32, height=32, {YV12})')
        assert c.num_frames == 12

    def test_blankclip_color(self, core):
        c = clip(core, f'BlankClip(width=16, height=16, color=$808080, {YV12})')
        assert c.width == 16

    def test_colorbars(self, core):
        c = clip(core, f'ColorBars(width=320, height=240, {YV12})')
        assert c.width == 320

    def test_colorbars_hd(self, core):
        c = clip(core, 'ColorBarsHD(width=1920, height=1080)')
        assert c.width == 1920

    def test_version(self, core):
        c = clip(core, 'Version()')
        assert c.width > 0

    def test_blackness(self, core):
        c = clip(core, 'Blackness(width=80, height=60)')
        assert c.width == 80


class TestColourConversion:
    src_yv12 = f'BlankClip(width=64, height=64, {YV12})'
    src_yv24 = f'BlankClip(width=64, height=64, {YV24})'
    src_yv16 = f'BlankClip(width=64, height=64, {YV16})'
    src_y8   = f'BlankClip(width=64, height=64, {Y8})'
    src_rgb24 = f'BlankClip(width=64, height=64, {RGB24})'

    def test_yv12_to_yv24(self, core):
        c = clip(core, self.src_yv12 + '\nConvertToYV24()')
        assert c.format.id == vs.YUV444P8

    def test_yv12_to_yv16(self, core):
        c = clip(core, self.src_yv12 + '\nConvertToYV16()')
        assert c.format.id == vs.YUV422P8

    def test_yv12_to_y8(self, core):
        c = clip(core, self.src_yv12 + '\nConvertToY8()')
        assert c.format.id == vs.GRAY8

    def test_yv24_to_yv12(self, core):
        c = clip(core, self.src_yv24 + '\nConvertToYV12()')
        assert c.format.id == vs.YUV420P8

    def test_yv16_to_yv12(self, core):
        c = clip(core, self.src_yv16 + '\nConvertToYV12()')
        assert c.format.id == vs.YUV420P8

    def test_yv24_to_rgb24(self, core):
        c = clip(core, self.src_yv24 + '\nConvertToRGB24()')
        assert c.format.color_family == vs.RGB

    def test_yv24_to_rgb32(self, core):
        r = multi(core, self.src_yv24 + '\nConvertToRGB32()')
        assert isinstance(r, list) and len(r) == 2

    def test_rgb24_to_yv24(self, core):
        c = clip(core, self.src_rgb24 + '\nConvertToYV24()')
        assert c.format.color_family == vs.YUV

    def test_y8_to_yv12(self, core):
        c = clip(core, self.src_y8 + '\nConvertToYV12()')
        assert c.format.id == vs.YUV420P8

    def test_yv12_to_yuy2(self, core):
        c = clip(core, self.src_yv12 + '\nConvertToYUY2()')
        assert c.format.color_family == vs.YUV
        assert c.format.bits_per_sample == 8


class TestResizing:
    src = f'BlankClip(width=320, height=240, {YV12})'

    def test_point(self, core):
        c = clip(core, self.src + '\nPointResize(160, 120)')
        assert (c.width, c.height) == (160, 120)

    def test_bilinear(self, core):
        c = clip(core, self.src + '\nBilinearResize(160, 120)')
        assert c.width == 160

    def test_bicubic(self, core):
        c = clip(core, self.src + '\nBicubicResize(640, 480)')
        assert c.width == 640

    def test_lanczos(self, core):
        c = clip(core, self.src + '\nLanczosResize(160, 120)')
        assert c.width == 160

    def test_spline16(self, core):
        c = clip(core, self.src + '\nSpline16Resize(160, 120)')
        assert c.width == 160

    def test_spline36(self, core):
        c = clip(core, self.src + '\nSpline36Resize(160, 120)')
        assert c.width == 160

    def test_spline64(self, core):
        c = clip(core, self.src + '\nSpline64Resize(160, 120)')
        assert c.width == 160

    def test_gauss(self, core):
        c = clip(core, self.src + '\nGaussResize(160, 120)')
        assert c.width == 160

    def test_lanczos4(self, core):
        c = clip(core, self.src + '\nLanczos4Resize(160, 120)')
        assert c.width == 160

    def test_blackman(self, core):
        c = clip(core, self.src + '\nBlackmanResize(160, 120)')
        assert c.width == 160

    def test_sinc(self, core):
        c = clip(core, self.src + '\nSincResize(160, 120)')
        assert c.width == 160


class TestTemporal:
    src10 = f'BlankClip(length=10, width=32, height=32, {YV12})'
    src20 = f'BlankClip(length=20, width=32, height=32, {YV12})'

    def test_trim(self, core):
        c = clip(core, self.src10 + '\nTrim(2, 7)')
        assert c.num_frames == 6

    def test_trim_start(self, core):
        c = clip(core, self.src10 + '\nTrim(5, 0)')
        assert c.num_frames == 5

    def test_trim_end(self, core):
        c = clip(core, self.src10 + '\nTrim(0, 3)')
        assert c.num_frames == 4

    def test_splice(self, core):
        c = clip(core, 'a = ' + self.src10 + '\n'
                 'b = BlankClip(length=5, width=32, height=32, ' + YV12 + ')\n'
                 'return a + b')
        assert c.num_frames == 15

    def test_splice_concat(self, core):
        c = clip(core, 'a = ' + self.src10 + '\nb = ' + self.src20 + '\nreturn a ++ b')
        assert c.num_frames == 30

    def test_delete_frame(self, core):
        c = clip(core, self.src10 + '\nDeleteFrame(5)')
        assert c.num_frames == 9

    def test_duplicate_frame(self, core):
        c = clip(core, self.src10 + '\nDuplicateFrame(3)')
        assert c.num_frames == 11

    def test_reverse(self, core):
        c = clip(core, self.src10 + '\nReverse()')
        assert c.num_frames == 10

    def test_fadein0(self, core):
        c = clip(core, self.src10 + '\nFadeIn0(3)')
        assert c.num_frames == 10

    def test_fadeout0(self, core):
        c = clip(core, self.src10 + '\nFadeOut0(3)')
        assert c.num_frames == 10

    def test_dissolve(self, core):
        c = clip(core, 'a = ' + self.src10 + '\nb = ' + self.src10 + '\nreturn Dissolve(a, b, 5)')
        assert c.num_frames == 15

    def test_loop(self, core):
        c = clip(core, self.src10 + '\nLoop(3, 0, 3)')
        assert c.num_frames == 18

    def test_freezeframe(self, core):
        c = clip(core, self.src10 + '\nFreezeFrame(2, 5, 0)')
        assert c.num_frames == 10

    def test_trim_and_splice(self, core):
        c = clip(core, 'a = ' + self.src20 + '\nb = a.Trim(0, 4)\nc = a.Trim(15, 19)\nreturn b + c')
        assert c.num_frames == 10

    def test_interleave(self, core):
        c = clip(core,
            'a = BlankClip(length=3, width=16, height=16, color=$000000, ' + YV12 + ')\n'
            'b = BlankClip(length=3, width=16, height=16, color=$FFFFFF, ' + YV12 + ')\n'
            'return Interleave(a, b)')
        assert c.num_frames == 6

    def test_select_every(self, core):
        c = clip(core, self.src10 + '\nSelectEvery(3, 0)')
        assert c.num_frames == 4

    def test_select_even(self, core):
        c = clip(core, self.src10 + '\nSelectEven()')
        assert c.num_frames == 5

    def test_select_odd(self, core):
        c = clip(core, self.src10 + '\nSelectOdd()')
        assert c.num_frames == 5


class TestSpatial:
    src = f'BlankClip(width=320, height=240, {YV12})'

    def test_crop(self, core):
        c = clip(core, self.src + '\nCrop(8, 8, -8, -8)')
        assert (c.width, c.height) == (304, 224)

    def test_crop_absolute(self, core):
        c = clip(core, self.src + '\nCrop(0, 0, 160, 120)')
        assert (c.width, c.height) == (160, 120)

    def test_add_borders(self, core):
        c = clip(core, self.src + '\nAddBorders(4, 4, 4, 4)')
        assert (c.width, c.height) == (328, 248)


class TestLevels:
    src = f'BlankClip(width=64, height=64, {YV12})'

    def test_levels(self, core):
        c = clip(core, self.src + '\nLevels(16, 1.0, 235, 16, 235)')
        assert c.format.id == vs.YUV420P8

    def test_coloryuv(self, core):
        c = clip(core, self.src + '\nColorYUV(levels="TV->PC")')
        assert c.format.id == vs.YUV420P8

    def test_rgbadjust(self, core):
        c = clip(core,
            f'BlankClip(width=64, height=64, {RGB24})\n'
            'RGBAdjust(r=1.0, g=0.9, b=1.0)')
        assert c.format.color_family == vs.RGB


class TestChroma:
    src = f'BlankClip(width=64, height=64, {YV12})'

    def test_greyscale(self, core):
        c = clip(core, self.src + '\nGreyScale()')
        assert c.format.id == vs.YUV420P8


class TestFrameProps:
    src = f'BlankClip(width=32, height=32, {YV12})'

    def test_assume_fps(self, core):
        c = clip(core, self.src + '\nAssumeFPS(29.97)')
        # 29.97 approximates as 30000/1001 or 2997/100 depending on version
        assert c.fps_den == 100 or c.fps_den == 1001

    def test_assume_fps_int(self, core):
        c = clip(core, self.src + '\nAssumeFPS(60)')
        assert c.fps_num == 60 and c.fps_den == 1

    def test_info(self, core):
        c = clip(core, self.src + '\nInfo()')
        assert c.width >= 32


class TestInterlacing:
    src = f'BlankClip(width=64, height=64, {YV12})'

    def test_separate_fields(self, core):
        c = clip(core, self.src + '\nAssumeTFF()\nSeparateFields()')
        assert c.height == 32

    def test_weave(self, core):
        c = clip(core, self.src + '\nAssumeTFF()\nSeparateFields()\nWeave()')
        assert c.height == 64

    def test_double_weave(self, core):
        c = clip(core, self.src + '\nAssumeTFF()\nDoubleWeave()')
        assert c.num_frames == 480

    def test_complement_parity(self, core):
        c = clip(core, self.src + '\nAssumeTFF()\nComplementParity()')
        assert c.width == 64


class TestAudio:
    src = f'BlankClip(width=32, height=32, {YV12})'

    def test_kill_audio(self, core):
        c = clip(core, self.src + '\nKillAudio()')
        assert c.width == 32

    def test_amplify(self, core):
        c = clip(core, self.src + '\nAmplify(1.5)')
        assert c.width == 32

    def test_convert_audio(self, core):
        c = clip(core, self.src + '\nConvertAudioTo16bit()')
        assert c.width == 32


class TestRobustness:
    def test_empty_script(self, core):
        with pytest.raises(vs.Error, match="Import:"):
            core.avsr.Import(script="")

    def test_empty_eval(self, core):
        with pytest.raises(vs.Error, match="Eval:"):
            core.avsr.Eval(lines="")

    def test_invalid_bitdepth(self, core):
        with pytest.raises(vs.Error, match="invalid bitdepth"):
            core.avsr.Import(script="dummy.avs", bitdepth=12)

    def test_zero_length_eval(self, core):
        with pytest.raises(vs.Error):
            core.avsr.Eval(lines="  ")

    @pytest.mark.parametrize("script", [
        f'BlankClip(length=10, width=64, height=64, {YV12})\nPeculiarBlend()',
        f'BlankClip(length=10, width=64, height=64, {YV12})\nFixBrokenChromaUpsampling()',
        'ShowFiveVersions()',
    ])
    def test_avisynth_errors_do_not_abort(self, script):
        p = run_isolated(script)
        assert p.returncode == 0, p.stderr


# -- Overlays & text ----------------------------------------------------

class TestOverlays:
    src = f'BlankClip(length=10, width=64, height=48, {YV12})'

    def test_subtitle(self, core):
        c = clip(core, self.src + '\nSubtitle("test")')
        assert c.width == 64

    def test_showframenumber(self, core):
        c = clip(core, self.src + '\nShowFrameNumber()')
        assert c.width == 64

    def test_showsmpte(self, core):
        c = clip(core, self.src + '\nShowSMPTE()')
        assert c.width == 64

    def test_showtime(self, core):
        c = clip(core, self.src + '\nShowTime()')
        assert c.width == 64

    def test_histogram_classic(self, core):
        c = clip(core, self.src + '\nHistogram("classic")')
        assert c.width >= 64  # histogram mode widens the clip

    def test_histogram_levels(self, core):
        c = clip(core, self.src + '\nHistogram("levels")')
        assert c.width >= 64


# -- Plane manipulation ------------------------------------------------

class TestPlanes:
    src_yv12  = f'BlankClip(width=64, height=48, {YV12})'
    src_y8_a  = f'BlankClip(width=32, height=48, {Y8})'
    src_y8_b  = f'BlankClip(width=32, height=48, {Y8})'
    src_rgb   = f'BlankClip(width=64, height=48, {RGB24})'

    def test_greyscale(self, core):
        c = clip(core, self.src_yv12 + '\nGreyScale()')
        assert c.format.id == vs.YUV420P8

    def test_swapuv(self, core):
        c = clip(core, self.src_yv12 + '\nSwapUV()')
        assert c.format.id == vs.YUV420P8

    def test_utoy(self, core):
        c = clip(core, self.src_yv12 + '\nUToY()')
        assert c.width == 32  # subsampled: YV12 U plane is half-width

    def test_vtoy(self, core):
        c = clip(core, self.src_yv12 + '\nVToY()')
        assert c.width == 32

    def test_ytouv(self, core):
        c = clip(core, self.src_y8_a + '\nYToUV(' + self.src_y8_b + ', last)')
        assert c.format.color_family == vs.YUV

    def test_mergechroma(self, core):
        src2 = f'BlankClip(width=64, height=48, {YV12}, color=$808080)'
        c = clip(core, 'a=' + self.src_yv12 + '\nb=' + src2 + '\nMergeChroma(a, b)')
        assert c.format.id == vs.YUV420P8

    def test_mergeluma(self, core):
        src2 = f'BlankClip(width=64, height=48, {Y8})'
        c = clip(core, 'a=' + self.src_yv12 + '\nb=' + src2 + '\nMergeLuma(a, b)')
        assert c.format.id == vs.YUV420P8

    def test_show_red_green_blue(self, core):
        for ch in ("Red", "Green", "Blue"):
            c = clip(core, self.src_rgb + f'\nShow{ch}("YV12")')
            assert c.format.color_family == vs.YUV


# -- Merge / compositing -----------------------------------------------

class TestMerge:
    src_yv12  = f'BlankClip(width=64, height=48, {YV12})'
    src_rgb24 = f'BlankClip(width=64, height=48, {RGB24})'

    def test_merge(self, core):
        src2 = f'BlankClip(width=64, height=48, {YV12}, color=$FFFFFF)'
        c = clip(core, 'a=' + self.src_yv12 + '\nb=' + src2 + '\nMerge(a, b, 0.5)')
        assert c.format.id == vs.YUV420P8

    def test_merge_rgb(self, core):
        src2 = f'BlankClip(width=64, height=48, {RGB24}, color=$FFFFFF)'
        c = clip(core, 'a=' + self.src_rgb24 + '\nb=' + src2 + '\nMergeRGB(a, b, a)')
        assert c.format.color_family == vs.RGB

    def test_overlay(self, core):
        src2 = f'BlankClip(width=32, height=24, {YV12}, color=$FFFFFF)'
        c = clip(core, 'a=' + self.src_yv12 + '\nb=' + src2 + '\nOverlay(a, b, x=16, y=12)')
        assert c.format.id == vs.YUV420P8

    def test_layer(self, core):
        src2 = f'BlankClip(width=64, height=48, {RGB24}, color=$808080)'
        c = clip(core, 'a=' + self.src_rgb24 + '\nb=' + src2 + '\nLayer(a, b, "add", 128)')
        assert c.format.color_family == vs.RGB


# -- Transforms --------------------------------------------------------

class TestTransforms:
    src_yv12  = f'BlankClip(width=64, height=48, {YV12})'

    def test_turn_left(self, core):
        c = clip(core, self.src_yv12 + '\nTurnLeft()')
        assert c.width == 48 and c.height == 64

    def test_turn_right(self, core):
        c = clip(core, self.src_yv12 + '\nTurnRight()')
        assert c.width == 48 and c.height == 64

    def test_turn180(self, core):
        c = clip(core, self.src_yv12 + '\nTurn180()')
        assert c.width == 64 and c.height == 48

    def test_flip_horizontal(self, core):
        c = clip(core, self.src_yv12 + '\nFlipHorizontal()')
        assert c.width == 64

    def test_flip_vertical(self, core):
        c = clip(core, self.src_yv12 + '\nFlipVertical()')
        assert c.height == 48


# -- Stacking ----------------------------------------------------------

class TestStacking:
    src = f'BlankClip(width=16, height=16, {YV12})'

    def test_stack_horizontal(self, core):
        c = clip(core, 'a=' + self.src + '\nb=' + self.src + '\nreturn StackHorizontal(a, b)')
        assert c.width == 32 and c.height == 16

    def test_stack_vertical(self, core):
        c = clip(core, 'a=' + self.src + '\nb=' + self.src + '\nreturn StackVertical(a, b)')
        assert c.width == 16 and c.height == 32


# -- Additional colour filters -----------------------------------------

class TestColourFilters:
    src_yv12 = f'BlankClip(width=64, height=48, {YV12})'
    src_rgb  = f'BlankClip(width=64, height=48, {RGB24})'

    def test_invert(self, core):
        c = clip(core, self.src_yv12 + '\nInvert()')
        assert c.format.id == vs.YUV420P8

    def test_tweak(self, core):
        c = clip(core, self.src_yv12 + '\nTweak(sat=1.1, bright=5)')
        assert c.format.id == vs.YUV420P8

    def test_limiter(self, core):
        c = clip(core, self.src_yv12 + '\nLimiter(16, 235, 16, 240)')
        assert c.format.id == vs.YUV420P8

    def test_rgbadjust_all_channels(self, core):
        c = clip(core, self.src_rgb + '\nRGBAdjust(1.1, 0.9, 1.0, 1.0)')
        assert c.format.color_family == vs.RGB

    def test_coloryuv_cont(self, core):
        c = clip(core, self.src_yv12 + '\nColorYUV(cont_u=10, cont_v=-10)')
        assert c.format.id == vs.YUV420P8


# -- Field/frame mode --------------------------------------------------

class TestFieldMode:
    src = f'BlankClip(length=10, width=64, height=48, {YV12})'

    def test_assume_field_based(self, core):
        c = clip(core, self.src + '\nAssumeFieldBased()')
        assert c.width == 64

    def test_assume_frame_based(self, core):
        c = clip(core, self.src + '\nAssumeFrameBased()')
        assert c.width == 64

    def test_bob(self, core):
        c = clip(core, self.src + '\nAssumeTFF()\nBob()')
        assert c.height == 48

    def test_assume_bff(self, core):
        c = clip(core, self.src + '\nAssumeBFF()\nComplementParity()')
        assert c.width == 64


# -- Misc filters ------------------------------------------------------

class TestMiscFilters:
    src_yv12 = f'BlankClip(length=1, width=64, height=48, {YV12})'

    def test_compare(self, core):
        src2 = f'BlankClip(length=1, width=64, height=48, {YV12}, color=$808080)'
        c = clip(core, 'a=' + self.src_yv12 + '\nb=' + src2 + '\nCompare(a, b)')
        assert c.width == 64

    def test_general_convolution(self, core):
        c = clip(core, f'BlankClip(width=64, height=48, {RGB24})\n'
                 'GeneralConvolution(bias=0, matrix="-1 -1 -1 -1 9 -1 -1 -1 -1")')
        assert c.format.color_family == vs.RGB

    def test_conditional_filter(self, core):
        c = clip(core,
            'a=' + self.src_yv12 + '\n'
            'b=BlankClip(length=1, width=64, height=48, ' + YV12 + ', color=$808080)\n'
            'ConditionalFilter(a, b, a, "AverageLuma()", ">", "0")')
        assert c.width == 64

    @pytest.mark.parametrize("fmt_str,fmt_id", [
        ("RGB24", vs.RGB24),
        ("YUY2", vs.YUV422P8),
        ("YV12", vs.YUV420P8),
        ("YV16", vs.YUV422P8),
        ("YV24", vs.YUV444P8),
        ("Y8", vs.GRAY8),
    ])
    def test_convert_to(self, core, fmt_str, fmt_id):
        c = clip(core, self.src_yv12 + f'\nConvertTo{fmt_str}()')
        assert c.format.id == fmt_id

